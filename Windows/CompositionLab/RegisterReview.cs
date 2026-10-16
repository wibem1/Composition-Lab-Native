using System.Globalization;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace CompositionLab;

internal sealed class RegisterRepairException(string message, JsonObject report) : Exception(message)
{
    public JsonObject Report { get; } = report;
}

internal sealed partial class MainForm
{
    bool automaticRegisterReview = true, forceRegisterReview;
    // Only the repair transport is replaced in offline tests; compilation and
    // validation exercise the same paths as a real composition.
    Func<JsonObject, CancellationToken, Task<JsonObject>>? registerRepairTransport;
    const string PitchEncodingHint = "Wenn du LilyPond ausgibst: Verwende explizite absolute Oktavlagen statt durchlaufendem \\relative. Prüfe die tatsächlich klingenden Lagen jedes Instruments. Klavier: A0 bis C8 (MIDI 21–108). Vermeide unbeabsichtigtes Auf- oder Abwandern um Oktaven; 8va/8vb ändert nur die Darstellung.";

    static JsonArray RegisterIssues(JsonObject score, string music)
    {
        var issues = new JsonArray();
        var tracks = score["tr"]!.AsArray().OfType<JsonObject>().ToArray();
        bool relative = Regex.IsMatch(ExtractLilyPond(music), @"\\relative\b");
        for (int i = 0; i < tracks.Length; i++)
        {
            var track = tracks[i];
            int program = track["pg"]?.GetValue<int>() ?? -1;
            // GM instrument program 0 is piano; programs 40–51 are bowed strings.
            // Very high notes in strings can be valid, but a sustained passage
            // beyond the normal violin range deserves an explicit warning.
            bool piano = program is >= 0 and <= 7;
            bool stringInstrument = program is >= 40 and <= 51;
            if (!piano && !stringInstrument) continue;
            var notes = track["nt"]!.AsArray().OfType<JsonArray>().ToArray();
            if (notes.Length == 0) continue;
            double low = piano ? 21 : 36;
            double high = piano ? 108 : 100;
            var outside = notes.Where(n => n[2]!.GetValue<double>() < low || n[2]!.GetValue<double>() > high).ToArray();
            // A long extreme register reached from a central opening in relative
            // input merits an octave review even if still inside the keyboard.
            var first = notes.Where(n => n[0]!.GetValue<double>() < 4).ToArray();
            bool drift = first.Length > 0 && first.Max(n => n[2]!.GetValue<double>()) <= 84 &&
                notes.Count(n => n[2]!.GetValue<double>() > (piano ? 96 : 93)) >= 6 &&
                (relative || stringInstrument);
            if (outside.Length == 0 && !drift) continue;
            issues.Add(new JsonObject { ["track"] = i + 1, ["instrument"] = track["nm"]?.GetValue<string>() ?? (piano ? "Klavier" : "Streicher"), ["minimum"] = notes.Min(n => n[2]!.GetValue<double>()),
                ["maximum"] = notes.Max(n => n[2]!.GetValue<double>()), ["outsideKeyboard"] = outside.Length,
                ["reason"] = outside.Length > 0 ? (piano ? "Töne außerhalb A0–C8" : "Auffällige Streicherlage außerhalb C2–E7") : "Verdacht auf anhaltende Oktavwanderung in extremer Lage",
                ["beats"] = new JsonArray((outside.Length > 0 ? outside : notes.Where(n => n[2]!.GetValue<double>() > 96)).Take(12).Select(n => (JsonNode?)JsonValue.Create(n[0]!.GetValue<double>())).ToArray()) });
        }
        return issues;
    }

    static double Numeric(JsonNode? value) => value == null ? 0 : double.Parse(value.ToString(), CultureInfo.InvariantCulture);

    static bool OctaveOnlyChange(JsonObject before, JsonObject after)
    {
        static string Number(JsonNode? n) => Math.Round(n!.GetValue<double>(), 6).ToString("G", CultureInfo.InvariantCulture);
        static string[] Signature(JsonObject t) => t["nt"]!.AsArray().OfType<JsonArray>().Select(n =>
            string.Join("/", Number(n[0]), Number(n[1]), ((int)n[2]!.GetValue<double>() % 12).ToString(), Number(n[3]), n.Count > 5 ? Number(n[5]) : "1")).Order().ToArray();
        var a = before["tr"]!.AsArray().OfType<JsonObject>().ToArray();
        var b = after["tr"]!.AsArray().OfType<JsonObject>().ToArray();
        if (a.Length != b.Length || Math.Abs(before["bpm"]!.GetValue<double>() - after["bpm"]!.GetValue<double>()) > .01 || before["ts"]!.ToJsonString() != after["ts"]!.ToJsonString() || before["k"]?.ToString() != after["k"]?.ToString()) return false;
        return a.Zip(b).All(pair => pair.First["pg"]?.ToString() == pair.Second["pg"]?.ToString() && Signature(pair.First).SequenceEqual(Signature(pair.Second)) && new[] { "ct", "me" }.All(k => pair.First[k]?.ToJsonString() == pair.Second[k]?.ToJsonString()));
    }

    async Task<JsonObject> RequestRegisterRepairAsync(JsonObject request, CancellationToken token)
    {
        if (testMode && registerRepairTransport != null) return await registerRepairTransport(request, token);
        string providerName = request["provider"]!.GetValue<string>();
        string key = ProviderKey(providerName);
        if (providerName == activeProvider && !string.IsNullOrWhiteSpace(apiKey.Text)) key = apiKey.Text.Trim();
        if (string.IsNullOrEmpty(key)) throw new InvalidOperationException("Für die Oktavkorrektur fehlt der API-Schlüssel des verwendeten Providers. Schlüssel eintragen und erneut prüfen.");
        var response = await core.RunAsync(new JsonObject { ["operation"] = "chat", ["apiKey"] = key, ["request"] = request.DeepClone() }, token);
        return response["result"]!.AsObject();
    }

    async Task<JsonObject> CompileCheckedCompositionAsync(string music, JsonObject source, CancellationToken token, bool updateDiagnostic = true)
    {
        var original = await CompileCompositionAsync(music, source, token, updateDiagnostic: false);
        var issues = RegisterIssues(original["score"]!.AsObject(), music);
        original["octaveReview"] = new JsonObject { ["status"] = issues.Count == 0 ? "passed" : "issues", ["issues"] = issues.DeepClone(), ["repairAICalls"] = 0 };
        if (issues.Count > 0 && (automaticRegisterReview || forceRegisterReview))
        {
            var review = original["octaveReview"]!.AsObject();
            original["originalLilyPond"] = music;
            try
            {
                SetStatus("Oktavfehler erkannt. KI korrigiert ausschließlich die klingenden Oktavlagen …");
                string instruction = "Korrigiere ausschließlich unbeabsichtigte Oktavlagen im folgenden vollständigen LilyPond-Stück. Keine neue Komposition. Erhalte alle Noten, Tonklassen, Rhythmen, Taktarten, Tempi, Stimmenreihenfolge, Instrumente, Artikulation, Dynamik und musikalische Abschnitte exakt. Behebe auch die damit zusammenhängende Auf-/Abwanderung innerhalb des Klaviers. Keine einzelne Note blind in einen Zielbereich falten: Wähle zusammenhängende musikalische Phrasen und passende Handlagen. Keine Änderung durch ottava (das behebt klingende Fehler nicht). Gib nur den vollständigen korrigierten LilyPond-Code mit expliziten absoluten Tonhöhen ohne \\relative aus. Klavierumfang MIDI 21–108; extreme Lagen nur wenn musikalisch begründet, keine fortschreitende Oktavwanderung.\nBefund (Beats in Vierteln, Tonhöhen als MIDI):\n" + issues.ToJsonString() + "\nORIGINAL:\n" + ExtractLilyPond(music);
                var request = new JsonObject { ["assignment"] = instruction, ["provider"] = source["provider"]?.DeepClone() ?? JsonValue.Create(activeProvider),
                    ["model"] = source["model"]?.DeepClone() ?? JsonValue.Create(SelectedModelId), ["effort"] = source["reasoning"]?.DeepClone() ?? JsonValue.Create("medium") };
                review["request"] = request.DeepClone(); review["repairAICalls"] = 1;
                var response = await RequestRegisterRepairAsync(request, token);
                review["response"] = response.DeepClone();
                foreach (string name in new[] { "inputTokens", "outputTokens" }) original[name] = (int)(Numeric(original[name]) + Numeric(response[name]));
                original["estimatedCostUSD"] = Numeric(original["estimatedCostUSD"]) + Numeric(response["estimatedCostUSD"]);
                string corrected = response["text"]!.GetValue<string>();
                var candidate = await CompileCompositionAsync(corrected, source, token, updateDiagnostic: false);
                if (!OctaveOnlyChange(original["score"]!.AsObject(), candidate["score"]!.AsObject()))
                    throw new InvalidDataException("Die vorgeschlagene Oktavkorrektur verändert Tonklassen, Rhythmus, Dynamik oder Besetzung und wurde verworfen.");
                if (Regex.IsMatch(ExtractLilyPond(corrected), @"\\relative\b") || RegisterIssues(candidate["score"]!.AsObject(), corrected).Count > 0)
                    throw new InvalidDataException("Die Oktavkorrektur ist weiterhin auffällig und wurde nicht übernommen.");
                review["status"] = "corrected";
                candidate["octaveReview"] = review.DeepClone(); candidate["originalLilyPond"] = music;
                foreach (string name in new[] { "inputTokens", "outputTokens", "estimatedCostUSD" }) candidate[name] = original[name]!.DeepClone();
                original = candidate;
            }
            catch (OperationCanceledException) { throw; }
            catch (Exception e)
            {
                review["status"] = "rejected"; original["stage"] = "octave-review-failed"; original["error"] = e.Message;
                lastDiagnostic = original.DeepClone().AsObject(); UpdateDiagnostic();
                if (forceRegisterReview)
                    throw new RegisterRepairException("Oktavprüfung: " + e.Message + " Die bisherige Fassung bleibt erhalten; Original und Befund stehen in der Diagnose.", original);
                // Automatic octave repair is best-effort: a valid LilyPond/MIDI
                // output must remain usable even when the optional AI repair fails.
                review["status"] = "warning";
                review["message"] = "Oktavkorrektur fehlgeschlagen; unverändertes Original ausgegeben: " + e.Message;
                original["stage"] = "completed-with-register-warning";
                original["error"] = e.Message;
                SetStatus("Originalausgabe bleibt erhalten; Oktavlagen müssen geprüft werden.", true);
            }
        }
        if (updateDiagnostic) { lastDiagnostic = original.DeepClone().AsObject(); UpdateDiagnostic(); }
        return original;
    }

    static bool RegisterNeedsAttention(JsonObject? value) => value?["octaveReview"]?["status"]?.GetValue<string>() is "warning" or "issues";
    void SetMusicStatus(JsonObject? value, string success)
    {
        if (RegisterNeedsAttention(value)) SetStatus("Oktavprüfung offen: Original ausgegeben. Komposition → Oktavlagen prüfen und korrigieren.", true);
        else SetStatus(success);
    }

    async Task ReviewCurrentRegistersAsync()
    {
        if (busy) return;
        forceRegisterReview = true;
        try { await ApplyLilyPondEditsAsync(); }
        finally { forceRegisterReview = false; }
    }
}

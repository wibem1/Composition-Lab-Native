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
    bool automaticRegisterReview = false, forceRegisterReview;
    // Only the repair transport is replaced in offline tests; compilation and
    // validation exercise the same paths as a real composition.
    Func<JsonObject, CancellationToken, Task<JsonObject>>? registerRepairTransport;
    string registerRepairInstruction = "";

    async Task<JsonArray> RegisterIssuesAsync(JsonObject score, string music)
    {
        var result = await core.RunAsync(new JsonObject { ["operation"] = "register-review", ["score"] = score.DeepClone() });
        registerRepairInstruction = result["instruction"]!.GetValue<string>();
        return result["issues"]!.DeepClone().AsArray();
    }

    static double Numeric(JsonNode? value) => value == null ? 0 : double.Parse(value.ToString(), CultureInfo.InvariantCulture);

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
        var issues = await RegisterIssuesAsync(original["score"]!.AsObject(), music);
        original["octaveReview"] = new JsonObject { ["status"] = issues.Count == 0 ? "passed" : "issues", ["issues"] = issues.DeepClone(), ["repairAICalls"] = 0 };
        if (issues.Count > 0 && forceRegisterReview)
        {
            var review = original["octaveReview"]!.AsObject();
            original["originalLilyPond"] = music;
            try
            {
                SetStatus("Oktavfehler erkannt. KI korrigiert ausschließlich die klingenden Oktavlagen …");
                string instruction = registerRepairInstruction + "\nBEFUND:\n" + issues.ToJsonString() + "\nORIGINAL:\n" + ExtractLilyPond(music);
                var request = new JsonObject { ["assignment"] = instruction, ["provider"] = source["provider"]?.DeepClone() ?? JsonValue.Create(activeProvider),
                    ["model"] = source["model"]?.DeepClone() ?? JsonValue.Create(SelectedModelId), ["effort"] = source["reasoning"]?.DeepClone() ?? JsonValue.Create("medium") };
                review["request"] = request.DeepClone(); review["repairAICalls"] = 1;
                var response = await RequestRegisterRepairAsync(request, token);
                review["response"] = response.DeepClone();
                foreach (string name in new[] { "inputTokens", "outputTokens" }) original[name] = (int)(Numeric(original[name]) + Numeric(response[name]));
                original["estimatedCostUSD"] = Numeric(original["estimatedCostUSD"]) + Numeric(response["estimatedCostUSD"]);
                string corrected = response["text"]!.GetValue<string>();
                var candidate = await CompileCompositionAsync(corrected, source, token, updateDiagnostic: false);
                await core.RunAsync(new JsonObject { ["operation"] = "validate-register-repair",
                    ["before"] = original["score"]!.DeepClone(), ["after"] = candidate["score"]!.DeepClone(), ["source"] = corrected }, token);
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

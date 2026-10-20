using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed partial class MainForm
{
    async Task RunRegisterReviewTestsAsync(string output)
    {
        const string bad = "\\version \"2.24.0\"\n\\header { title = \"Oktavprüfung\" }\nright = \\relative c' { c4 e g c | e'4 g c e }\nleft = \\relative c, { \\clef bass c1 | c,,1 }\n\\score { \\new PianoStaff << \\new Staff { \\right } \\new Staff { \\left } >> \\layout {} \\midi {} }";
        const string good = "\\version \"2.24.0\"\n\\header { title = \"Oktavprüfung\" }\nright = { c'4 e' g' c'' | e''4 g'' c''' e''' }\nleft = { \\clef bass c,1 | c,1 }\n\\score { \\new PianoStaff << \\new Staff { \\right } \\new Staff { \\left } >> \\layout {} \\midi {} }";
        var source = new JsonObject { ["provider"] = "gemini", ["model"] = "test-register",
            ["inputTokens"] = 9, ["outputTokens"] = 10, ["estimatedCostUSD"] = .02 };
        int calls = 0;
        bool previousSetting = automaticRegisterReview;
        var previousDiagnostic = lastDiagnostic?.DeepClone().AsObject();
        try
        {
            automaticRegisterReview = true;
            registerRepairTransport = (_, _) => { calls++; return Task.FromResult(new JsonObject {
                ["text"] = good, ["inputTokens"] = 7, ["outputTokens"] = 8, ["estimatedCostUSD"] = .03
            }); };
            // A warning must never trigger a hidden network request.
            var scanned = await CompileCheckedCompositionAsync(bad, source, CancellationToken.None);
            if (calls != 0 || scanned["octaveReview"]?["status"]?.GetValue<string>() != "issues" ||
                scanned["composition"]?.GetValue<string>() != bad)
                throw new Exception("Automatische Oktavprüfung verändert die Komposition oder ruft die KI.");
            // Previously undetected: concert-pitch high notes remain below C8,
            // but a sustained phrase from C7 onward is visibly extreme.
            var highPiano = scanned["score"]!.DeepClone().AsObject();
            var pianoNotes = highPiano["tr"]!.AsArray().OfType<JsonObject>()
                .First(t => (t["pg"]?.GetValue<int>() ?? -1) is >= 0 and <= 7)["nt"]!.AsArray();
            for (int i = 0; i < 5; i++)
                pianoNotes.Add(new JsonArray(16d + i, 1d, 96d + i, 80d, 0d, 1d));
            if ((await RegisterIssuesAsync(highPiano, good)).Count == 0)
                throw new Exception("Hohe Klavierpassagen innerhalb C7–E7 wurden übersehen.");
            var highStrings = highPiano.DeepClone().AsObject();
            highStrings["tr"]![0]!["pg"] = 40;
            if ((await RegisterIssuesAsync(highStrings, good)).Count == 0)
                throw new Exception("Auffällige hohe Streicherpassagen wurden übersehen.");
            forceRegisterReview = true;
            var fixedResult = await CompileCheckedCompositionAsync(bad, source, CancellationToken.None);
            forceRegisterReview = false;
            if (calls != 1 || fixedResult["octaveReview"]?["status"]?.GetValue<string>() != "corrected" ||
                fixedResult["composition"]?.GetValue<string>() != good)
                throw new Exception("Ausdrücklich bestellte Oktavkorrektur wurde nicht übernommen.");
            if (Math.Abs(Numeric(fixedResult["estimatedCostUSD"]) - .05) > .000001)
                throw new Exception("Kosten der ausdrücklichen Korrektur fehlen.");
            registerRepairTransport = (_, _) => { calls++; return Task.FromResult(new JsonObject { ["text"] = bad }); };
            forceRegisterReview = true;
            bool rejected = false;
            try { await CompileCheckedCompositionAsync(bad, source, CancellationToken.None); }
            catch (RegisterRepairException) { rejected = true; }
            finally { forceRegisterReview = false; }
            if (!rejected || calls != 2)
                throw new Exception("Ungültige KI-Korrektur muss bei manueller Anforderung abgelehnt werden.");
            AtomicFile.WriteText(Path.Combine(output, "Oktavpruefung.json"), scanned.ToJsonString());
            AtomicFile.WriteText(Path.Combine(output, "Oktavpruefung.ly"), bad);
        }
        finally
        {
            forceRegisterReview = false;
            automaticRegisterReview = previousSetting;
            registerRepairTransport = null;
            lastDiagnostic = previousDiagnostic;
            UpdateDiagnostic();
        }
    }
}

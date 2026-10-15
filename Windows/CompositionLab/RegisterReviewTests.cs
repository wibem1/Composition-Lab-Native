using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed partial class MainForm
{
    async Task RunRegisterReviewTestsAsync(string output)
    {
        const string bad = "\\version \"2.24.0\"\n\\header { title = \"Oktavprüfung\" }\nright = \\relative c' { c4 e g c | e'4 g c e }\nleft = \\relative c, { \\clef bass c1 | c,,1 }\n\\score { \\new PianoStaff << \\new Staff { \\right } \\new Staff { \\left } >> \\layout {} \\midi {} }";
        const string good = "\\version \"2.24.0\"\n\\header { title = \"Oktavprüfung\" }\nright = { c'4 e' g' c'' | e''4 g'' c''' e''' }\nleft = { \\clef bass c,1 | c,1 }\n\\score { \\new PianoStaff << \\new Staff { \\right } \\new Staff { \\left } >> \\layout {} \\midi {} }";
        var source = new JsonObject { ["provider"] = "gemini", ["model"] = "test-register", ["inputTokens"] = 9, ["outputTokens"] = 10, ["estimatedCostUSD"] = .02 };
        int calls = 0;
        var previousDiagnostic = lastDiagnostic?.DeepClone().AsObject();
        bool previousSetting = automaticRegisterReview;
        registerRepairTransport = (request, token) =>
        {
            token.ThrowIfCancellationRequested(); calls++;
            if (!request["assignment"]!.GetValue<string>().Contains("outsideKeyboard")) throw new Exception("Oktavbefund fehlt im Reparaturauftrag.");
            return Task.FromResult(new JsonObject { ["text"] = good, ["inputTokens"] = 7, ["outputTokens"] = 8, ["estimatedCostUSD"] = .03 });
        };
        try
        {
            automaticRegisterReview = true;
            var fixedResult = await CompileCheckedCompositionAsync(bad, source, CancellationToken.None);
            if (calls != 1 || fixedResult["octaveReview"]?["status"]?.GetValue<string>() != "corrected" || fixedResult["originalLilyPond"]?.GetValue<string>() != bad || fixedResult["composition"]?.GetValue<string>() != good) throw new Exception("Oktavfehler werden nicht automatisch mit genau einem Versuch korrigiert.");
            if (Math.Abs(Numeric(fixedResult["estimatedCostUSD"]) - .05) > .000001 || Numeric(fixedResult["inputTokens"]) != 16 || Numeric(fixedResult["outputTokens"]) != 18) throw new Exception("Kosten der Oktavkorrektur fehlen.");
            var clean = await CompileCheckedCompositionAsync(good, source, CancellationToken.None);
            if (calls != 1 || clean["composition"]?.GetValue<string>() != good) throw new Exception("Unauffällige Komposition löst unnötige KI-Korrektur aus.");
            var drift = clean["score"]!.DeepClone().AsObject();
            var treble = drift["tr"]![0]!["nt"]!.AsArray();
            for (int i = 1; i < 8; i++) treble.Add(new JsonArray(10d+i, 1d, 100d, 80d, 0d, 1d));
            if (RegisterIssues(drift, bad).Count == 0 || RegisterIssues(drift, good).Count != 0) throw new Exception("Relative Oktavwanderung wird nicht gezielt erkannt.");
            var changed = clean["score"]!.DeepClone().AsObject(); changed["tr"]![0]!["nt"]![0]![2] = 61d;
            if (OctaveOnlyChange(clean["score"]!.AsObject(), changed)) throw new Exception("Tonklassenänderung als Oktavkorrektur akzeptiert.");
            changed = clean["score"]!.DeepClone().AsObject(); changed["tr"]![0]!["nt"]![0]![1] = 2d;
            if (OctaveOnlyChange(clean["score"]!.AsObject(), changed)) throw new Exception("Rhythmusänderung als Oktavkorrektur akzeptiert.");
            foreach (string refused in new[] { bad, good.Replace("c'4 e'", "cis'4 e'") })
            {
                int attempts = 0;
                registerRepairTransport = (_, _) => { attempts++; return Task.FromResult(new JsonObject { ["text"] = refused }); };
                bool rejected = false;
                try { await CompileCheckedCompositionAsync(bad, source, CancellationToken.None); }
                catch (RegisterRepairException e) { rejected = e.Report["octaveReview"]?["status"]?.GetValue<string>() == "rejected" && e.Report["originalLilyPond"]?.GetValue<string>() == bad; }
                if (!rejected || attempts != 1) throw new Exception("Ungültige Oktavkorrektur wird übernommen oder wiederholt angefragt.");
            }
            registerRepairTransport = (_, _) => throw new OperationCanceledException();
            bool cancelled = false;
            try { await CompileCheckedCompositionAsync(bad, source, CancellationToken.None); } catch (OperationCanceledException) { cancelled = true; }
            if (!cancelled) throw new Exception("Abbruch der Oktavkorrektur wird ignoriert.");
            // Exercise correction of an existing slot through the same refresh
            // operation as the Noten tab, including editor, playback and history.
            int selected = slots.SelectedIndex, free = Array.FindIndex(documents, d => d == null);
            var history = pieceHistory.Select(d => d.DeepClone().AsObject()).ToArray();
            try
            {
                var existing = await CompileCompositionAsync(good, source, CancellationToken.None);
                await AcceptCompositionAsync(existing, free, "Oktavtest", "gemini", "test-register");
                composition.Text = bad;
                registerRepairTransport = (_, _) => Task.FromResult(new JsonObject { ["text"] = good });
                await RefreshNotationAsync();
                if (Current!["octaveReview"]?["status"]?.GetValue<string>() != "corrected" || composition.Text.Contains("\\relative") || !currentMidi!.SequenceEqual(Convert.FromBase64String(fixedResult["sourceMidiData"]!.GetValue<string>()))) throw new Exception("Bestehender Slot erhält die korrigierte Fassung nicht.");
                if (ToHistory(Current)["octaveReview"]?["status"]?.GetValue<string>() != "corrected") throw new Exception("Oktavprüfung geht beim Speichern verloren.");
                var valid = currentMidi.ToArray(); var score = Score!.ToJsonString();
                composition.Text = bad;
                registerRepairTransport = (_, _) => Task.FromResult(new JsonObject { ["text"] = bad });
                bool rejected = false;
                try { await RefreshNotationAsync(); } catch (RegisterRepairException) { rejected = true; }
                if (!rejected || !currentMidi.SequenceEqual(valid) || Score.ToJsonString() != score) throw new Exception("Gescheiterte Oktavkorrektur ersetzt die letzte gültige Musik.");
            }
            finally
            {
                documents[free] = null; pieceHistory.Clear(); pieceHistory.AddRange(history); RefreshHistory(); RefreshSlots(); slots.SelectedIndex = selected; await DisplayCurrentAsync();
            }
            AtomicFile.WriteText(Path.Combine(output, "Oktavpruefung.json"), fixedResult.ToJsonString());
            AtomicFile.WriteText(Path.Combine(output, "Oktavpruefung.ly"), good);
        }
        finally { registerRepairTransport = null; automaticRegisterReview = previousSetting; lastDiagnostic = previousDiagnostic; UpdateDiagnostic(); }
    }
}

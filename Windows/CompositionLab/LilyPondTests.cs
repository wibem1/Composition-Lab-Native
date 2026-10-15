using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed partial class MainForm
{
    async Task RunLilyPondTestsAsync(string output)
    {
        const string source = """
            \version "2.24.0"
            \header { title = "Auftakt – Originalprüfung" tagline = ##f }
            upper = \relative c' {
              \key f \major \time 2/4 \tempo 4 = 104 \partial 8 c8\mf |
              \repeat unfold 4 { f8. g16 a8 bes | c4 c8( d16 c) | }
              \pageBreak
              \repeat unfold 4 { <f, a>4( <e g>) | <f a>2 | }
            }
            lower = \relative c {
              \clef bass \key f \major \time 2/4 \partial 8 r8 |
              \repeat unfold 8 { f8 c' a c | f,4 c' | }
            }
            \score { \new PianoStaff << \new Staff { \upper } \new Staff { \lower } >> \layout {} \midi {} }
            """;
        foreach (string unsafeSource in new[] { @"\score { c4 } #(system ""anything"")", @"\include ""private.ly"" \score { c4 }", @"\score { c4 } $(ly:gulp-file ""private"")" })
        {
            bool failed = false; try { LilyPondCompiler.Prepare(unsafeSource); } catch (InvalidDataException) { failed = true; }
            if (!failed) throw new Exception("Ausführbarer LilyPond-Code wird nicht abgefangen.");
        }
        if (LilyPondCompiler.Prepare(source) != source) throw new Exception("Vollständiger LilyPond-Code wurde verändert.");
        var generated = await Engraver.CompileAsync(source);
        if (generated.Cached || generated.Pages.Length != 2) throw new Exception("Originalnoten werden nicht vollständig in zwei Seiten gesetzt.");
        var cached = await Engraver.CompileAsync(source);
        if (!cached.Cached || !cached.Midi.SequenceEqual(generated.Midi) || !cached.Pages.SequenceEqual(generated.Pages)) throw new Exception("LilyPond-Cache verändert Musik oder Seiten.");
        var noMidi = await Engraver.CompileAsync("\\version \"2.24.0\"\n\\score { { c'4 d' e' f' } }");
        if (noMidi.Midi.Length < 14 || noMidi.Pages.Length == 0) throw new Exception("LilyPond ohne expliziten MIDI-Block bleibt stumm.");
        var separate = await Engraver.CompileAsync("\\version \"2.24.0\"\n\\score { { c'4 d' e' f' } \\layout {} }\n\\score { { c'4 d' e' f' } \\midi {} }");
        if (separate.Pages.Length != 1 || separate.Midi.Length < 14) throw new Exception("Getrennte Layout- und MIDI-Scores werden nicht unterstützt.");
        bool multipleRejected = false;
        try { await Engraver.CompileAsync("\\version \"2.24.0\"\n\\score { { c'4 d' e' f' } \\layout {} \\midi {} }\n\\score { { g'4 a' b' c'' } \\layout {} \\midi {} }"); }
        catch (InvalidDataException) { multipleRejected = true; }
        if (!multipleRejected) throw new Exception("Mehrere Scores werden unbemerkt auf eine MIDI-Datei gekürzt.");
        using (var cancelled = new CancellationTokenSource())
        {
            cancelled.Cancel(); bool stopped = false;
            try { await Engraver.CompileAsync(source, cancelled.Token); } catch (OperationCanceledException) { stopped = true; }
            if (!stopped) throw new Exception("Abbruch der lokalen Ausgabe wird ignoriert.");
        }
        string music = "Originalprüfung\n```lilypond\n" + source + "\n```";
        var result = await CompileCompositionAsync(music, new JsonObject { ["provider"] = "gemini", ["model"] = "test-local", ["estimatedCostUSD"] = .01 }, CancellationToken.None);
        if (result["conversionAICalls"]!.GetValue<int>() != 0 || result["composition"]!.GetValue<string>() != music) throw new Exception("Lokale Ausgabe verändert die Komposition oder ruft die KI auf.");
        var notes = result["score"]!["tr"]!.AsArray().OfType<JsonObject>().SelectMany(t => t["nt"]!.AsArray()).OfType<JsonArray>().ToArray();
        if (!notes.Any(n => n[0]!.GetValue<double>() == 0 && n[2]!.GetValue<double>() == 60) || !notes.Any(n => n[0]!.GetValue<double>() == .5 && n[2]!.GetValue<double>() == 65)) throw new Exception("Achtelauftakt oder erste volle Taktposition falsch.");
        int selected = slots.SelectedIndex, free = Array.FindIndex(documents, d => d == null);
        var old = documents[free];
        var savedHistory = pieceHistory.Select(d => d.DeepClone().AsObject()).ToArray();
        try
        {
            await AcceptCompositionAsync(result, free, "Lokaler Test", "gemini", "test-local");
            if (currentLilyPond == null || currentMidi == null || !currentMidi.SequenceEqual(generated.Midi)) throw new Exception("Wiedergabe verwendet nicht das originale LilyPond-MIDI.");
            string file = Path.Combine(output, "Original-LilyPond.clab"); AtomicFile.WriteText(file, Current!.ToJsonString());
            await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = Current!.DeepClone() });
            if (ToHistory(Current!)["sourceMidiData"]?.GetValue<string>() != result["sourceMidiData"]?.GetValue<string>()) throw new Exception("Projekt und Verlauf verlieren das Original-MIDI.");
            var navigation = new TaskCompletionSource<bool>();
            void Loaded(object? sender, Microsoft.Web.WebView2.Core.CoreWebView2NavigationCompletedEventArgs e)
            {
                if (e.WebErrorStatus == Microsoft.Web.WebView2.Core.CoreWebView2WebErrorStatus.OperationCanceled) return;
                if (e.IsSuccess) navigation.TrySetResult(true);
                else navigation.TrySetException(new Exception("Originalvorschau: " + e.WebErrorStatus));
            }
            web.CoreWebView2.NavigationCompleted += Loaded;
            try { RenderLilyPond(); if (!await navigation.Task.WaitAsync(TimeSpan.FromSeconds(20))) throw new Exception("Originalvorschau lädt nicht."); }
            finally { web.CoreWebView2.NavigationCompleted -= Loaded; }
            await Task.Delay(150);
            string state = JsonSerializer.Deserialize<string>(await web.ExecuteScriptAsync("JSON.stringify({count:document.images.length,loaded:Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0),page:currentPage,scale:scale})"))!;
            var preview = JsonNode.Parse(state)!;
            if (preview["count"]!.GetValue<int>() != 2 || !preview["loaded"]!.GetValue<bool>()) throw new Exception("Offline-Notenseiten sind nicht sichtbar.");
            await PreviewCommand("page(1);zoom(10)");
            if (await web.ExecuteScriptAsync("currentPage===2 && scale===110") != "true") throw new Exception("Seitenauswahl oder Zoom im Originalnotensatz funktioniert nicht.");
            await PreviewCommand("page(-1)");
            using (var capture = File.Create(Path.Combine(output, "LilyPond-Original-Preview.png"))) await web.CoreWebView2.CapturePreviewAsync(Microsoft.Web.WebView2.Core.CoreWebView2CapturePreviewImageFormat.Png, capture);
            AtomicFile.WriteBytes(Path.Combine(output, "LilyPond-Original.mid"), generated.Midi);
            AtomicFile.WriteText(Path.Combine(output, "LilyPond-Messung.json"), new JsonObject { ["compileMilliseconds"] = generated.Milliseconds, ["pageCount"] = generated.Pages.Length, ["cached"] = cached.Cached, ["aiCalls"] = 0 }.ToJsonString());
        }
        finally
        {
            pieceHistory.Clear(); pieceHistory.AddRange(savedHistory); RefreshHistory();
            documents[free] = old; RefreshSlots(); slots.SelectedIndex = selected; await DisplayCurrentAsync();
        }
    }
}

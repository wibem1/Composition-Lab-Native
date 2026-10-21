using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed partial class MainForm
{
    async Task RunLilyPondTestsAsync(string output)
    {
        // Real child-process regression: preserve output at a deadline and
        // distinguish it from an explicit user cancellation.
        var probeStart = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe")) {
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardOutput = true, RedirectStandardError = true
        };
        foreach (string arg in new[] { "-NoProfile", "-NonInteractive", "-Command", "[Console]::Error.Write('engraving-timeout-probe['); [Console]::Error.Flush(); Start-Sleep -Seconds 30" }) probeStart.ArgumentList.Add(arg);
        bool deadlineReported = false;
        try { await EngravingProcess.RunAsync(probeStart, TimeSpan.FromSeconds(3), CancellationToken.None); }
        catch (EngravingTimeoutException e) { deadlineReported = e.Log.Contains("engraving-timeout-probe[") && e.Milliseconds >= 2500; }
        if (!deadlineReported) throw new Exception("Notensatz-Zeitlimit verliert Ursache oder Prozessprotokoll.");
        using (var stop = new CancellationTokenSource()) {
            stop.CancelAfter(TimeSpan.FromMilliseconds(250)); bool cancelledByUser = false;
            try { await EngravingProcess.RunAsync(probeStart, TimeSpan.FromSeconds(30), stop.Token); }
            catch (OperationCanceledException) { cancelledByUser = true; }
            if (!cancelledByUser) throw new Exception("Benutzerabbruch wird mit Zeitlimit verwechselt.");
        }
        // Parent exits, descendant retains both inherited pipe handles. The old
        // implementation stopped enforcing its deadline after parent exit.
        var heldPipeStart = new ProcessStartInfo(probeStart.FileName) {
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardOutput = true, RedirectStandardError = true
        };
        foreach (string arg in new[] { "-NoProfile", "-NonInteractive", "-Command",
            "[Console]::Error.Write('inherited-pipe-marker['); [Console]::Error.Flush(); $s=[Diagnostics.ProcessStartInfo]::new($env:ComSpec, '/c ping -n 16 127.0.0.1 >nul'); $s.UseShellExecute=$false; $s.CreateNoWindow=$true; [void][Diagnostics.Process]::Start($s)" }) heldPipeStart.ArgumentList.Add(arg);
        bool inheritedPipeBounded = false;
        try { await EngravingProcess.RunAsync(heldPipeStart, TimeSpan.FromSeconds(2), CancellationToken.None); }
        catch (EngravingTimeoutException e) {
            inheritedPipeBounded = e.Log.Contains("inherited-pipe-marker[") && e.Milliseconds < 10000;
        }
        if (!inheritedPipeBounded) throw new Exception("Offene geerbte Prozesskanäle umgehen das Zeitlimit oder verlieren das Teilprotokoll.");
        if (LilyPondCompiler.ProgressMessage("(process:25856): GLib-GIO-WARNING **: Failed to open application manifest C:\\Windows") != null ||
            LilyPondCompiler.ProgressMessage("Parsing...") == null)
            throw new Exception("Bibliothekswarnungen verdrängen die Notensatz-Statusanzeige.");
        await ScoreSourceMapper.SelfTestAsync();
        WorkspaceRevisionGate.SelfTest();
        ProjectPieceCodec.SelfTest();
        ProjectWorkspaceCodec.SelfTest();
        SlotDocumentStore.SelfTest();
        var previewDocument = ScorePreviewDocument.Build(new[] { "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>" });
        if (!previewDocument.Contains("Auswahl im Editor öffnen", StringComparison.Ordinal) ||
            !previewDocument.Contains("pointerdown", StringComparison.Ordinal) ||
            !previewDocument.Contains("source\\.ly:", StringComparison.Ordinal))
            throw new Exception("Eigenständiges Notenansichtsmodul liefert keine interaktive Quelltextauswahl.");
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
        foreach (string unsafeSource in new[] { @"\bookOutputName ""outside"" \score { { c4 } }", @"\score { c4 } #(system ""anything"")", @"\include ""private.ly"" \score { c4 }", @"\score { c4 } $(ly:gulp-file ""private"")" })
        {
            bool failed = false; try { await LilyPondCompiler.PrepareAsync(unsafeSource); } catch (InvalidDataException) { failed = true; }
            if (!failed) throw new Exception("Ausführbarer LilyPond-Code wird nicht abgefangen.");
        }
        if (await LilyPondCompiler.PrepareAsync(source) != source) throw new Exception("Vollständiger LilyPond-Code wurde verändert.");
        // Regression for the real Pastorale diagnostic: literal spacing moments
        // must reach the bundled engraver without a second model request.
        string pastoralePath = Path.Combine(Path.GetDirectoryName(Environment.GetEnvironmentVariable("COMPOSITION_LAB_BACKUP_FIXTURE"))!, "pastorale-violin-cello.ly");
        string pastorale = await File.ReadAllTextAsync(pastoralePath);
        if (await LilyPondCompiler.PrepareAsync(pastorale) != pastorale)
            throw new Exception("Pastorale-Original wird durch die Quellprüfung verändert.");
        // Deliberately hostile inherited config: the bundle must not use it.
        string? inheritedFontConfig = Environment.GetEnvironmentVariable("FONTCONFIG_FILE");
        LilyPondOutput pastoraleOutput;
        try {
            Environment.SetEnvironmentVariable("FONTCONFIG_FILE", Path.Combine(output, "missing-external-fontconfig.conf"));
            pastoraleOutput = await Engraver.CompileAsync(pastorale);
        }
        finally { Environment.SetEnvironmentVariable("FONTCONFIG_FILE", inheritedFontConfig); }
        var pastoraleCached = await Engraver.CompileAsync(pastorale);
        if (!pastoraleCached.Cached || !pastoraleCached.Midi.SequenceEqual(pastoraleOutput.Midi))
            throw new Exception("Pastorale wird bei erneuter Übernahme unnötig neu gesetzt.");
        AtomicFile.WriteText(Path.Combine(output, "Pastorale-Messung.json"), new JsonObject {
            ["coldEngravingMilliseconds"] = pastoraleOutput.Milliseconds,
            ["pages"] = pastoraleOutput.Pages.Length, ["repeatWasCached"] = pastoraleCached.Cached
        }.ToJsonString());
        if (pastoraleOutput.Pages.Length == 0 || pastoraleOutput.Midi.Length < 14)
            throw new Exception("Pastorale wird nicht als Noten und MIDI ausgegeben.");
        var generated = await Engraver.CompileAsync(source);
        if (generated.Cached || generated.Pages.Length != 2) throw new Exception("Originalnoten werden nicht vollständig in zwei Seiten gesetzt.");
        // V4.13: SVG notation must retain the source references required
        // for click-to-editor selection. Raster-like SVG images are insufficient.
        if (!generated.Pages.Any(page => page.Contains("textedit:", StringComparison.OrdinalIgnoreCase)))
            throw new Exception("LilyPond SVG enthält keine Point-and-Click-Quelltextverweise.");
        var cached = await Engraver.CompileAsync(source);
        if (!cached.Cached || !cached.Midi.SequenceEqual(generated.Midi) || !cached.Pages.SequenceEqual(generated.Pages)) throw new Exception("LilyPond-Cache verändert Musik oder Seiten.");
        var recoveryRoot = Path.Combine(output, "Cache-Recovery");
        var cacheProbe = new LilyPondCompiler(recoveryRoot);
        var cacheOriginal = await cacheProbe.CompileAsync(source);
        var cachedMidi = Directory.EnumerateFiles(recoveryRoot, "*", SearchOption.AllDirectories).Single(path =>
            Path.GetExtension(path).Equals(".mid", StringComparison.OrdinalIgnoreCase) ||
            Path.GetExtension(path).Equals(".midi", StringComparison.OrdinalIgnoreCase));
        await File.WriteAllTextAsync(cachedMidi, "corrupt cache fixture");
        var recoveredCache = await cacheProbe.CompileAsync(source);
        if (recoveredCache.Cached || !recoveredCache.Midi.SequenceEqual(cacheOriginal.Midi))
            throw new Exception("Ein beschädigter Notensatzcache wird nicht originalgetreu neu aufgebaut.");
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
        // Regression: a failed automatic octave repair must not discard a valid score.
        const string extreme = "\\version \"2.24.0\"\n\\score { \\new Staff { \\clef bass c,,,4 } \\layout {} \\midi {} }";
        var previousTransport = registerRepairTransport;
        bool previousReview = automaticRegisterReview, previousForce = forceRegisterReview;
        try
        {
            automaticRegisterReview = true; forceRegisterReview = false;
            int unwantedAICalls = 0;
            registerRepairTransport = (_, _) => {
                unwantedAICalls++;
                throw new InvalidOperationException("Eine automatische KI-Korrektur darf nicht starten.");
            };
            var preserved = await CompileCheckedCompositionAsync(extreme,
                new JsonObject { ["provider"] = "gemini", ["model"] = "offline-test", ["estimatedCostUSD"] = 0d }, CancellationToken.None);
            if (preserved["octaveReview"]?["status"]?.GetValue<string>() != "issues" ||
                preserved["sourceMidiData"]?.GetValue<string>() is not string midiSource || midiSource.Length < 20 ||
                preserved["composition"]?.GetValue<string>() != extreme || unwantedAICalls != 0)
                throw new Exception("Die lokale Oktavprüfung muss die Originalkomposition ohne KI-Anfrage erhalten.");
        }
        finally
        {
            registerRepairTransport = previousTransport;
            automaticRegisterReview = previousReview; forceRegisterReview = previousForce;
        }
        var notes = result["score"]!["tr"]!.AsArray().OfType<JsonObject>().SelectMany(t => t["nt"]!.AsArray()).OfType<JsonArray>().ToArray();
        if (!notes.Any(n => n[0]!.GetValue<double>() == 0 && n[2]!.GetValue<double>() == 60) || !notes.Any(n => n[0]!.GetValue<double>() == .5 && n[2]!.GetValue<double>() == 65)) throw new Exception("Achtelauftakt oder erste volle Taktposition falsch.");
        int originalTab = tabs.SelectedIndex;
        int selected = slots.SelectedIndex, free = documents.FirstFreeIndex();
        var old = documents[free];
        var savedHistory = pieceHistory.Select(d => d.DeepClone().AsObject()).ToArray();
        try
        {
            // Exact reported Pastorale must traverse the real import, document,
            // preview and export path, rather than only producing compiler files.
            var pastoraleResult = await CompileCompositionAsync(pastorale, new JsonObject { ["provider"] = "gemini", ["model"] = "offline-pastorale" }, CancellationToken.None);
            var pastoraleTracks = pastoraleResult["score"]!["tr"]!.AsArray().OfType<JsonObject>()
                .Where(t => t["nt"]!.AsArray().Count > 0).ToArray();
            if (pastoraleTracks.Length != 2 || !pastoraleTracks.Any(t => t["pg"]!.GetValue<int>() == 40) || !pastoraleTracks.Any(t => t["pg"]!.GetValue<int>() == 42))
                throw new Exception("Pastorale verliert Violine oder Violoncello beim MIDI-Import.");
            foreach (var track in pastoraleTracks) {
                double end = track["nt"]!.AsArray().OfType<JsonArray>().Max(n => n[0]!.GetValue<double>() + n[1]!.GetValue<double>());
                // 46 bars in 6/8 = 138 quarter-note beats (MIDI note-off can be shortened).
                if (end < 137 || end > 139) throw new Exception("Pastorale wird vor dem 46. Takt abgeschnitten: " + end);
            }
            await AcceptCompositionAsync(pastoraleResult, free, "Pastorale-Test", "gemini", "offline-pastorale");
            if (currentMidi == null || !currentMidi.SequenceEqual(pastoraleOutput.Midi) || currentLilyPond?.Pages.Length != pastoraleOutput.Pages.Length)
                throw new Exception("Pastorale verliert Original-MIDI oder Notenseiten bei der Übernahme.");
            await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = Current!.DeepClone() });
            await WriteMusicExportAsync(Path.Combine(output, "Pastorale.ly"), "ly");
            await WriteMusicExportAsync(Path.Combine(output, "Pastorale.mid"), "mid");
            if (File.ReadAllText(Path.Combine(output, "Pastorale.ly")).ReplaceLineEndings("\n") != ExtractLilyPond(pastorale).ReplaceLineEndings("\n"))
                throw new Exception("Pastorale-LilyPond-Export verändert die Quelle (Zeilenenden ausgenommen).");
            if (!File.ReadAllBytes(Path.Combine(output, "Pastorale.mid")).SequenceEqual(pastoraleOutput.Midi))
                throw new Exception("Pastorale-MIDI-Export verändert die Originalbytes.");
            AtomicFile.WriteText(Path.Combine(output, "Pastorale-Verarbeitung.json"), pastoraleResult.ToJsonString());
            // Regression for the uploaded 4.2.9 Romanze diagnostic: A4 paper
            // and literal spacing must pass the same local pipeline unchanged.
            string romanzePath = Path.Combine(Path.GetDirectoryName(Environment.GetEnvironmentVariable("COMPOSITION_LAB_BACKUP_FIXTURE"))!, "romanze-violin-piano-a4.ly");
            string romanze = await File.ReadAllTextAsync(romanzePath);
            if (await LilyPondCompiler.PrepareAsync(romanze) != romanze) throw new Exception("Romanze-A4-Original wird verändert.");
            var romanzeOutput = await Engraver.CompileAsync(romanze);
            var romanzeResult = await CompileCompositionAsync(romanze, new JsonObject { ["provider"] = "gemini", ["model"] = "offline-romanze" }, CancellationToken.None);
            var romanzeTracks = romanzeResult["score"]!["tr"]!.AsArray().OfType<JsonObject>().Where(t => t["nt"]!.AsArray().Count > 0).ToArray();
            if (!romanzeTracks.Any(t => t["pg"]!.GetValue<int>() == 40) || !romanzeTracks.Any(t => t["pg"]!.GetValue<int>() == 0))
                throw new Exception("Romanze verliert Violine oder Klavier.");
            foreach (var track in romanzeTracks) {
                double end = track["nt"]!.AsArray().OfType<JsonArray>().Max(n => n[0]!.GetValue<double>() + n[1]!.GetValue<double>());
                if (end < 147 || end > 149) throw new Exception("Romanze wird vor dem 37. Takt abgeschnitten: " + end);
            }
            documents[free] = null;
            await AcceptCompositionAsync(romanzeResult, free, "Romanze-A4-Test", "gemini", "offline-romanze");
            if (currentMidi == null || !currentMidi.SequenceEqual(romanzeOutput.Midi) || currentLilyPond?.Pages.Length != romanzeOutput.Pages.Length || romanzeOutput.Pages.Length == 0)
                throw new Exception("Romanze verliert Original-MIDI oder SVG-Seiten.");
            await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = Current!.DeepClone() });
            await WriteMusicExportAsync(Path.Combine(output, "Romanze.ly"), "ly");
            await WriteMusicExportAsync(Path.Combine(output, "Romanze.mid"), "mid");
            if (File.ReadAllText(Path.Combine(output, "Romanze.ly")).ReplaceLineEndings("\n") != ExtractLilyPond(romanze).ReplaceLineEndings("\n") || !File.ReadAllBytes(Path.Combine(output, "Romanze.mid")).SequenceEqual(romanzeOutput.Midi))
                throw new Exception("Romanze-Export verändert Originalquelle oder MIDI.");
            AtomicFile.WriteText(Path.Combine(output, "Romanze-Messung.json"), new JsonObject {
                ["passed"] = true, ["coldEngravingMilliseconds"] = romanzeOutput.Milliseconds,
                ["pages"] = romanzeOutput.Pages.Length, ["tracks"] = romanzeTracks.Length, ["bars"] = 37
            }.ToJsonString());
            // Release the test slot before accepting the independent second score.
            documents[free] = null;
            await AcceptCompositionAsync(result, free, "Lokaler Test", "gemini", "test-local");
            if (currentLilyPond == null || currentMidi == null || !currentMidi.SequenceEqual(generated.Midi)) throw new Exception("Wiedergabe verwendet nicht das originale LilyPond-MIDI.");
            string file = Path.Combine(output, "Original-LilyPond.clab"); AtomicFile.WriteText(file, Current!.ToJsonString());
            await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = Current!.DeepClone() });
            if (ToHistory(Current!)["sourceMidiData"]?.GetValue<string>() != result["sourceMidiData"]?.GetValue<string>()) throw new Exception("Projekt und Verlauf verlieren das Original-MIDI.");
            var navigation = new TaskCompletionSource<bool>();
            ulong expectedNavigation = 0;
            void Starting(object? sender, Microsoft.Web.WebView2.Core.CoreWebView2NavigationStartingEventArgs e)
            {
                if (currentLilyPondPreviewUri != null && new Uri(e.Uri).Query == new Uri(currentLilyPondPreviewUri).Query) expectedNavigation = e.NavigationId;
            }
            void Loaded(object? sender, Microsoft.Web.WebView2.Core.CoreWebView2NavigationCompletedEventArgs e)
            {
                if (expectedNavigation == 0 || e.NavigationId != expectedNavigation) return;
                if (e.IsSuccess) navigation.TrySetResult(true);
                else navigation.TrySetException(new Exception("Originalvorschau: " + e.WebErrorStatus));
            }
            web.CoreWebView2.NavigationStarting += Starting;
            web.CoreWebView2.NavigationCompleted += Loaded;
            try { RenderLilyPond(); if (!await navigation.Task.WaitAsync(TimeSpan.FromSeconds(20))) throw new Exception("Originalvorschau lädt nicht."); }
            finally { web.CoreWebView2.NavigationStarting -= Starting; web.CoreWebView2.NavigationCompleted -= Loaded; }
            await Task.Delay(150);
            string state = JsonSerializer.Deserialize<string>(await web.ExecuteScriptAsync("JSON.stringify({count:document.querySelectorAll('.page svg').length,loaded:!!document.querySelector('.page:not([hidden]) svg')&&document.querySelector('.page:not([hidden]) svg').getBoundingClientRect().width>0,links:document.querySelectorAll('.page a').length,page:currentPage,scale:scale})"))!;
            var preview = JsonNode.Parse(state)!;
            if (preview["count"]!.GetValue<int>() != 2 || !preview["loaded"]!.GetValue<bool>() ||
                preview["links"]!.GetValue<int>() == 0)
                throw new Exception("Interaktive LilyPond-SVG-Seiten oder Quelltextverweise sind nicht sichtbar.");
            await PreviewCommand("page(1);zoom(10)");
            if (await web.ExecuteScriptAsync("currentPage===2 && scale===110") != "true") throw new Exception("Seitenauswahl oder Zoom im Originalnotensatz funktioniert nicht.");
            await PreviewCommand("page(-1)");
            using (var capture = File.Create(Path.Combine(output, "LilyPond-Original-Preview.png"))) await web.CoreWebView2.CapturePreviewAsync(Microsoft.Web.WebView2.Core.CoreWebView2CapturePreviewImageFormat.Png, capture);
            // End-to-end UI check: click a real SVG note, mark it, and
            // hand its LilyPond source location to the editor.
            string clickResult = await web.ExecuteScriptAsync("""
                (() => {
                  const a = Array.from(document.querySelectorAll('.page a')).find(n =>
                    /source\.ly:\d+:\d+:\d+/i.test(n.getAttribute('href') || n.getAttribute('xlink:href') || ''));
                  if (!a) return 'no-note-link';
                  a.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true}));
                  if (document.getElementById('openSelection').disabled) return 'selection-disabled';
                  document.getElementById('openSelection').click();
                  return 'sent';
                })()
                """);
            if (clickResult != "\"sent\"")
                throw new Exception("SVG-Note konnte nicht markiert und an den Editor übergeben werden: " + clickResult);
            // WebView messages cross a process boundary; wait for the observable
            // result instead of assuming a fixed 200 ms delivery time on CI.
            for (int i = 0; i < 100 && (tabs.SelectedIndex != 0 || composition.SelectionLength < 1); i++)
                await Task.Delay(50);
            if (tabs.SelectedIndex != 0 || composition.SelectionLength < 1)
                throw new Exception($"SVG-Notenauswahl landet nicht im LilyPond-Editor. Tab={tabs.SelectedIndex}, Auswahl={composition.SelectionLength}, Status={status.Text}");
            // Regression for mouse click-and-drag: two linked notes must become
            // a visible multi-selection, not merely receive an invisible click.
            tabs.SelectedIndex = 1;
            RenderLilyPond();
            await Task.Delay(250);
            string dragResult = await web.ExecuteScriptAsync("""
                (() => {
                  const notes=Array.from(document.querySelectorAll('.page:not([hidden]) a'))
                    .filter(a=>/source\.ly:\d+:\d+:\d+/i.test(a.getAttribute('href')||a.getAttribute('xlink:href')||''));
                  if(notes.length<2)return 'insufficient-notes';
                  notes[0].dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,button:0,buttons:1}));
                  notes[1].dispatchEvent(new PointerEvent('pointermove',{bubbles:true,button:0,buttons:1}));
                  document.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,button:0,buttons:0}));
                  return document.querySelectorAll('.page a.selected').length>=2 && !document.getElementById('openSelection').disabled
                    ? 'drag-ok' : 'drag-failed';
                })()
                """);
            if (dragResult != "\"drag-ok\"")
                throw new Exception("Klick-und-Ziehen markiert keine Notenpassage: " + dragResult);
            // Reproduce the user flow: edit the visible composition, then click
            // the actual Noten-tab button rather than calling the compiler only.
            string edited = music.Replace("Auftakt – Originalprüfung", "Bearbeitet – G statt C").Replace("c8\\mf", "g'8\\mf").Replace("4 = 104", "4 = 116");
            var previousPages = currentLilyPond!.Pages.ToArray();
            composition.Text = edited;
            edited = composition.Text; // RichTextBox owns the visible newline representation.
            tabs.SelectedIndex = 1;
            await Task.Delay(100);
            var refreshButton = WorkspaceViewState.ControlsIn(this).OfType<Button>().Single(b => b.Text == "Aktualisieren");
            if (!refreshButton.Visible || !refreshButton.Enabled) throw new Exception("Aktualisieren ist im Noten-Tab nicht erreichbar.");
            refreshButton.PerformClick();
            for (int i = 0; busy && i < 1200; i++) await Task.Delay(50);
            if (busy || Current!["lilyPondSource"]?.GetValue<string>() != edited || currentLilyPond!.Pages.SequenceEqual(previousPages) || currentMidi!.SequenceEqual(generated.Midi)) throw new Exception($"Aktualisieren: busy={busy}, source={Current!["lilyPondSource"]?.GetValue<string>() == edited}, pagesChanged={!currentLilyPond!.Pages.SequenceEqual(previousPages)}, midiChanged={!currentMidi!.SequenceEqual(generated.Midi)}, status={status.Text}");
            if (Current["concept"]?.GetValue<string>() != music || Current["title"]?.GetValue<string>() != "Bearbeitet – G statt C") throw new Exception("Bearbeitung überschreibt Original oder aktualisiert Titel nicht.");
            var editedNotes = Score!["tr"]!.AsArray().OfType<JsonObject>().SelectMany(t => t["nt"]!.AsArray()).OfType<JsonArray>();
            if (!editedNotes.Any(n => n[0]!.GetValue<double>() == 0 && n[2]!.GetValue<double>() == 67)) throw new Exception("Bearbeitete Tonhöhe fehlt im neuen MIDI/Score.");
            if (!ExtractLilyPond(EditableLilyPondText(Current)).Contains("g'8\\mf")) throw new Exception("LilyPond-Export verwendet den alten Quelltext.");
            if (ToHistory(Current)["lilyPondSource"]?.GetValue<string>() != edited) throw new Exception("Projekt/Verlauf verliert die bearbeitete Quelle.");
            var validMidi = currentMidi.ToArray(); var validScore = Score.ToJsonString(); var validPages = currentLilyPond.Pages.ToArray();
            composition.Text = edited.Replace("\\upper", "\\unbekannteStimme");
            bool invalidRejected = false;
            try { await RefreshNotationAsync(); } catch (InvalidDataException) { invalidRejected = true; }
            if (!invalidRejected || !currentMidi.SequenceEqual(validMidi) || Score.ToJsonString() != validScore || !currentLilyPond.Pages.SequenceEqual(validPages) || Current["lilyPondSource"]?.GetValue<string>() != edited || lastDiagnostic?["stage"]?.GetValue<string>() != "failed") throw new Exception("Fehlerhafte Bearbeitung ersetzt die letzte gültige Ausgabe.");
            await DisplayCurrentAsync();
            if (!currentMidi!.SequenceEqual(validMidi) || composition.Text == edited || Current!["lilyPondSource"]?.GetValue<string>() != edited) throw new Exception("Neuladen verliert gültige Ausgabe oder fehlerhaften Entwurf.");
            composition.Text = edited; await RefreshNotationAsync();
            string expectedSvg = currentLilyPond!.Pages[0];
            bool editedVisible = false;
            for (int i = 0; i < 100; i++)
            {
                string displayed = JsonSerializer.Deserialize<string>(await web.ExecuteScriptAsync("typeof images!=='undefined' ? images[0] : ''")) ?? "";
                bool rendered = await web.ExecuteScriptAsync("!!document.querySelector('.page:not([hidden]) svg') && document.querySelector('.page:not([hidden]) svg').getBoundingClientRect().width>0") == "true";
                if (displayed == expectedSvg && rendered) { editedVisible = true; break; }
                await Task.Delay(50);
            }
            if (!editedVisible) throw new Exception("Der Browser zeigt nach Aktualisieren weiterhin alte Noten.");
            using (var capture = File.Create(Path.Combine(output, "LilyPond-Edited-Preview.png"))) await web.CoreWebView2.CapturePreviewAsync(Microsoft.Web.WebView2.Core.CoreWebView2CapturePreviewImageFormat.Png, capture);
            AtomicFile.WriteText(Path.Combine(output, "Edited-LilyPond.clab"), Current!.ToJsonString());
            var saved = JsonNode.Parse(File.ReadAllText(Path.Combine(output, "Edited-LilyPond.clab")))!.AsObject();
            if (AppliedLilyPondText(saved) != edited || saved["sourceMidiData"]?.GetValue<string>() != Convert.ToBase64String(currentMidi!)) throw new Exception("CLAB verliert die erfolgreiche Bearbeitung.");
            await WriteMusicExportAsync(Path.Combine(output, "Bearbeitet.ly"), "ly");
            await WriteMusicExportAsync(Path.Combine(output, "Bearbeitet.musicxml"), "musicxml");
            await WriteMusicExportAsync(Path.Combine(output, "Bearbeitet.mid"), "mid");
            if (File.ReadAllText(Path.Combine(output, "Bearbeitet.ly")) != ExtractLilyPond(edited) || !File.ReadAllBytes(Path.Combine(output, "Bearbeitet.mid")).SequenceEqual(currentMidi!)) throw new Exception("Dateiexporte verwenden die alte Fassung.");
            // Frescobaldi uses LilyPond's default PDF backend. Exercise the saved
            // .ly itself, without the app's preparation or SVG-specific options.
            var pdfStart = new ProcessStartInfo(Path.Combine(AppContext.BaseDirectory, "LilyPond", "bin", "lilypond.exe"))
            { WorkingDirectory = output, UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
            foreach (string arg in new[] { "-dno-point-and-click", "--output=Frescobaldi-Exportpruefung", "Bearbeitet.ly" }) pdfStart.ArgumentList.Add(arg);
            using (var pdfProcess = Process.Start(pdfStart)!)
            {
                var pdfOut = pdfProcess.StandardOutput.ReadToEndAsync(); var pdfErr = pdfProcess.StandardError.ReadToEndAsync();
                try { await pdfProcess.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(60)); }
                catch (TimeoutException) { pdfProcess.Kill(true); throw; }
                string pdfLog = await pdfOut + await pdfErr;
                AtomicFile.WriteText(Path.Combine(output, "Frescobaldi-Exportpruefung.log"), pdfLog);
                string pdfPath = Path.Combine(output, "Frescobaldi-Exportpruefung.pdf");
                if (pdfProcess.ExitCode != 0 || !File.Exists(pdfPath) || !File.ReadAllBytes(pdfPath).Take(5).SequenceEqual(Encoding.ASCII.GetBytes("%PDF-"))) throw new Exception("LilyPond-Dateiexport scheitert bei normalem PDF-Aufruf: " + pdfLog);
            }
            var xmlCheck = await core.RunAsync(new JsonObject { ["operation"] = "import-musicxml", ["data"] = Convert.ToBase64String(File.ReadAllBytes(Path.Combine(output, "Bearbeitet.musicxml"))), ["title"] = "Exportprüfung" });
            if (!xmlCheck["score"]!["tr"]!.AsArray().OfType<JsonObject>().SelectMany(t => t["nt"]!.AsArray()).OfType<JsonArray>().Any(n => n[2]!.GetValue<double>() == 67)) throw new Exception("MusicXML enthält die bearbeitete Tonhöhe nicht.");
            AtomicFile.WriteBytes(Path.Combine(output, "LilyPond-Original.mid"), generated.Midi);
            AtomicFile.WriteText(Path.Combine(output, "LilyPond-Messung.json"), new JsonObject { ["compileMilliseconds"] = generated.Milliseconds, ["pageCount"] = generated.Pages.Length, ["cached"] = cached.Cached, ["aiCalls"] = 0 }.ToJsonString());
        }
        finally
        {
            tabs.SelectedIndex = originalTab;
            pieceHistory.Clear(); pieceHistory.AddRange(savedHistory); RefreshHistory();
            documents[free] = old; RefreshSlots(); slots.SelectedIndex = selected; await DisplayCurrentAsync();
        }
    }
}

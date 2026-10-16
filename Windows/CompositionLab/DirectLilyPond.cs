using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace CompositionLab;

internal sealed partial class MainForm
{
    LilyPondCompiler? lilyCompiler;
    LilyPondOutput? currentLilyPond;
    string? currentLilyPondPreviewUri;
    LilyPondCompiler Engraver => lilyCompiler ??= new(Path.Combine(dataDirectory, "LilyPondCache"));

    static string AppliedLilyPondText(JsonObject document) => document["lilyPondSource"]?.GetValue<string>() ?? document["concept"]?.GetValue<string>() ?? "";
    string EditableLilyPondText(JsonObject document) => Regex.IsMatch(composition.Text, @"\\(?:version|score)\b|```(?:lilypond|ly)\b", RegexOptions.IgnoreCase) ? composition.Text : AppliedLilyPondText(document);

    async Task ApplyLilyPondEditsAsync()
    {
        if (busy || Current == null) return;
        var document = Current;
        int generation = displayGeneration;
        string editorText = composition.Text;
        string music = EditableLilyPondText(document);
        try
        {
            pending = new CancellationTokenSource(); SetBusy(true);
            var source = new JsonObject { ["assignment"] = document["assignment"]?.DeepClone(), ["provider"] = document["provider"]?.DeepClone(),
                ["model"] = document["model"]?.DeepClone(), ["estimatedCostUSD"] = document["costUSD"]?.DeepClone(),
                ["inputTokens"] = document["inputTokens"]?.DeepClone(), ["outputTokens"] = document["outputTokens"]?.DeepClone() };
            var result = await CompileCheckedCompositionAsync(music, source, pending.Token, updateDiagnostic: false);
            // A different slot or a new edit must never receive an older result.
            if (!ReferenceEquals(Current, document) || generation != displayGeneration || composition.Text != editorText)
            { SetStatus("Der Quelltext oder das Stück wurde inzwischen geändert. Bitte erneut aktualisieren."); return; }
            SaveScoreUndoSnapshot(document);
            document["lilyPondSource"] = result["composition"]!.DeepClone();
            document["description"] = result["composition"]!.DeepClone();
            foreach (string field in new[] { "octaveReview", "originalLilyPond" }) if (result[field] != null) document[field] = result[field]!.DeepClone();
            document["costUSD"] = result["estimatedCostUSD"]?.DeepClone();
            document["inputTokens"] = result["inputTokens"]?.DeepClone(); document["outputTokens"] = result["outputTokens"]?.DeepClone();
            document["directLilyPond"] = true;
            document["sourceMidiData"] = result["sourceMidiData"]!.DeepClone();
            document["score"] = result["score"]!.DeepClone();
            document["title"] = result["score"]!["ti"]!.DeepClone();
            result["entryPoint"] = "edited-lilypond";
            lastDiagnostic = result.DeepClone().AsObject(); UpdateDiagnostic();
            RememberPiece(document); RefreshSlots(); SaveLocalState();
            await DisplayCurrentAsync();
            SetMusicStatus(result, result["octaveReview"]?["status"]?.GetValue<string>() == "corrected" ? "Oktavlagen korrigiert und geprüft. Notation und MIDI aktualisiert." : "Bearbeiteter LilyPond-Code übernommen. Notation und MIDI aktualisiert.");
        }
        catch (OperationCanceledException) { SetStatus("Aktualisierung abgebrochen. Die letzte gültige Ausgabe bleibt erhalten."); }
        catch (Exception e)
        {
            if (e is RegisterRepairException failure) lastDiagnostic = failure.Report.DeepClone().AsObject();
            else lastDiagnostic = new JsonObject { ["format"] = "composition-lab-native-diagnostic", ["interfaceVersion"] = Version,
                ["entryPoint"] = "edited-lilypond", ["stage"] = "failed", ["composition"] = music, ["error"] = e.Message,
                ["conversionAICalls"] = 0, ["lastValidSource"] = AppliedLilyPondText(document) };
            UpdateDiagnostic();
            throw;
        }
        finally { pending?.Dispose(); pending = null; SetBusy(false); }
    }

    async Task<JsonObject> CompileCompositionAsync(string music, JsonObject source, CancellationToken token, bool updateDiagnostic = true)
    {
        SetStatus("LilyPond erzeugt MIDI und Originalnoten lokal …");
        string notation = ExtractLilyPond(music);
        var watch = Stopwatch.StartNew();
        var compiled = await Engraver.CompileAsync(notation, token);
        string title = Regex.Match(notation, "\\btitle\\s*=\\s*\"([^\"]+)\"") is { Success: true } m ? m.Groups[1].Value : "Komposition";
        var imported = await core.RunAsync(new JsonObject { ["operation"] = "import-midi", ["data"] = Convert.ToBase64String(compiled.Midi), ["title"] = title }, token);
        var score = imported["score"]!.DeepClone().AsObject(); score["ti"] = title;
        watch.Stop();
        var result = new JsonObject
        {
            ["format"] = "composition-lab-native-diagnostic", ["interfaceVersion"] = Version,
            ["assignment"] = source["assignment"]?.DeepClone(), ["provider"] = source["provider"]?.DeepClone(),
            ["model"] = source["model"]?.DeepClone(), ["reasoning"] = source["reasoning"]?.DeepClone(),
            ["composition"] = music, ["score"] = score, ["sourceMidiData"] = Convert.ToBase64String(compiled.Midi),
            ["directLilyPond"] = true, ["stage"] = "completed", ["conversionEngine"] = "LilyPond " + LilyPondCompiler.Version,
            ["conversionMilliseconds"] = Math.Round(watch.Elapsed.TotalMilliseconds), ["engravingMilliseconds"] = Math.Round(compiled.Milliseconds),
            ["engravingCacheHit"] = compiled.Cached, ["engravingPageCount"] = compiled.Pages.Length,
            ["engravingLog"] = compiled.Log, ["conversionAICalls"] = 0,
            ["translationInputTokens"] = 0, ["translationOutputTokens"] = 0,
            ["inputTokens"] = source["inputTokens"]?.DeepClone() ?? JsonValue.Create(0),
            ["outputTokens"] = source["outputTokens"]?.DeepClone() ?? JsonValue.Create(0),
            ["estimatedCostUSD"] = source["estimatedCostUSD"]?.DeepClone() ?? JsonValue.Create(0d),
            ["sourceDiagnostic"] = source.DeepClone()
        };
        if (updateDiagnostic) { lastDiagnostic = result.DeepClone().AsObject(); UpdateDiagnostic(); }
        return result;
    }

    async Task RebuildOriginalAsync()
    {
        if (busy) return;
        var document = Current ?? throw new InvalidOperationException("Kein Stück geladen.");
        string music = document["concept"]?.GetValue<string>() ?? "";
        if (!ContainsFinishedMusic(music)) throw new InvalidOperationException("Dieses Stück enthält kein LilyPond-Original.");
        int destination = Array.FindIndex(documents, d => d == null);
        if (destination < 0) throw new InvalidOperationException("Bitte einen Slot für die Originalausgabe freimachen. Die bisherige Fassung bleibt erhalten.");
        try
        {
            pending = new CancellationTokenSource(); SetBusy(true);
            var input = new JsonObject { ["assignment"] = document["assignment"]?.DeepClone(), ["provider"] = document["provider"]?.DeepClone(), ["model"] = document["model"]?.DeepClone(),
                ["estimatedCostUSD"] = document["costUSD"]?.DeepClone(), ["inputTokens"] = document["inputTokens"]?.DeepClone(), ["outputTokens"] = document["outputTokens"]?.DeepClone() };
            var result = await CompileCheckedCompositionAsync(music, input, pending.Token);
            await AcceptCompositionAsync(result, destination, document["assignment"]?.GetValue<string>() ?? "", document["provider"]?.GetValue<string>() ?? activeProvider, document["model"]?.GetValue<string>() ?? SelectedModelId);
            SetMusicStatus(result, "Originalnoten und Original-MIDI in Slot " + (destination + 1) + ". Die bisherige Fassung bleibt erhalten.");
        }
        finally { pending?.Dispose(); pending = null; SetBusy(false); }
    }

    // LilyPond's point-and-click links contain source.ly:line:column.
    // Only source locations from the locally generated score are accepted.
    void SelectLilyPondSource(JsonNode message)
    {
        if (Current == null || currentLilyPond == null) return;
        int line = (int?)message["line"] ?? 0, col = (int?)message["column"] ?? 0;
        int endLine = (int?)message["endLine"] ?? line;
        int endCol = (int?)message["endColumn"] ?? col;
        string source = AppliedLilyPondText(Current);
        var mapping = ScoreSourceMapper.Map(source, composition.Text,
            new(line, col), new(endLine, endCol));
        if (mapping.Failure == ScoreSourceMapper.Error.StaleSource)
        {
            SetStatus("Notenbild und Editor unterscheiden sich. Erst Notation aktualisieren.", true);
            return;
        }
        if (mapping.Range is not { } selected)
        {
            SetStatus("Die Notenauswahl enthält keine gültige Quelltextposition.", true);
            return;
        }
        tabs.SelectedIndex = 0;
        composition.Focus();
        composition.SelectionStart = selected.Start;
        composition.SelectionLength = selected.Length;
        composition.ScrollToCaret();
        SetStatus("LilyPond-Zeilen " + line + "–" + endLine + " im Editor markiert.");
    }

    void RenderLilyPond()
    {
        if (!webReady || currentLilyPond == null) return;
        // Render SVG inline, not inside <img>: point-and-click anchors need
        // to be actual DOM nodes to be clickable and selectable.
        string content = ScorePreviewDocument.Build(currentLilyPond.Pages);
        string folder = Path.Combine(dataDirectory, "LilyPondPreviews"); Directory.CreateDirectory(folder);
        string hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(Encoding.UTF8.GetBytes(content)));
        string path = Path.Combine(folder, hash + ".html");
        if (!File.Exists(path)) AtomicFile.WriteText(path, content);
        currentLilyPondPreviewUri = new Uri(path).AbsoluteUri + "?view=" + Guid.NewGuid().ToString("N");
        web.CoreWebView2.Navigate(currentLilyPondPreviewUri);
    }
}

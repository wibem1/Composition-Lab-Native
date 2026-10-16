using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace CompositionLab;

// File interchange and the original LilyPond-to-Hacklily handoff.
internal sealed partial class MainForm
{
    internal static string ExtractLilyPond(string text)
    {
        var fenced = Regex.Match(text, @"```(?:lilypond|ly)?[^\S\r\n]*\r?\n(?<source>[\s\S]*?)```", RegexOptions.IgnoreCase);
        string source = fenced.Success ? fenced.Groups["source"].Value.Trim() : text.Trim();
        if (!source.Contains(@"\version") && !source.Contains(@"\score"))
            throw new InvalidOperationException("Dieses Stück enthält keinen LilyPond-Quelltext. MIDI- und MusicXML-Exporte sind weiterhin verfügbar.");
        return source + "\n";
    }
    async Task ExportLilyPondAsync()
    {
        if (Current == null) throw new InvalidOperationException("Kein Stück geladen.");
        string source = ExtractLilyPond(EditableLilyPondText(Current));
        using var dialog = new SaveFileDialog { Filter = "LilyPond|*.ly", FileName = SafeName(pieceTitle.Text) + ".ly", OverwritePrompt = true };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        await WriteMusicExportAsync(dialog.FileName, "ly");
        SetStatus("LilyPond-Quelltext gespeichert.");
    }
    void OpenHacklily()
    {
        if (Current == null) throw new InvalidOperationException("Kein Stück geladen.");
        string source = ExtractLilyPond(EditableLilyPondText(Current));
        // Open a short local path so Windows' shell command length cannot truncate
        // the full composition URL. No clipboard access is required for transfer.
        string folder = Path.Combine(dataDirectory, "Hacklily"); Directory.CreateDirectory(folder);
        string path = Path.Combine(folder, Guid.NewGuid().ToString("N") + ".html");
        AtomicFile.WriteText(path, HacklilyHandoffHtml(source));
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
        SetStatus("Quelltext an Hacklily übergeben. URL-Importe sind dort schreibgeschützt; zum Bearbeiten eine Kopie speichern.");
    }

    internal static string HacklilySourceUri(string source) => "https://www.hacklily.org/wasm#src=" + Uri.EscapeDataString(source);
    internal static string HacklilyHandoffHtml(string source)
    {
        string target = JsonSerializer.Serialize(HacklilySourceUri(source));
        return "<!doctype html><html lang=\"de\"><meta charset=\"utf-8\"><meta name=\"referrer\" content=\"no-referrer\"><title>An Hacklily übergeben</title>" +
            "<p>Die Komposition wird in Hacklily geöffnet. Zum Bearbeiten dort eine Kopie speichern.</p>" +
            "<p><a id=\"open\">In Hacklily öffnen</a></p><script>const target=" + target + ";document.getElementById('open').href=target;location.replace(target);</script></html>";
    }

    async Task SaveDocumentAsync()
    {
        if (Current == null) throw new InvalidOperationException("Kein Stück geladen.");
        using var dialog = new SaveFileDialog { Filter = "Composition Lab Stück|*.clab", FileName = SafeName(pieceTitle.Text) + ".clab", OverwritePrompt = true };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = Current.DeepClone() });
        AtomicFile.WriteText(dialog.FileName, Current.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
        currentPath = dialog.FileName; SetStatus("Stück gespeichert.");
    }
    async Task ExportAsync(string extension)
    {
        if (Score == null) throw new InvalidOperationException("Kein Stück geladen.");
        using var dialog = new SaveFileDialog { Filter = extension == "mid" ? "MIDI|*.mid" : "MusicXML|*.musicxml",
            Title = extension == "musicxml" ? "MusicXML sichern – vereinfachte Austauschfassung" : "MIDI sichern",
            FileName = SafeName(pieceTitle.Text) + "." + extension, OverwritePrompt = true };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        await WriteMusicExportAsync(dialog.FileName, extension);
        SetStatus(extension == "musicxml" && currentLilyPond != null ? "MusicXML als vereinfachte Austauschfassung gespeichert." : "Export gespeichert.");
    }
    async Task WriteMusicExportAsync(string path, string extension)
    {
        var document = Current ?? throw new InvalidOperationException("Kein Stück geladen.");
        if (extension == "ly")
        {
            AtomicFile.WriteText(path, ExtractLilyPond(EditableLilyPondText(document))); return;
        }
        string requestedSource = EditableLilyPondText(document);
        if (requestedSource != AppliedLilyPondText(document))
        {
            if (busy) throw new InvalidOperationException("Bitte die laufende Anfrage abwarten und dann speichern.");
            await ApplyLilyPondEditsAsync();
            bool correctedRequest = document["octaveReview"]?["status"]?.GetValue<string>() == "corrected" && document["originalLilyPond"]?.GetValue<string>() == requestedSource;
            if (!ReferenceEquals(Current, document) || (AppliedLilyPondText(document) != requestedSource && !correctedRequest)) throw new InvalidOperationException("Der bearbeitete Quelltext wurde noch nicht übernommen. Bitte erneut aktualisieren und speichern.");
        }
        if (extension == "mid" && currentMidi != null) { AtomicFile.WriteBytes(path, currentMidi); return; }
        var result = await core.RunAsync(new JsonObject { ["operation"] = extension == "mid" ? "midi" : "musicxml", ["score"] = document["score"]!.DeepClone(), ["options"] = extension == "mid" ? null : notationOptions?.DeepClone() });
        AtomicFile.WriteBytes(path, Convert.FromBase64String(result["data"]!.GetValue<string>()));
    }

}

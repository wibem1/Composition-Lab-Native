using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace CompositionLab;

// Recovery/import workflow stays separate from the form layout and playback.
internal sealed partial class MainForm
{
    async Task RecoverDisplayedMusicAsync()
    {
        var source = pendingComposition?.DeepClone().AsObject();
        if (source == null || !ContainsFinishedMusic(source["composition"]?.GetValue<string>() ?? ""))
        {
            // Restore older conversations too: the diagnostic can have been overwritten by a later error.
            var matches = Regex.Matches(chat.Text, @"```(?:lilypond|ly)?[^\S\r\n]*\r?\n[\s\S]*?```", RegexOptions.IgnoreCase);
            for (int i = matches.Count - 1; i >= 0; i--)
                if (ContainsFinishedMusic(matches[i].Value)) { source = new JsonObject { ["composition"] = matches[i].Value, ["assignment"] = "Aus dem Chatverlauf wiederhergestellt", ["estimatedCostUSD"] = 0d }; break; }
        }
        if (source == null || !ContainsFinishedMusic(source["composition"]?.GetValue<string>() ?? "")) source = lastDiagnostic?.DeepClone().AsObject();
        if (source == null) throw new InvalidOperationException("Keine fertige Komposition im Chatverlauf oder der Diagnose vorhanden.");
        int destination = documents.FirstFreeIndex();
        if (destination < 0) throw new InvalidOperationException("Bitte zuerst einen Slot freimachen.");
        await TranslateStoredDiagnosticAsync(source, destination);
    }
    // One interpretation of the diagnostic schema for import and recovery.
    // A diagnostic can carry the finished source in 'composition', 'text',
    // or the preserved sourceDiagnostic after a failed conversion.
    static string FinishedMusicFromDiagnostic(JsonObject source)
    {
        foreach (string name in new[] { "composition", "text" })
        {
            var value = source[name]?.GetValue<string>();
            if (!string.IsNullOrWhiteSpace(value) && ContainsFinishedMusic(value))
                return value;
        }
        if (source["sourceDiagnostic"] is JsonObject nested)
            return FinishedMusicFromDiagnostic(nested);
        return "";
    }

    async Task TranslateStoredDiagnosticAsync(JsonObject source, int destination)
    {
        if (busy) throw new InvalidOperationException("Bitte die laufende Anfrage abwarten.");
        string music = FinishedMusicFromDiagnostic(source);
        if (!ContainsFinishedMusic(music)) throw new InvalidOperationException("Diese Antwort enthält keine fertige LilyPond-Komposition.");
        string assignmentText = source["assignment"]?.GetValue<string>() ?? "Die vorhandene fertige Komposition unverändert technisch übertragen.";
        PreservePendingComposition(music, source, assignmentText, source["provider"]?.GetValue<string>() ?? activeProvider, source["model"]?.GetValue<string>() ?? SelectedModelId);
        try
        {
            pending = new CancellationTokenSource(); SetBusy(true);
            var request = new JsonObject { ["assignment"] = assignmentText, ["provider"] = activeProvider, ["model"] = SelectedModelId,
                ["effort"] = effort.SelectedIndex switch { 0 => "low", 2 => "high", _ => "medium" } };
            var result = await TranslateExistingAsync(music, request, source, pending.Token);
            await AcceptCompositionAsync(result, destination, assignmentText,
                source["provider"]?.GetValue<string>() ?? activeProvider,
                source["model"]?.GetValue<string>() ?? SelectedModelId);
            SetMusicStatus(result, "Vorhandene Komposition in Slot " + (destination + 1) + " übernommen; MIDI bereit.");
        }
        catch (CoreRequestException e) { lastDiagnostic = e.Diagnostic; UpdateDiagnostic(); SaveLocalState(); throw; }
        finally { pending?.Dispose(); pending = null; SetBusy(false); }
    }


    async Task ImportDiagnosticAsync()
    {
        if (busy) { SetStatus("Bitte zuerst die laufende Anfrage abwarten.", true); return; }
        int free = documents.FirstFreeIndex();
        if (free < 0) { SetStatus("Alle zehn Slots belegt. Bitte einen Slot freimachen.", true); return; }
        using var dialog = new OpenFileDialog
        {
            Title = "Composition-Lab-Diagnose importieren",
            Filter = "Diagnosedateien (*.json)|*.json|Alle Dateien (*.*)|*.*",
            FilterIndex = 1,
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        try { await ImportPathAsync(dialog.FileName, free); }
        catch (Exception e)
        {
            SetStatus("Diagnose nicht übernommen: " + e.Message, true);
            MessageBox.Show(this, "Die Diagnosedatei wurde nicht übernommen. Bestehende Stücke bleiben erhalten.\n\n" +
                e.Message, "Diagnoseimport", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

}

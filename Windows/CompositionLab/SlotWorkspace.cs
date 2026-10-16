using System.Text.Json;
using System.Text;
using System.Text.Json.Nodes;

namespace CompositionLab;

// Workspace slots, selection and document import: separate from application startup.
internal sealed partial class MainForm
{
    JsonObject CreateDocument(JsonObject score, string concept, string userAssignment = "") => new()
    {
        ["format"] = "composition-lab-document", ["version"] = 1,
        ["savedAt"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - 978307200,
        ["title"] = score["ti"]?.GetValue<string>() ?? "Komposition", ["score"] = score,
        ["concept"] = concept, ["description"] = concept, ["measures"] = measures.Text, ["meter"] = meter.Text,
        ["tempo"] = tempo.Text, ["musicalKey"] = musicalKey.Text, ["ensemble"] = ensemble.Text,
        ["assignment"] = userAssignment
    };

    async Task DisplayCurrentAsync()
    {
        int generation = ++displayGeneration;
        player.Close(); currentMidi = null; currentXML = null; currentLilyPond = null; currentPath = null;
        var document = Current;
        loadingIdea = true;
        try
        {
            editableIdea = document?["description"]?.GetValue<string>() ?? document?["concept"]?.GetValue<string>() ?? document?["assignment"]?.GetValue<string>() ?? slotDrafts.GetValueOrDefault(slots.SelectedIndex, "");
            composition.Text = editableIdea; composition.ClearUndo(); assignment.Text = editableIdea;
        }
        finally { loadingIdea = false; }
        playback.Text = "00:00 / 00:00";
        pieceInfo.ForeColor = StudioTheme.Muted; notationCurrent.ForeColor = StudioTheme.Ink;
        if (document == null) { cost.Text = "Kosten: –"; pieceInfo.Text = "Wähle links ein Stück oder komponiere etwas Neues."; pieceTitle.Text = "Raum für deine nächste Idee"; scoreJSON.Clear(); validation.Clear(); notationCurrent.Text = "Aktuelles Stück: –"; if (webReady) web.NavigateToString("<html><body>Kein Stück geladen.</body></html>"); return; }
        pieceTitle.Text = document["title"]?.GetValue<string>() ?? "Komposition"; notationCurrent.Text = "Aktuelles Stück: " + pieceTitle.Text;
        var scoreInfo = document["score"];
        pieceInfo.Text = string.Join("  ·  ", new[] { document["ensemble"]?.GetValue<string>(), scoreInfo?["k"]?.GetValue<string>(), scoreInfo?["bpm"]?.ToString() is string bpm ? bpm + " BPM" : null }.Where(v => !string.IsNullOrWhiteSpace(v)));
        bool registerWarning = RegisterNeedsAttention(document);
        if (registerWarning)
        {
            pieceInfo.Text = "Oktavprüfung offen · " + pieceInfo.Text;
            pieceInfo.ForeColor = Color.Firebrick;
            notationCurrent.Text = "Oktavprüfung offen: " + pieceTitle.Text;
            notationCurrent.ForeColor = Color.Firebrick;
        }
        scoreJSON.Text = document["score"]?.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) ?? "";
        validation.Text = "Technische Prüfung läuft …";
        playerBpm = double.TryParse(document["score"]?["bpm"]?.ToString(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out double bpmValue) ? (int)Math.Round(bpmValue) : 96; tempoOverride = false; foreach (var transport in transports) transport.Tempo.Text = playerBpm.ToString();
        try
        {
            if ((document["directLilyPond"]?.GetValue<bool>() == true) && ContainsFinishedMusic(AppliedLilyPondText(document)))
            {
                var compiled = await Engraver.CompileAsync(ExtractLilyPond(AppliedLilyPondText(document)));
                if (generation != displayGeneration) return;
                currentLilyPond = compiled; currentMidi = compiled.Midi;
            }
            var score = document["score"]!.DeepClone();
            var midi = await core.RunAsync(new JsonObject { ["operation"] = "midi", ["score"] = score });
            if (generation != displayGeneration) return;
            currentMidi ??= Convert.FromBase64String(midi["data"]!.GetValue<string>());
            var xml = await core.RunAsync(new JsonObject { ["operation"] = "musicxml", ["score"] = score.DeepClone(), ["options"] = notationOptions?.DeepClone() });
            if (generation != displayGeneration) return;
            currentXML = Encoding.UTF8.GetString(Convert.FromBase64String(xml["data"]!.GetValue<string>()));
            if (webReady) RenderNotation();
            validation.Text = (currentLilyPond != null ? "Originalkomposition mit LilyPond gesetzt. MIDI direkt aus dem Original; keine zusätzliche KI-Anfrage. MusicXML ist eine vereinfachte Austauschansicht.\n\n" : "Technische Partiturprüfung bestanden. MIDI und MusicXML erzeugt.\n\n") + (document["title"]?.GetValue<string>() ?? "");
            if (registerWarning)
            {
                validation.Text = "Oktavprüfung offen: Das unveränderte Original wurde ausgegeben.\n" + (document["octaveReview"]?["message"]?.GetValue<string>() ?? "Auffällige klingende Oktavlagen erkannt.") + "\n\n" + validation.Text;
                SetMusicStatus(document, "");
            }
            cost.Text = document["costUSD"] is JsonValue c && c.TryGetValue<double>(out double n) ? "Stück ca. $" + n.ToString("0.0000") : "Kosten: –";
        }
        catch (Exception e) { if (generation == displayGeneration) SetStatus(e.Message, true); }
    }

    void RefreshSlots()
    {
        int selected = slots.SelectedIndex;
        refreshingSlots = true;
        try { slots.BeginUpdate(); slots.Items.Clear();
            for (int i = 0; i < documents.Length; i++) slots.Items.Add($"{i + 1:00}  " + (documents[i]?["title"]?.GetValue<string>() ?? "— frei —"));
            slots.SelectedIndex = selected < 0 ? 0 : selected; slots.EndUpdate(); RefreshCards();
        } finally { refreshingSlots = false; }
    }
    void RefreshCards()
    {

        for (int i = 0; i < slotCards.Count; i++)
        {
            var title = documents[i]?["title"]?.GetValue<string>() ?? "";
            var card = (PieceCard)slotCards[i]; card.PieceTitle = title; card.Occupied = documents[i] != null;
            card.Selected = i == slots.SelectedIndex; card.Text = (i + 1) + ": " + title; card.Invalidate();
            slotTips.SetToolTip(card, title + "\nKlick: auswählen / freien Platz laden. Rechtsklick: laden, speichern, löschen. Dateidrop möglich.");
        }
        for (int i = 0; i < notationCards.Count; i++) { notationCards[i].Text = (documents[i] == null ? "" : "●") + (i + 1); notationCards[i].Selected = i == slots.SelectedIndex; notationCards[i].Invalidate(); }
    }
    void SelectFreeSlot()
    { int free = Array.FindIndex(documents, d => d == null); if (free < 0) SetStatus("Alle Slots belegt.", true); else slots.SelectedIndex = free; }

    async Task OpenAsync(int? destination = null)
    {
        if (busy) return;
        using var dialog = new OpenFileDialog { Filter = "Musikdateien und Diagnosen|*.clab;*.mid;*.midi;*.musicxml;*.xml;*.json;*.clabproject|Alle Dateien|*.*" };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        if (destination.HasValue) await ImportIntoSlotAsync(dialog.FileName, destination.Value);
        else await ImportPathAsync(dialog.FileName);
    }
    async Task ImportPathAsync(string path, int? targetSlot = null)
    {
        int destination = targetSlot ?? (Current == null ? slots.SelectedIndex : Array.FindIndex(documents, d => d == null));
        if (destination < 0) throw new InvalidOperationException("Alle Slots belegt. Bitte einen Slot freimachen.");
        if (Path.GetExtension(path).Equals(".clabproject", StringComparison.OrdinalIgnoreCase)) { await LoadProjectPathAsync(path); return; }
        var data = await File.ReadAllBytesAsync(path); JsonObject document;
        if (Path.GetExtension(path).Equals(".clab", StringComparison.OrdinalIgnoreCase))
        {
            document = JsonNode.Parse(data)!.AsObject();
            await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = document.DeepClone() });
        }
        else if (Path.GetExtension(path).Equals(".json", StringComparison.OrdinalIgnoreCase))
        {
            var sourceDiagnostic = JsonNode.Parse(data)!.AsObject();
            if (ContainsFinishedMusic(FinishedMusicFromDiagnostic(sourceDiagnostic)))
            { await TranslateStoredDiagnosticAsync(sourceDiagnostic, destination); return; }
            var raw = RepairLegacyText(sourceDiagnostic["scoreResponse"]?.GetValue<string>() ?? throw new InvalidDataException("Diese Diagnose enthält keine technische Partiturantwort."));
            var response = await core.RunAsync(new JsonObject { ["operation"] = "recover-score", ["response"] = raw });
            document = CreateDocument(response["score"]!.DeepClone().AsObject(),
                RepairLegacyText(sourceDiagnostic["composition"]?.GetValue<string>() ?? ""), RepairLegacyText(sourceDiagnostic["assignment"]?.GetValue<string>() ?? ""));
            foreach (string field in new[] { "provider", "model", "inputTokens", "outputTokens" })
                if (sourceDiagnostic[field] != null) document[field] = sourceDiagnostic[field]!.DeepClone();
            document["costUSD"] = sourceDiagnostic["estimatedCostUSD"]?.DeepClone();
            lastDiagnostic = sourceDiagnostic.DeepClone().AsObject();
            lastDiagnostic["recoveredScore"] = document["score"]!.DeepClone();
            lastDiagnostic["recoveryVersion"] = Version; UpdateDiagnostic();
        }
        else
        {
            bool midi = new[] { ".mid", ".midi" }.Contains(Path.GetExtension(path).ToLowerInvariant());
            var response = await core.RunAsync(new JsonObject { ["operation"] = midi ? "import-midi" : "import-musicxml",
                ["data"] = Convert.ToBase64String(data), ["title"] = Path.GetFileNameWithoutExtension(path) });
            document = CreateDocument(response["score"]!.DeepClone().AsObject(), "Import: " + Path.GetFileName(path));
            if (!midi) document["originalMusicXMLData"] = Convert.ToBase64String(data);
        }
        documents[destination] = document; RememberPiece(document); RefreshSlots(); slots.SelectedIndex = destination;
        await DisplayCurrentAsync(); currentPath = Path.GetExtension(path).Equals(".clab", StringComparison.OrdinalIgnoreCase) ? path : null;
        SaveLocalState(); SetStatus("Datei geladen.");
    }
    async Task GuardAsync(Func<Task> action)
    { try { await action(); } catch (Exception e) { SetStatus(e.Message, true); } }

    async Task ImportIntoSlotAsync(string path, int index)
    {
        if (busy) return;
        if (documents[index] != null && !testMode && MessageBox.Show(this,
            $"Stück {index + 1} durch die gewählte Datei ersetzen? Die gespeicherte Datei bleibt erhalten.", "Stück laden", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        // Parse and validate before assigning: failed imports leave the old piece intact.
        await ImportPathAsync(path, index);
    }
    async Task DeleteSlotAsync(int index)
    {
        if (busy || documents[index] == null) return;
        if (!testMode && MessageBox.Show(this, $"Stück {index + 1} aus der App entfernen? Gespeicherte Dateien bleiben erhalten.",
            "Stück löschen", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        documents[index] = null; RefreshCards(); SaveLocalState();
        if (slots.SelectedIndex == index) await DisplayCurrentAsync();
        SetStatus($"Stück {index + 1} gelöscht.");
    }

}

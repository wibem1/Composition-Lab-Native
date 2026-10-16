using System.Text.Json;
using System.Text.Json.Nodes;

namespace CompositionLab;

// Portable project serialization and loading, separate from menu/layout construction.
internal sealed partial class MainForm
{

    async Task SaveProjectAsync()
    {
        using var dialog = new SaveFileDialog { Filter = "Composition Lab Arbeitsplatz|*.clabproject", FileName = SafeName(projectName) + ".clabproject", OverwritePrompt = true }; if (dialog.ShowDialog(this) != DialogResult.OK) return;
        var settings = new JsonObject { ["provider"] = activeProvider, ["models"] = JsonSerializer.SerializeToNode(models), ["efforts"] = new JsonObject(), ["measures"] = measures.Text, ["meter"] = meter.Text, ["tempo"] = tempo.Text, ["key"] = musicalKey.Text, ["ensemble"] = ensemble.Text, ["prompt"] = assignment.Text, ["zoomPercent"] = 100 };
        var project = ProjectWorkspaceCodec.Encode(projectName, settings, composition.Text, documents, slots.SelectedIndex, pieceHistory, chat.Text, activeProvider, SelectedModelId);
        await core.RunAsync(new JsonObject { ["operation"] = "validate-workspace", ["document"] = project.DeepClone() }); AtomicFile.WriteText(dialog.FileName, project.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
    }
    JsonObject ToHistory(JsonObject document) => ProjectPieceCodec.ToHistory(document, activeProvider, SelectedModelId);
    async Task LoadProjectAsync()
    {
        if (busy) return; using var dialog = new OpenFileDialog { Filter = "Composition Lab Arbeitsplatz|*.clabproject" }; if (dialog.ShowDialog(this) != DialogResult.OK) return;
        await LoadProjectPathAsync(dialog.FileName);
    }
    JsonObject RestoreProjectPiece(JsonObject saved)
    {
        var restored = CreateDocument(
            saved["score"]!.DeepClone().AsObject(),
            saved["concept"]?.GetValue<string>() ?? "");
        ProjectPieceCodec.CopySavedPieceMetadata(saved, restored);
        return restored;
    }

    async Task LoadProjectPathAsync(string path)
    {
        var project = JsonNode.Parse(await File.ReadAllTextAsync(path))!.AsObject();
        await core.RunAsync(new JsonObject {
            ["operation"] = "validate-workspace",
            ["document"] = project.DeepClone()
        });
        if (project["slots"] is not JsonArray savedSlots)
            throw new InvalidDataException("Diese Datei enthält keine Stück-Plätze.");

        // Validate every imported piece before changing the user's current workspace.
        var imported = new JsonObject?[documents.Length];
        for (int i = 0; i < Math.Min(imported.Length, savedSlots.Count); i++)
        {
            if (savedSlots[i] is not JsonObject saved) continue;
            var restored = RestoreProjectPiece(saved);
            await core.RunAsync(new JsonObject {
                ["operation"] = "validate-document",
                ["document"] = restored.DeepClone()
            });
            imported[i] = restored;
        }
        if (!testMode && MessageBox.Show(this, "Aktuellen Arbeitsplatz ersetzen?",
            "Projekt laden", MessageBoxButtons.YesNo) != DialogResult.Yes) return;

        var settings = project["settings"]!.AsObject();
        if (settings["models"] is JsonObject savedModels)
            foreach (var pair in savedModels)
                if (models.ContainsKey(pair.Key))
                    models[pair.Key] = pair.Value!.GetValue<string>();

        measures.Text = settings["measures"]?.GetValue<string>() ?? "";
        meter.Text = settings["meter"]?.GetValue<string>() ?? "";
        tempo.Text = settings["tempo"]?.GetValue<string>() ?? "";
        musicalKey.Text = settings["key"]?.GetValue<string>() ?? "";
        ensemble.Text = settings["ensemble"]?.GetValue<string>() ?? "";
        assignment.Text = settings["prompt"]?.GetValue<string>() ?? "";

        loadingSettings = true;
        try
        {
            activeProvider = settings["provider"]?.GetValue<string>() ?? activeProvider;
            if (!models.ContainsKey(activeProvider)) activeProvider = "anthropic";
            provider.SelectedIndex = activeProvider switch {
                "openai" => 2, "gemini" => 0, _ => 1
            };
            SelectModel();
            apiKey.Text = keys.GetValueOrDefault(activeProvider, "");
            remember.Checked = keys.ContainsKey(activeProvider);
        }
        finally { loadingSettings = false; }

        pieceHistory.Clear();
        if (project["history"] is JsonArray history)
            foreach (var saved in history.OfType<JsonObject>())
                pieceHistory.Add(RestoreProjectPiece(saved));
        RefreshHistory();

        documents.ReplaceAll(imported);
        projectName = project["name"]?.GetValue<string>() ?? "Unbenannt";
        chat.Text = project["chat"]?.GetValue<string>() ?? "";
        loadingIdea = true;
        try
        {
            composition.Text = project["concept"]?.GetValue<string>()
                ?? settings["prompt"]?.GetValue<string>() ?? "";
        }
        finally { loadingIdea = false; }
        RefreshSlots();
        slots.SelectedIndex = Math.Clamp(project["activeSlot"]?.GetValue<int>() ?? 0, 0, documents.Length - 1);
        await DisplayCurrentAsync();
        SaveLocalState();
    }

}

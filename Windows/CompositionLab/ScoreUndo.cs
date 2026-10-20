using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed partial class MainForm
{
    JsonObject? scoreRevisionState;
    JsonArray RevisionSlots()
    {
        var slots = new JsonArray();
        foreach (var document in documents)
            slots.Add(document == null ? null : new JsonObject { ["identity"] = document["revisionIdentity"]?.DeepClone() ?? JsonValue.Create(""), ["document"] = document.DeepClone() });
        return slots;
    }
    async Task SaveScoreUndoSnapshotAsync(JsonObject document)
    {
        int slot = documents.IndexOfReference(document);
        if (slot < 0) return;
        document["revisionIdentity"] ??= JsonValue.Create(Guid.NewGuid().ToString());
        var result = await core.RunAsync(new JsonObject { ["operation"] = "score-revision", ["request"] = new JsonObject {
            ["operation"] = "push", ["state"] = scoreRevisionState?.DeepClone(), ["slots"] = RevisionSlots(), ["slot"] = slot } });
        scoreRevisionState = result["revision"]!["state"]!.DeepClone().AsObject();
    }
    async Task UndoScoreAsync(bool redo)
    {
        if (busy) throw new InvalidOperationException("Bitte die laufende Komposition abwarten.");
        SetBusy(true);
        try {
        var result = await core.RunAsync(new JsonObject { ["operation"] = "score-revision", ["request"] = new JsonObject {
            ["operation"] = redo ? "redo" : "undo", ["state"] = scoreRevisionState?.DeepClone(), ["slots"] = RevisionSlots() } });
        var revision = result["revision"]!.AsObject();
        scoreRevisionState = revision["state"]!.DeepClone().AsObject();
        if (revision["slot"] == null) { SetStatus("Keine weitere Partituränderung vorhanden."); return; }
        int slot = revision["slot"]!.GetValue<int>();
        documents[slot] = revision["document"]!.DeepClone().AsObject();
        refreshingSlots = true; try { slots.SelectedIndex = slot; } finally { refreshingSlots = false; }
        RefreshSlots(); SaveLocalState(); await DisplayCurrentAsync();
        SetStatus(redo ? "Partituränderung wiederhergestellt." : "Partituränderung rückgängig gemacht.");
        } finally { SetBusy(false); }
    }
}

using System.Text.Json.Nodes;

namespace CompositionLab;

// Undo/redo for committed score refreshes, independent of textbox edit history.
// Snapshots are per slot; a different piece invalidates the relevant history.
internal sealed partial class MainForm
{
    readonly Stack<(int Slot, JsonObject Snapshot)> scoreUndo = new();
    readonly Stack<(int Slot, JsonObject Snapshot)> scoreRedo = new();

    void SaveScoreUndoSnapshot(JsonObject document)
    {
        int slot = documents.IndexOfReference(document);
        if (slot < 0) return;
        scoreUndo.Push((slot, document.DeepClone().AsObject()));
        if (scoreUndo.Count > 25)
        {
            var newest = scoreUndo.ToArray().Take(25).Reverse().ToArray();
            scoreUndo.Clear();
            foreach (var entry in newest) scoreUndo.Push(entry);
        }
        scoreRedo.Clear();
    }

    async Task UndoScoreAsync(bool redo)
    {
        if (busy) throw new InvalidOperationException("Bitte die laufende Komposition abwarten.");
        var source = redo ? scoreRedo : scoreUndo;
        var destination = redo ? scoreUndo : scoreRedo;
        if (source.Count == 0)
        {
            SetStatus(redo ? "Keine Partituränderung zum Wiederholen." : "Keine Partituränderung zum Rückgängigmachen.");
            return;
        }
        var entry = source.Peek();
        if (entry.Slot < 0 || entry.Slot >= documents.Length || documents[entry.Slot] == null)
            throw new InvalidOperationException("Das Stück dieser Änderung ist nicht mehr vorhanden.");
        source.Pop();
        destination.Push((entry.Slot, documents[entry.Slot]!.DeepClone().AsObject()));
        documents[entry.Slot] = entry.Snapshot.DeepClone().AsObject();
        refreshingSlots = true;
        try { slots.SelectedIndex = entry.Slot; }
        finally { refreshingSlots = false; }
        RefreshSlots();
        SaveLocalState();
        await DisplayCurrentAsync();
        SetStatus(redo ? "Vorherige Partituränderung wiederhergestellt." : "Partituränderung rückgängig gemacht.");
    }
}

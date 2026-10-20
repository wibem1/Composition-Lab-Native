using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed partial class MainForm
{
    int[] dialogueSourceSlots = [];
    JsonObject? compositionReference;
    string DialogueWorkspace()
    {
        var index = new JsonArray();
        for (int i = 0; i < documents.Length; i++)
            if (documents[i] is { } document) index.Add(new JsonObject { ["slot"] = i + 1, ["title"] = document["title"]?.DeepClone(),
                ["concept"] = document["concept"]?.DeepClone(), ["provider"] = document["provider"]?.DeepClone(), ["model"] = document["model"]?.DeepClone() });
        return new JsonObject { ["slotIndex"] = index, ["activeSlot"] = slots.SelectedIndex + 1,
            ["settings"] = new JsonObject { ["measures"] = measures.Text, ["meter"] = meter.Text, ["tempo"] = tempo.Text, ["key"] = musicalKey.Text, ["ensemble"] = ensemble.Text },
            ["recentConversation"] = chat.Text.Length > 12000 ? chat.Text[^12000..] : chat.Text,
            ["currentAssignment"] = assignment.Text, ["currentCompositionIdea"] = composition.Text }.ToJsonString();
    }
    void AcceptDialogue(JsonObject result)
    {
        var dialogue = result["dialogue"]!.AsObject();
        chat.AppendText("KI: " + dialogue["reply"]!.GetValue<string>() + "\n\n");
        chatInput.Clear();
        var settings = dialogue["resolvedSettings"]?.AsObject();
        foreach (var pair in new (string Name, Control Field)[] { ("measures", measures), ("meter", meter), ("tempo", tempo), ("key", musicalKey), ("ensemble", ensemble) })
            if (settings?[pair.Name] is { } value) pair.Field.Text = value.ToString();
        if (dialogue["compositionAssignment"] is JsonValue a && a.TryGetValue<string>(out var task) && !string.IsNullOrWhiteSpace(task)) assignment.Text = task;
        if (dialogue["compositionIdea"] is JsonValue b && b.TryGetValue<string>(out var idea) && !string.IsNullOrWhiteSpace(idea)) composition.Text = idea;
        dialogueSourceSlots = dialogue["sourceSlots"]!.AsArray().Select(n => n!.GetValue<int>()).ToArray();
        if (dialogueSourceSlots.Length == 0 && dialogue["compositionAssignment"] is JsonValue) compositionReference = null;
        SaveLocalState();
    }
    string DialogueSourceMaterial()
    {
        var material = new JsonArray();
        foreach (int slot in dialogueSourceSlots)
            if (slot is >= 1 and <= 10 && documents[slot - 1] is { } document)
                material.Add(new JsonObject { ["slot"] = slot, ["document"] = document.DeepClone() });
        return material.Count == 0 ? "" : "\n\nMUSICCHAT-ARBEITSMATERIAL:\n" + material.ToJsonString();
    }
}

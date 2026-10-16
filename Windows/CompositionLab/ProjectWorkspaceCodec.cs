using System.Text.Json.Nodes;

namespace CompositionLab;

/// <summary>
/// Pure workspace project encoder. All state arrives as explicit parameters;
/// no WinForms controls, disk IO, provider APIs or mutable global fields.
/// </summary>
internal static class ProjectWorkspaceCodec
{
    internal static JsonObject Encode(
        string name, JsonObject settings, string editorText,
        IReadOnlyList<JsonObject?> documents, int activeSlot,
        IReadOnlyList<JsonObject> history, string chatText,
        string fallbackProvider, string fallbackModel)
    {
        if (documents.Count == 0 || activeSlot < 0 || activeSlot >= documents.Count)
            throw new ArgumentOutOfRangeException(nameof(activeSlot));
        if (settings is null) throw new ArgumentNullException(nameof(settings));
        // Never parent a node in two documents. History records must be detached.
        JsonNode? EncodePiece(JsonObject? doc) => doc is null ? null :
            ProjectPieceCodec.ToHistory(doc, fallbackProvider, fallbackModel);
        return new JsonObject
        {
            ["format"] = "composition-lab-v6-project", ["version"] = 1,
            ["savedAt"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - 978307200,
            ["name"] = name, ["settings"] = settings.DeepClone(),
            ["concept"] = editorText,
            ["slots"] = new JsonArray(documents.Select(EncodePiece).ToArray()),
            ["activeSlot"] = activeSlot,
            ["history"] = new JsonArray(history.Select(h => EncodePiece(h)).ToArray()),
            ["chat"] = chatText
        };
    }
    internal static void SelfTest()
    {
        var source = new JsonObject { ["title"] = "Probe", ["score"] = new JsonObject { ["ti"] = "Probe" }, ["concept"] = "c'4" };
        JsonObject?[] slots = [source, null];
        var settings = new JsonObject { ["provider"] = "gemini" };
        var encoded = Encode("Test", settings, "c'4", slots, 0, new[] { source }, "", "gemini", "modell");
        if (encoded["slots"]?[0]?["score"]?["ti"]?.GetValue<string>() != "Probe" ||
            encoded["slots"]?[1] != null || encoded["activeSlot"]?.GetValue<int>() != 0 ||
            encoded["history"]?.AsArray().Count != 1)
            throw new InvalidOperationException("ProjectWorkspaceCodec: workspace structure lost.");
        settings["provider"] = "openai";
        source["title"] = "Verändert";
        if (encoded["settings"]?["provider"]?.GetValue<string>() != "gemini" ||
            encoded["slots"]?[0]?["title"]?.GetValue<string>() != "Probe")
            throw new InvalidOperationException("ProjectWorkspaceCodec: mutable input leaked.");
        bool refused = false;
        try { Encode("X", settings, "", slots, 5, Array.Empty<JsonObject>(), "", "", ""); }
        catch (ArgumentOutOfRangeException) { refused = true; }
        if (!refused) throw new InvalidOperationException("ProjectWorkspaceCodec: invalid slot accepted.");
    }
}

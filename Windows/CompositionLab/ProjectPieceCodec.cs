using System.Text.Json.Nodes;

namespace CompositionLab;

/// <summary>
/// Pure conversion between a score document and its portable history record.
/// No UI controls, IO, or global provider state. All provider defaults are inputs.
/// </summary>
internal static class ProjectPieceCodec
{
    // Keep slot and history imports in sync as optional project fields evolve.
    internal static void CopySavedPieceMetadata(JsonObject source, JsonObject target)
    {
        foreach (string field in new[] {
            "title", "description", "provider", "model", "costUSD", "inputTokens",
            "outputTokens", "directLilyPond", "sourceMidiData", "lilyPondSource",
            "octaveReview", "originalLilyPond", "assignment", "measures",
            "meter", "tempo", "musicalKey", "ensemble", "originalMusicXMLData"
        })
            if (source[field] != null) target[field] = source[field]!.DeepClone();
    }

    internal static JsonObject ToHistory(JsonObject document, string fallbackProvider, string fallbackModel)
    {
        if (document["title"] == null || document["score"] == null)
            throw new InvalidDataException("Document must contain a title and a score.");
        return new JsonObject { ["id"] = Guid.NewGuid().ToString(), ["time"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - 978307200,
            ["title"] = document["title"]!.DeepClone(), ["provider"] = document["provider"]?.DeepClone() ?? JsonValue.Create(fallbackProvider),
            ["model"] = document["model"]?.DeepClone() ?? JsonValue.Create(fallbackModel),
            ["concept"] = document["concept"]?.DeepClone() ?? JsonValue.Create(""),
            ["description"] = document["description"]?.DeepClone(), ["score"] = document["score"]!.DeepClone(),
            ["assignment"] = document["assignment"]?.DeepClone(), ["measures"] = document["measures"]?.DeepClone(),
            ["meter"] = document["meter"]?.DeepClone(), ["tempo"] = document["tempo"]?.DeepClone(),
            ["musicalKey"] = document["musicalKey"]?.DeepClone(), ["ensemble"] = document["ensemble"]?.DeepClone(),
            ["originalMusicXMLData"] = document["originalMusicXMLData"]?.DeepClone(),
            ["costUSD"] = document["costUSD"]?.DeepClone(), ["inputTokens"] = document["inputTokens"]?.DeepClone(),
            ["outputTokens"] = document["outputTokens"]?.DeepClone(), ["directLilyPond"] = document["directLilyPond"]?.DeepClone(),
            ["sourceMidiData"] = document["sourceMidiData"]?.DeepClone(), ["lilyPondSource"] = document["lilyPondSource"]?.DeepClone(),
            ["octaveReview"] = document["octaveReview"]?.DeepClone(), ["originalLilyPond"] = document["originalLilyPond"]?.DeepClone() };
    }
    internal static void SelfTest()
    {
        var original = new JsonObject { ["title"] = "Demo", ["score"] = new JsonObject { ["ti"] = "Demo" }, ["assignment"] = "User prompt", ["lilyPondSource"] = "\\\\score { c'4 }" };
        var encoded = ToHistory(original, "gemini", "model");
        if (encoded["lilyPondSource"]?.GetValue<string>() != original["lilyPondSource"]?.GetValue<string>() ||
            encoded["provider"]?.GetValue<string>() != "gemini") throw new InvalidOperationException("ProjectPieceCodec: metadata lost.");
        var restored = new JsonObject { ["score"] = encoded["score"]!.DeepClone() };
        CopySavedPieceMetadata(encoded, restored);
        if (restored["lilyPondSource"]?.GetValue<string>() != original["lilyPondSource"]?.GetValue<string>() ||
            restored["assignment"]?.GetValue<string>() != "User prompt")
            throw new InvalidOperationException("ProjectPieceCodec: LilyPond metadata not restored.");
    }
}

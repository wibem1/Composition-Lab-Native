using System.Text.Json.Nodes;

namespace CompositionLab;

/// Portable record adapter. Preserve extensions instead of maintaining another
/// growing list of musical/source fields beside the shared document schema.
internal static class ProjectPieceCodec
{
    internal static void CopySavedPieceMetadata(JsonObject source, JsonObject target)
    {
        foreach (var field in source)
            if (field.Key is not ("id" or "time" or "format" or "version" or "savedAt" or "score" or "concept"))
                target[field.Key] = field.Value?.DeepClone();
    }
    internal static JsonObject ToHistory(JsonObject document, string fallbackProvider, string fallbackModel)
    {
        if (document["title"] == null || document["score"] == null)
            throw new InvalidDataException("Document must contain a title and a score.");
        var result = document.DeepClone().AsObject();
        foreach (string field in new[] { "format", "version", "savedAt" }) result.Remove(field);
        result["id"] = Guid.NewGuid().ToString();
        result["time"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - 978307200;
        result["provider"] ??= JsonValue.Create(fallbackProvider);
        result["model"] ??= JsonValue.Create(fallbackModel);
        result["concept"] ??= JsonValue.Create("");
        return result;
    }
    internal static void SelfTest()
    {
        var original = new JsonObject { ["title"] = "Demo", ["score"] = new JsonObject { ["ti"] = "Demo" },
            ["assignment"] = "User prompt", ["lilyPondSource"] = "\\score { c'4 }",
            ["futureExtension"] = new JsonObject { ["value"] = "Ü – unverändert" } };
        var encoded = ToHistory(original, "gemini", "model");
        if (encoded["lilyPondSource"]?.GetValue<string>() != original["lilyPondSource"]?.GetValue<string>() ||
            encoded["provider"]?.GetValue<string>() != "gemini") throw new InvalidOperationException("ProjectPieceCodec: metadata lost.");
        var restored = new JsonObject { ["score"] = encoded["score"]!.DeepClone() };
        CopySavedPieceMetadata(encoded, restored);
        if (restored["futureExtension"]?.ToJsonString() != original["futureExtension"]?.ToJsonString() ||
            restored["lilyPondSource"]?.GetValue<string>() != original["lilyPondSource"]?.GetValue<string>())
            throw new InvalidOperationException("ProjectPieceCodec: extension fields lost.");
    }
}

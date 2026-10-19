using System.Text.Json.Nodes;
namespace CompositionLab;

// Native DTO adapter; source matching and Unicode offsets belong to the core.
internal static class ScoreSourceMapper
{
    internal readonly record struct Point(int Line, int Column, int? Character = null);
    internal readonly record struct Span(int Start, int Length);
    internal enum Error { None, StaleSource, InvalidPosition, EmptySource }
    internal static async Task<(Span? Range, Error Failure)> MapAsync(string renderedSource, string editorSource, Point from, Point to)
    {
        var result = await new CoreClient().RunAsync(new JsonObject {
            ["operation"] = "source-selection", ["rendered"] = renderedSource, ["editor"] = editorSource,
            ["line"] = from.Line, ["character"] = from.Character ?? from.Column - 1,
            ["endLine"] = to.Line, ["endCharacter"] = to.Character ?? to.Column - 1
        });
        var selection = result["selection"]!;
        if (selection["error"] is JsonValue error)
            return (null, Enum.TryParse<Error>(error.GetValue<string>(), out var code) ? code : Error.InvalidPosition);
        return (new Span(selection["start"]!.GetValue<int>(), selection["length"]!.GetValue<int>()), Error.None);
    }
    internal static async Task SelfTestAsync()
    {
        const string source = "c'4 d'4\r\n<e' g'>2\r\n";
        var mapped = await MapAsync(source, source.Replace("\r\n", "\n"), new(2, 1), new(2, 2));
        if (mapped.Range is not { Start: 8, Length: 2 }) throw new InvalidOperationException("Gemeinsame Quelltextzuordnung: Zeilenenden falsch.");
        if ((await MapAsync(source, source + "x", new(1, 1), new(1, 1))).Failure != Error.StaleSource)
            throw new InvalidOperationException("Gemeinsame Quelltextzuordnung akzeptiert veraltete Noten.");
    }
}

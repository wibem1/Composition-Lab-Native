using System.Text.RegularExpressions;
namespace CompositionLab;

/// <summary>
/// Pure mapping between a LilyPond rendering's source coordinates and the editor.
/// Owns no GUI state. The source must match exactly to prevent editing the wrong note.
/// </summary>
internal static class ScoreSourceMapper
{
    internal readonly record struct Point(int Line, int Column);
    internal readonly record struct Span(int Start, int Length);
    internal enum Error { None, StaleSource, InvalidPosition, EmptySource }

    internal static (Span? Range, Error Failure) Map(string renderedSource, string editorSource, Point from, Point to)
    {
        if (string.IsNullOrEmpty(renderedSource)) return (null, Error.EmptySource);
        if (!string.Equals(renderedSource, editorSource, StringComparison.Ordinal))
            return (null, Error.StaleSource);
        // Renderers compile the LilyPond body only. Stored AI answers may
        // wrap that body in a Markdown fence and introductory prose.
        // Compute positions against the compiled body, then translate back
        // to absolute editor offsets without modifying the editor text.
        string mappingSource = renderedSource;
        int baseOffset = 0;
        var fenced = Regex.Match(renderedSource, @"(?s)```(?:lilypond|ly)\s*\r?\n(?<body>.*?)\r?\n```", RegexOptions.IgnoreCase);
        if (fenced.Success)
        {
            mappingSource = fenced.Groups["body"].Value;
            baseOffset = fenced.Groups["body"].Index;
        }
        int Offset(Point p)
        {
            if (p.Line < 1 || p.Column < 1) return -1;
            int start = 0;
            for (int line = 1; line < p.Line; line++)
            {
                int newline = mappingSource.IndexOf('\n', start);
                if (newline < 0) return -1;
                start = newline + 1;
            }
            int stop = mappingSource.IndexOf('\n', start);
            if (stop < 0) stop = mappingSource.Length;
            if (p.Column > stop - start + 1) return -1;
            return baseOffset + start + p.Column - 1;
        }
        int a = Offset(from), b = Offset(to);
        if (a < 0 || b < 0) return (null, Error.InvalidPosition);
        if (b < a) (a, b) = (b, a);
        return (new Span(a, Math.Min(renderedSource.Length - a, Math.Max(1, b - a + 1))), Error.None);
    }
    internal static void SelfTest()
    {
        const string music = "c'4 d'4\n<e' g'>2\n";
        var span = Map(music, music, new(1,1), new(2,2));
        if (span.Failure != Error.None || span.Range is not { Start: 0, Length: 10 })
            throw new InvalidOperationException("ScoreSourceMapper: multi-line range incorrect.");
        if (Map(music, music+"x", new(1,1), new(1,2)).Failure != Error.StaleSource)
            throw new InvalidOperationException("ScoreSourceMapper: stale source accepted.");
        if (Map(music, music, new(20,1), new(20,2)).Failure != Error.InvalidPosition)
            throw new InvalidOperationException("ScoreSourceMapper: invalid source location accepted.");
        string wrapped = "Überschrift\n```lilypond\n" + music.TrimEnd('\n') + "\n```";
        var wrappedResult = Map(wrapped, wrapped, new(1, 1), new(2, 2));
        if (wrappedResult.Failure != Error.None ||
            wrappedResult.Range?.Start != wrapped.IndexOf("c'4", StringComparison.Ordinal))
            throw new Exception("ScoreSourceMapper: fenced LilyPond source coordinate incorrect.");
        if (Map(music, music, new(2,2), new(1,1)).Range is not {Start:0})
            throw new InvalidOperationException("ScoreSourceMapper: reverse range rejected.");
    }
}

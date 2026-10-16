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
        int Offset(Point p)
        {
            if (p.Line < 1 || p.Column < 1) return -1;
            int start = 0;
            for (int line = 1; line < p.Line; line++)
            {
                int newline = renderedSource.IndexOf('\n', start);
                if (newline < 0) return -1;
                start = newline + 1;
            }
            int stop = renderedSource.IndexOf('\n', start);
            if (stop < 0) stop = renderedSource.Length;
            if (p.Column > stop - start + 1) return -1;
            return start + p.Column - 1;
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
        if (Map(music, music, new(2,2), new(1,1)).Range is not {Start:0})
            throw new InvalidOperationException("ScoreSourceMapper: reverse range rejected.");
    }
}

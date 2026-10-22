using System.Text.Json;

namespace CompositionLab;

// A transport-neutral template is shared with WKWebView on Mac.
internal static class ScorePreviewDocument
{
    internal static string Build(string[] svgPages)
    {
        if (svgPages == null || svgPages.Length == 0) throw new ArgumentException("A score must contain at least one SVG page.", nameof(svgPages));
        using var resource = typeof(ScorePreviewDocument).Assembly.GetManifestResourceStream("CompositionLab.ScorePreview.html")
            ?? throw new InvalidDataException("Gemeinsame Notenansicht fehlt.");
        using var reader = new StreamReader(resource);
        return reader.ReadToEnd().Replace("PAGES_VALUE", JsonSerializer.Serialize(svgPages))
            .Replace("RENDER_ID_VALUE", JsonSerializer.Serialize(Guid.NewGuid().ToString("N")));
    }
}

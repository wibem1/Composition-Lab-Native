using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;

namespace CompositionLab;

// Explorer/copy tools can assign extraction times in directory order, making
// Guile source newer than matching bytecode. Guile then bootstraps interpreted
// Scheme before LilyPond can even enter its main callback.
internal static class GuileRuntime
{
    internal const string Profile = "verified-guile-bytecode-v1";
    internal sealed record Pair(string Source, string Compiled, string SourceHash, string CompiledHash);
    internal static readonly Pair[] Pairs = LoadManifest();
    static readonly object Sync = new();

    static Pair[] LoadManifest()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("CompositionLab.GuileRuntimeManifest.json")
            ?? throw new InvalidDataException("Die Prüfliste der Guile-Laufzeit fehlt.");
        using var json = JsonDocument.Parse(stream);
        return json.RootElement.GetProperty("pairs").EnumerateArray().Select(p => new Pair(
            p.GetProperty("source").GetString()!, p.GetProperty("compiled").GetString()!,
            p.GetProperty("sourceSHA256").GetString()!, p.GetProperty("compiledSHA256").GetString()!)).ToArray();
    }

    internal static int EnsureBytecodeFresh(string bundle)
    {
        lock (Sync)
        {
            var stale = new List<Pair>();
            foreach (var pair in Pairs)
            {
                string source = Path.Combine(bundle, pair.Source), compiled = Path.Combine(bundle, pair.Compiled);
                if (!File.Exists(source) || !File.Exists(compiled))
                    throw new InvalidDataException("Die mitgelieferte Guile-Laufzeit ist unvollständig: " + pair.Source);
                if (File.GetLastWriteTimeUtc(compiled) <= File.GetLastWriteTimeUtc(source).AddSeconds(2)) stale.Add(pair);
            }
            if (stale.Count == 0) return 0;
            // Validate ALL contents before changing ANY timestamp. Modified
            // source must never be disguised as compatible with old bytecode.
            foreach (var pair in Pairs)
            {
                Verify(Path.Combine(bundle, pair.Source), pair.SourceHash);
                Verify(Path.Combine(bundle, pair.Compiled), pair.CompiledHash);
            }
            foreach (var pair in stale)
            {
                string source = Path.Combine(bundle, pair.Source), compiled = Path.Combine(bundle, pair.Compiled);
                File.SetLastWriteTimeUtc(compiled, File.GetLastWriteTimeUtc(source).AddSeconds(4));
                if (File.GetLastWriteTimeUtc(compiled) <= File.GetLastWriteTimeUtc(source))
                    throw new IOException("Guile-Zeitstempel konnte nicht korrigiert werden: " + pair.Compiled);
            }
            return stale.Count;
        }
    }

    static void Verify(string path, string expected)
    {
        using var stream = File.OpenRead(path);
        if (!Convert.ToHexString(SHA256.HashData(stream)).Equals(expected, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("Die Guile-Laufzeit wurde verändert. Bitte das vollständige Originalpaket neu entpacken: " + Path.GetFileName(path));
    }
}

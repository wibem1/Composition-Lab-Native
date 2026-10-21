using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace CompositionLab;

internal sealed record LilyPondOutput(byte[] Midi, string[] Pages, string Log, double Milliseconds, bool Cached);

/// Run the bundled engraver once per immutable source. Playback and display use
/// the same original score; the structured MIDI import is only an interchange view.
internal sealed class LilyPondCompiler(string cacheRoot)
{
    public const string Version = "2.24.4";
    public const string RuntimeProfile = "local-gio-lazy-v1";
    readonly SemaphoreSlim gate = new(1, 1);
    internal static string? ProgressMessage(string line)
    {
        if (line.StartsWith("Parsing", StringComparison.Ordinal) || line.StartsWith("Analysiere", StringComparison.Ordinal)) return "Notentext wird eingelesen …";
        if (line.StartsWith("Interpreting music", StringComparison.Ordinal) || line.StartsWith("Interpretiere Musik", StringComparison.Ordinal)) return "Stimmen und MIDI werden verarbeitet …";
        if (line.StartsWith("Fitting music", StringComparison.Ordinal) || line.StartsWith("Finding the ideal", StringComparison.Ordinal)) return "Seiten werden aufgeteilt …";
        if (line.StartsWith("Drawing systems", StringComparison.Ordinal) || line.StartsWith("Zeichne", StringComparison.Ordinal)) return "Notenbild wird gezeichnet …";
        return null; // Full library warnings and file paths belong in the diagnostic log.
    }

    public static async Task<string> PrepareAsync(string source, CancellationToken cancellation = default)
    {
        try {
            var response = await new CoreClient().RunAsync(new System.Text.Json.Nodes.JsonObject {
                ["operation"] = "prepare-lilypond", ["source"] = source
            }, cancellation);
            return response["source"]!.GetValue<string>();
        }
        catch (CoreRequestException e) { throw new InvalidDataException(e.Message, e); }
    }

    public async Task<LilyPondOutput> CompileAsync(string source, CancellationToken cancellation = default, Action<string>? progress = null)
    {
        string prepared = await PrepareAsync(source, cancellation);
        string hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Version + "\n" + RuntimeProfile + "\npoint-and-click-v1\n" + prepared)));
        string final = Path.Combine(cacheRoot, hash);
        await gate.WaitAsync(cancellation);
        string? temporary = null;
        try
        {
            if (File.Exists(Path.Combine(final, "complete")))
            {
                try { return Read(final, true, 0); }
                catch (Exception e) when (e is IOException or InvalidDataException) { Directory.Delete(final, true); }
            }
            var executable = Path.Combine(AppContext.BaseDirectory, "LilyPond", "bin", "lilypond.exe");
            if (!File.Exists(executable)) throw new FileNotFoundException("Der mitgelieferte LilyPond-Notensatz fehlt. Bitte das gesamte ZIP in einen neuen Ordner entpacken.");
            Directory.CreateDirectory(cacheRoot);
            temporary = Path.Combine(cacheRoot, ".work-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(temporary);
            await File.WriteAllTextAsync(Path.Combine(temporary, "source.ly"), prepared, new UTF8Encoding(false), cancellation);
            var start = new ProcessStartInfo(executable) { WorkingDirectory = temporary, UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true, StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8 };
            // Portable LilyPond's relocate files use set?, which otherwise keeps
            // Fontconfig settings inherited from unrelated installed programs.
            // Use this bundle's configuration and a persistent writable user cache.
            string bundle = Path.Combine(AppContext.BaseDirectory, "LilyPond");
            start.Environment["FONTCONFIG_FILE"] = Path.Combine(bundle, "etc", "fonts", "fonts.conf");
            start.Environment["FONTCONFIG_PATH"] = Path.Combine(bundle, "etc", "fonts");
            string fontCache = Path.Combine(cacheRoot, "font-cache");
            Directory.CreateDirectory(fontCache);
            start.Environment["XDG_CACHE_HOME"] = fontCache;
            foreach (string argument in new[] { "--svg", "-dpoint-and-click", "--loglevel=INFO", "--output=score", "source.ly" }) start.ArgumentList.Add(argument);
            // Keep the existing deadline; preserve the actual process log on timeout.
            var reporter = progress == null ? null : new Progress<string>(progress);
            var run = await EngravingProcess.RunAsync(start, TimeSpan.FromMinutes(2), cancellation, reporter);
            string log = run.Log;
            await File.WriteAllTextAsync(Path.Combine(temporary, "compile.log"), log, cancellation);
            if (run.ExitCode != 0) throw new InvalidDataException("LilyPond konnte die Originalkomposition nicht setzen. Es wurde keine KI-Übersetzung gestartet.\n" + log[..Math.Min(8000, log.Length)]);
            // Verify every output before publishing the cache atomically.
            var output = Read(temporary, false, run.Milliseconds);
            cancellation.ThrowIfCancellationRequested();
            if (Directory.Exists(final)) Directory.Delete(final, true);
            await File.WriteAllTextAsync(Path.Combine(temporary, "complete"), Version, cancellation);
            Directory.Move(temporary, final); temporary = null;
            return output;
        }
        finally
        {
            if (temporary != null) { try { Directory.Delete(temporary, true); } catch (IOException) { } }
            gate.Release();
        }
    }
    static LilyPondOutput Read(string path, bool cached, double milliseconds)
    {
        var midis = Directory.GetFiles(path, "score*.mid*").Where(p => Path.GetExtension(p) is ".midi" or ".mid").ToArray();
        if (midis.Length != 1) throw new InvalidDataException("LilyPond muss genau eine vollständige MIDI-Datei erzeugen. Mehrere Score-Ausgaben werden nicht stillschweigend gekürzt.");
        var midi = File.ReadAllBytes(midis[0]);
        if (midi.Length < 14 || Encoding.ASCII.GetString(midi, 0, 4) != "MThd") throw new InvalidDataException("LilyPond hat keine gültige MIDI-Datei erzeugt.");
        var pages = Directory.GetFiles(path, "score*.svg").OrderBy(p => Regex.Match(Path.GetFileName(p), @"(\d+)\.svg$") is { Success: true } m ? int.Parse(m.Groups[1].Value) : 0).Select(File.ReadAllText).ToArray();
        if (pages.Length == 0 || pages.Any(p => !p.Contains("<svg"))) throw new InvalidDataException("LilyPond hat keine vollständige Notenausgabe erzeugt.");
        return new(midi, pages, File.ReadAllText(Path.Combine(path, "compile.log")), milliseconds, cached);
    }
}

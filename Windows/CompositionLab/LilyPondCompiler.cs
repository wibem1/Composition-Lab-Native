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
    public const string Version = "2.26.0";
    readonly SemaphoreSlim gate = new(1, 1);
    public static string Prepare(string source)
    {
        // Accept ordinary notation, not arbitrary embedded Scheme or external files.
        string notation = Regex.Replace(source, "(?s)\\%\\{.*?\\%\\}|%[^\\r\\n]*|\"(?:\\\\.|[^\"\\\\])*\"", " ");
        notation = Regex.Replace(notation, @"##[tf]\b|#\(set-global-staff-size\s+\d+(?:\.\d+)?\s*\)", " ");
        if (Regex.IsMatch(notation, @"\\(?:include|includeSpecial|applyContext|applyOutput|displayScheme|scheme|load)\b|\$|#(?!#[tf]\b|[-+]?\d+(?:\.\d+)?)"))
            throw new InvalidDataException("Die LilyPond-Datei enthält externe Dateien oder ausführbare Scheme-Ausdrücke. Für die direkte Ausgabe bitte reine Notation verwenden.");
        if (!Regex.IsMatch(notation, @"\\score\s*\{")) throw new InvalidDataException("Kein vollständiger LilyPond-Score vorhanden.");
        // A score without an explicit MIDI block still gets playback. A layout
        // block is needed when an explicit MIDI block would suppress engraving.
        // Add only output directives, never change the music expressions.
        var score = Regex.Match(source, @"\\score\s*\{");
        int depth = 1, end = score.Index + score.Length;
        bool quoted = false, comment = false, block = false;
        for (; end < source.Length && depth > 0; end++)
        {
            char c = source[end];
            if (comment) { if (c == '\n') comment = false; continue; }
            if (block) { if (c == '%' && end + 1 < source.Length && source[end + 1] == '}') { block = false; end++; } continue; }
            if (quoted) { if (c == '\\') end++; else if (c == '"') quoted = false; continue; }
            if (c == '"') { quoted = true; continue; }
            if (c == '%') { if (end + 1 < source.Length && source[end + 1] == '{') { block = true; end++; } else comment = true; continue; }
            if (c == '{') depth++; else if (c == '}') depth--;
        }
        if (depth != 0) throw new InvalidDataException("Die LilyPond-Score-Klammer ist nicht geschlossen.");
        string body = notation;
        string directives = (Regex.IsMatch(body, @"\\layout\s*\{") ? "" : "\n\\layout { }\n") +
                            (Regex.IsMatch(body, @"\\midi\s*\{") ? "" : "\n\\midi { }\n");
        return source.Insert(end - 1, directives);
    }

    public async Task<LilyPondOutput> CompileAsync(string source, CancellationToken cancellation = default)
    {
        string prepared = Prepare(source);
        string hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Version + "\npoint-and-click-v1\n" + prepared)));
        string final = Path.Combine(cacheRoot, hash);
        await gate.WaitAsync(cancellation);
        string? temporary = null;
        try
        {
            if (File.Exists(Path.Combine(final, "complete"))) return Read(final, true, 0);
            var executable = Path.Combine(AppContext.BaseDirectory, "LilyPond", "bin", "lilypond.exe");
            if (!File.Exists(executable)) throw new FileNotFoundException("Der mitgelieferte LilyPond-Notensatz fehlt. Bitte das gesamte ZIP in einen neuen Ordner entpacken.");
            Directory.CreateDirectory(cacheRoot);
            temporary = Path.Combine(cacheRoot, ".work-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(temporary);
            await File.WriteAllTextAsync(Path.Combine(temporary, "source.ly"), prepared, new UTF8Encoding(false), cancellation);
            var start = new ProcessStartInfo(executable) { WorkingDirectory = temporary, UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true, StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8 };
            foreach (string argument in new[] { "--svg", "-dpoint-and-click", "--loglevel=WARNING", "--output=score", "source.ly" }) start.ArgumentList.Add(argument);
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellation); timeout.CancelAfter(TimeSpan.FromMinutes(2));
            using var process = new Process { StartInfo = start };
            var watch = Stopwatch.StartNew(); process.Start();
            using var registration = timeout.Token.Register(() => { try { if (!process.HasExited) process.Kill(true); } catch (InvalidOperationException) { } });
            var stdout = process.StandardOutput.ReadToEndAsync(); var stderr = process.StandardError.ReadToEndAsync();
            await process.WaitForExitAsync(timeout.Token);
            string log = (await stderr) + (await stdout); watch.Stop();
            await File.WriteAllTextAsync(Path.Combine(temporary, "compile.log"), log, cancellation);
            if (process.ExitCode != 0) throw new InvalidDataException("LilyPond konnte die Originalkomposition nicht setzen. Es wurde keine KI-Übersetzung gestartet.\n" + log[..Math.Min(5000, log.Length)]);
            // Verify every output before publishing the cache atomically.
            var output = Read(temporary, false, watch.Elapsed.TotalMilliseconds);
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

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

    public async Task<LilyPondOutput> CompileAsync(string source, CancellationToken cancellation = default)
    {
        string prepared = await PrepareAsync(source, cancellation);
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

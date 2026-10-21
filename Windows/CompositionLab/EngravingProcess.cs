using System.Diagnostics;
using System.Text;

namespace CompositionLab;

internal sealed class EngravingTimeoutException(string message, string log, double milliseconds)
    : TimeoutException(message)
{
    public string Log { get; } = log;
    public double Milliseconds { get; } = milliseconds;
}

// Capture bytes as they arrive: LilyPond's startup marker and GLib diagnostics
// need not end in a newline. A deadline must cover inherited output handles too.
internal static class EngravingProcess
{
    sealed class Capture
    {
        readonly StringBuilder text = new();
        readonly object sync = new();
        public string Snapshot() { lock (sync) return text.ToString(); }
        public async Task ReadAsync(StreamReader reader, IProgress<string>? progress)
        {
            var buffer = new char[2048];
            var line = new StringBuilder();
            int count;
            while ((count = await reader.ReadAsync(buffer.AsMemory()).ConfigureAwait(false)) != 0) {
                lock (sync) {
                    // Retain the start and last part without unbounded memory use.
                    text.Append(buffer, 0, count);
                    if (text.Length > 1024 * 1024) text.Remove(16384, text.Length - 512 * 1024);
                }
                for (int i = 0; i < count; i++) {
                    char c = buffer[i];
                    if (c is '\n' or '\r') {
                        if (line.Length != 0) progress?.Report(line.ToString());
                        line.Clear();
                    } else if (line.Length < 512) line.Append(c);
                }
            }
            if (line.Length != 0) progress?.Report(line.ToString());
        }
    }

    internal static async Task<(int ExitCode, string Log, double Milliseconds)> RunAsync(
        ProcessStartInfo start, TimeSpan limit, CancellationToken cancellation, IProgress<string>? progress = null)
    {
        cancellation.ThrowIfCancellationRequested();
        using var process = new Process { StartInfo = start };
        var watch = Stopwatch.StartNew();
        process.Start();
        var output = new Capture(); var error = new Capture();
        var stdout = output.ReadAsync(process.StandardOutput, null);
        var stderr = error.ReadAsync(process.StandardError, progress);
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellation);
        deadline.CancelAfter(limit);
        try {
            await process.WaitForExitAsync(deadline.Token).ConfigureAwait(false);
            await Task.WhenAll(stdout, stderr).WaitAsync(deadline.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            string processState = "";
            try {
                processState = "\nLilyPond-Prozess: CPU " + Math.Round(process.TotalProcessorTime.TotalMilliseconds) + " ms; Arbeitsspeicher " + process.WorkingSet64 + " Bytes.\n";
                if (!process.HasExited) process.Kill(entireProcessTree: true);
            } catch (InvalidOperationException) { }
            try { await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3)).ConfigureAwait(false); }
            catch (TimeoutException) { }
            try { await Task.WhenAll(stdout, stderr).WaitAsync(TimeSpan.FromSeconds(2)).ConfigureAwait(false); }
            catch (TimeoutException) { } // Snapshot remains available even with inherited handles.
            string captured = error.Snapshot() + output.Snapshot() + processState;
            watch.Stop();
            cancellation.ThrowIfCancellationRequested();
            throw new EngravingTimeoutException(
                "Zeitlimit beim lokalen LilyPond-Notensatz nach " + Math.Round(watch.Elapsed.TotalSeconds) +
                " Sekunden. Die Originalkomposition bleibt zur erneuten Übernahme gespeichert.\n" + captured[..Math.Min(8000, captured.Length)],
                captured, watch.Elapsed.TotalMilliseconds);
        }
        watch.Stop();
        return (process.ExitCode, error.Snapshot() + output.Snapshot(), watch.Elapsed.TotalMilliseconds);
    }
}

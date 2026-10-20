using System.Diagnostics;

namespace CompositionLab;

internal sealed class EngravingTimeoutException(string message, string log, double milliseconds)
    : TimeoutException(message)
{
    public string Log { get; } = log;
    public double Milliseconds { get; } = milliseconds;
}

// Own the child process, timeout and both output pipes for every engraving.
internal static class EngravingProcess
{
    static async Task<string> ReadLogAsync(StreamReader reader, IProgress<string>? progress)
    {
        var log = new System.Text.StringBuilder();
        while (await reader.ReadLineAsync().ConfigureAwait(false) is { } line) {
            log.AppendLine(line);
            if (!string.IsNullOrWhiteSpace(line)) progress?.Report(line);
        }
        return log.ToString();
    }
    internal static async Task<(int ExitCode, string Log, double Milliseconds)> RunAsync(
        ProcessStartInfo start, TimeSpan limit, CancellationToken cancellation, IProgress<string>? progress = null)
    {
        cancellation.ThrowIfCancellationRequested();
        using var process = new Process { StartInfo = start };
        var watch = Stopwatch.StartNew();
        process.Start();
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = ReadLogAsync(process.StandardError, progress);
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellation);
        deadline.CancelAfter(limit);
        try { await process.WaitForExitAsync(deadline.Token); }
        catch (OperationCanceledException)
        {
            try { if (!process.HasExited) process.Kill(entireProcessTree: true); }
            catch (InvalidOperationException) { }
            // Bound pipe cleanup too: never wait indefinitely for inherited handles.
            try { await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(5)); }
            catch (TimeoutException) { }
            string captured = "";
            try { captured = (await stderr.WaitAsync(TimeSpan.FromSeconds(5))) + (await stdout.WaitAsync(TimeSpan.FromSeconds(5))); }
            catch (TimeoutException) { captured = "Das Prozessprotokoll konnte nach dem Abbruch nicht vollständig gelesen werden."; }
            watch.Stop();
            cancellation.ThrowIfCancellationRequested();
            throw new EngravingTimeoutException(
                "Zeitlimit beim lokalen LilyPond-Notensatz nach " + Math.Round(watch.Elapsed.TotalSeconds) +
                " Sekunden. Die Originalkomposition bleibt zur erneuten Übernahme gespeichert.\n" + captured[..Math.Min(8000, captured.Length)],
                captured, watch.Elapsed.TotalMilliseconds);
        }
        string log = (await stderr) + (await stdout);
        watch.Stop();
        return (process.ExitCode, log, watch.Elapsed.TotalMilliseconds);
    }
}

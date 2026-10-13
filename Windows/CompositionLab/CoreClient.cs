using System.Diagnostics;
using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed class CoreRequestException(string message, JsonObject? diagnostic) : Exception(message)
{
    public JsonObject? Diagnostic { get; } = diagnostic;
}

internal sealed class CoreClient
{
    public async Task<JsonObject> RunAsync(JsonObject request, CancellationToken cancellation = default,
                                          Action<string>? progress = null)
    {
        var exe = Path.Combine(AppContext.BaseDirectory, "Core", "composition-lab-core.exe");
        if (!File.Exists(exe)) throw new FileNotFoundException("Der gemeinsame Kern fehlt im Ordner Core. Bitte das gesamte ZIP entpacken.");
        using var process = new Process { StartInfo = new ProcessStartInfo(exe, "service")
        {
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true,
            WorkingDirectory = Path.GetDirectoryName(exe)!
        }};
        process.Start();
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellation);
        timeout.CancelAfter(TimeSpan.FromMinutes(33));
        using var registration = timeout.Token.Register(() =>
        {
            try { if (!process.HasExited) process.Kill(entireProcessTree: true); } catch (InvalidOperationException) { }
        });
        var stderr = process.StandardError.ReadToEndAsync(timeout.Token);
        await process.StandardInput.WriteAsync(request.ToJsonString().AsMemory(), timeout.Token);
        process.StandardInput.Close();
        JsonObject? result = null;
        string? line;
        while ((line = await process.StandardOutput.ReadLineAsync(timeout.Token)) != null)
        {
            if (string.IsNullOrWhiteSpace(line)) continue;
            var message = JsonNode.Parse(line)?.AsObject() ?? throw new InvalidDataException("Ungültige Kernantwort.");
            if (message["event"]?.GetValue<string>() == "progress")
                progress?.Invoke(message["stage"]?.GetValue<string>() ?? "");
            else result = message;
        }
        await process.WaitForExitAsync(timeout.Token);
        var errorText = await stderr;
        timeout.Token.ThrowIfCancellationRequested();
        if (process.ExitCode != 0 || result == null)
            throw new InvalidOperationException(string.IsNullOrWhiteSpace(errorText)
                ? "Der gemeinsame Kern konnte nicht gestartet werden oder hat keine Antwort geliefert." : errorText.Trim());
        if (result["ok"]?.GetValue<bool>() != true)
            throw new CoreRequestException(result["error"]?.GetValue<string>() ?? "Fehler im gemeinsamen Kern.",
                                           result["diagnostic"]?.DeepClone().AsObject());
        return result;
    }
}

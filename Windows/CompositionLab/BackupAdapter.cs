using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CompositionLab;

/// OS crypto adapter for the existing portable Mac backup envelope (v1).
internal static class PortableBackupCrypto
{
    static byte[] Key(string password, byte[] salt)
    {
        byte[] material = Encoding.UTF8.GetBytes(password).Concat(salt).ToArray();
        for (int i = 0; i < 50000; i++) { byte[] previous = material; material = SHA256.HashData(previous); CryptographicOperations.ZeroMemory(previous); }
        return material;
    }
    public static byte[] Encrypt(JsonObject payload, string password)
    {
        byte[] salt = RandomNumberGenerator.GetBytes(16), nonce = RandomNumberGenerator.GetBytes(12), key = Key(password, salt);
        byte[] plain = JsonSerializer.SerializeToUtf8Bytes(payload), cipher = new byte[plain.Length], tag = new byte[16];
        try {
            using var aes = new AesGcm(key, 16); aes.Encrypt(nonce, plain, cipher, tag);
            return JsonSerializer.SerializeToUtf8Bytes(new { format = "composition-lab-native-backup", version = 1, salt = Convert.ToBase64String(salt), combined = Convert.ToBase64String(nonce.Concat(cipher).Concat(tag).ToArray()) });
        }
        finally { CryptographicOperations.ZeroMemory(key); CryptographicOperations.ZeroMemory(plain); }
    }
    public static JsonObject Decrypt(byte[] envelope, string password)
    {
        var parsed = JsonNode.Parse(envelope)?.AsObject() ?? throw new InvalidDataException("Ungültiges Backup.");
        if (parsed["format"]?.GetValue<string>() != "composition-lab-native-backup" || parsed["version"]?.GetValue<int>() != 1) throw new InvalidDataException("Unbekanntes Backupformat.");
        byte[] salt = Convert.FromBase64String(parsed["salt"]!.GetValue<string>()), combined = Convert.FromBase64String(parsed["combined"]!.GetValue<string>());
        if (salt.Length != 16 || combined.Length < 28) throw new InvalidDataException("Beschädigtes Backup.");
        byte[] key = Key(password, salt), plain = new byte[combined.Length - 28];
        try {
            using var aes = new AesGcm(key, 16);
            aes.Decrypt(combined.AsSpan(0, 12), combined.AsSpan(12, plain.Length), combined.AsSpan(combined.Length - 16), plain);
            return JsonNode.Parse(plain)!.AsObject();
        }
        catch (CryptographicException) { throw new InvalidDataException("Das Backup-Passwort ist falsch oder die Datei ist beschädigt."); }
        finally { CryptographicOperations.ZeroMemory(key); CryptographicOperations.ZeroMemory(plain); }
    }
}

internal sealed partial class MainForm
{
    string? BackupPassword()
    {
        using var dialog = new Form { Text = "Backup-Passwort", Width = 420, Height = 155, FormBorderStyle = FormBorderStyle.FixedDialog, StartPosition = FormStartPosition.CenterParent, MaximizeBox = false, MinimizeBox = false };
        var field = new TextBox { UseSystemPasswordChar = true, Dock = DockStyle.Top };
        var ok = new Button { Text = "Übernehmen", Dock = DockStyle.Bottom, DialogResult = DialogResult.OK };
        dialog.Controls.Add(field); dialog.Controls.Add(ok); dialog.AcceptButton = ok;
        return dialog.ShowDialog(this) == DialogResult.OK && field.Text.Length > 0 ? field.Text : null;
    }
    JsonObject PortableSettings() => new() { ["provider"] = activeProvider, ["models"] = JsonSerializer.SerializeToNode(models),
        ["efforts"] = new JsonObject { [activeProvider] = effort.SelectedIndex switch { 0 => "low", 2 => "high", _ => "medium" } },
        ["measures"] = measures.Text, ["meter"] = meter.Text, ["tempo"] = tempo.Text, ["key"] = musicalKey.Text, ["ensemble"] = ensemble.Text, ["prompt"] = assignment.Text, ["zoomPercent"] = guiZoom };
    async Task ExportBackupAsync()
    {
        if (busy) return;
        using var save = new SaveFileDialog { Filter = "Verschlüsseltes Composition-Lab-Backup|*.clabbackup", FileName = "Composition-Lab-Backup.clabbackup" };
        if (save.ShowDialog(this) != DialogResult.OK || BackupPassword() is not { } password) return;
        var payload = new JsonObject { ["format"] = "composition-lab-native-backup-payload", ["version"] = 1,
            ["savedAt"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - 978307200, ["settings"] = PortableSettings(),
            ["history"] = new JsonArray(pieceHistory.Select(ToHistory).Select(d => (JsonNode)d).ToArray()), ["apiKeys"] = JsonSerializer.SerializeToNode(keys) };
        await core.RunAsync(new JsonObject { ["operation"] = "validate-backup", ["document"] = payload.DeepClone() });
        AtomicFile.WriteBytes(save.FileName, PortableBackupCrypto.Encrypt(payload, password)); SetStatus("Verschlüsseltes Backup gespeichert.");
    }
    async Task ImportBackupAsync()
    {
        if (busy) return;
        using var open = new OpenFileDialog { Filter = "Verschlüsseltes Composition-Lab-Backup|*.clabbackup" };
        if (open.ShowDialog(this) != DialogResult.OK || BackupPassword() is not { } password) return;
        var payload = PortableBackupCrypto.Decrypt(await File.ReadAllBytesAsync(open.FileName), password);
        await core.RunAsync(new JsonObject { ["operation"] = "validate-backup", ["document"] = payload.DeepClone() });
        var restoredHistory = payload["history"]!.AsArray().OfType<JsonObject>().Select(RestoreProjectPiece).ToArray();
        var importedKeys = payload["apiKeys"]!.Deserialize<Dictionary<string, string>>()!;
        var settings = payload["settings"]!.AsObject();
        // Save credentials before publishing the restored UI/history state.
        secrets.Save(importedKeys); keys.Clear(); foreach (var pair in importedKeys) keys[pair.Key] = pair.Value;
        loadingSettings = true;
        try {
            if (settings["models"] is JsonObject values) foreach (var pair in values) if (models.ContainsKey(pair.Key)) models[pair.Key] = pair.Value!.GetValue<string>();
            activeProvider = settings["provider"]!.GetValue<string>(); provider.SelectedIndex = activeProvider switch { "openai" => 2, "gemini" => 0, _ => 1 };
            SelectModel(); effort.SelectedIndex = settings["efforts"]?[activeProvider]?.GetValue<string>() switch { "low" => 0, "high" => 2, _ => 1 }; apiKey.Text = keys.GetValueOrDefault(activeProvider, ""); remember.Checked = keys.ContainsKey(activeProvider);
            measures.Text = settings["measures"]!.GetValue<string>(); meter.Text = settings["meter"]!.GetValue<string>(); tempo.Text = settings["tempo"]!.GetValue<string>(); musicalKey.Text = settings["key"]!.GetValue<string>(); ensemble.Text = settings["ensemble"]!.GetValue<string>(); assignment.Text = settings["prompt"]!.GetValue<string>();
            pieceHistory.Clear(); pieceHistory.AddRange(restoredHistory); RefreshHistory();
        } finally { loadingSettings = false; }
        SaveLocalState(); SetStatus("Backup geladen. Aktuelle Stückplätze bleiben erhalten.");
    }
}

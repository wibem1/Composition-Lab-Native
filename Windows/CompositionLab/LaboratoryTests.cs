using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed partial class MainForm
{
    async Task RunLaboratoryTestsAsync(string output)
    {
        string fixturePath = Environment.GetEnvironmentVariable("COMPOSITION_LAB_BACKUP_FIXTURE") ?? throw new Exception("Backup fixture fehlt.");
        var fixture = JsonNode.Parse(await File.ReadAllTextAsync(fixturePath))!.AsObject();
        string password = fixture["password"]!.GetValue<string>();
        byte[] envelope = System.Text.Encoding.UTF8.GetBytes(fixture["envelope"]!.ToJsonString());
        var payload = PortableBackupCrypto.Decrypt(envelope, password);
        if (payload["apiKeys"]?["anthropic"]?.GetValue<string>() != "OFFLINE-TEST-NOT-A-REAL-KEY" || payload["settings"]?["prompt"]?.GetValue<string>() != "Test 𝄞") throw new Exception("Backup-Austausch verliert Daten.");
        await core.RunAsync(new JsonObject { ["operation"] = "validate-backup", ["document"] = payload.DeepClone() });
        _ = PortableBackupCrypto.Decrypt(PortableBackupCrypto.Encrypt(payload, password), password);
        bool rejected = false;
        try { PortableBackupCrypto.Decrypt(envelope, "wrong"); } catch (InvalidDataException) { rejected = true; }
        if (!rejected) throw new Exception("Falsches Backup-Passwort akzeptiert.");
        string before = new JsonArray(documents.Select(d => d?.DeepClone()).ToArray()).ToJsonString();
        foreach (bool comparison in new[] { false, true })
        {
            using var lab = BuildLaboratory(comparison);
            lab.Show(this); lab.PerformLayout(); await Task.Delay(80);
            if (lab.Controls.Count != 1 || !lab.Visible) throw new Exception("Laboroberfläche nicht sichtbar.");
            using var image = new Bitmap(lab.ClientSize.Width, lab.ClientSize.Height);
            lab.DrawToBitmap(image, new Rectangle(Point.Empty, image.Size));
            image.Save(Path.Combine(output, comparison ? "Vergleichslabor.png" : "Experimentallabor.png"));
            lab.Close();
        }
        if (new JsonArray(documents.Select(d => d?.DeepClone()).ToArray()).ToJsonString() != before)
            throw new Exception("Laborinitialisierung verändert die Hauptkomposition.");
        var prompt = await core.RunAsync(new JsonObject { ["operation"] = "lab-prompt", ["kind"] = "compare", ["task"] = "Prüfen", ["first"] = "Quelle A", ["second"] = "Quelle B" });
        if (!prompt["prompt"]!.GetValue<string>().Contains("Quelle B")) throw new Exception("Vergleich verliert Quelle B.");
    }
}

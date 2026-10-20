using System.Text;
using System.Text.Json.Nodes;

namespace CompositionLab;

// Native laboratory presentation. Musical contracts live in CompositionCore;
// results and their player remain isolated from the main workspace until transfer.
internal sealed partial class MainForm
{
    Task ShowLaboratory(bool compare)
    {
        if (busy) return Task.CompletedTask;
        using var dialog = BuildLaboratory(compare);
        dialog.ShowDialog(this);
        return Task.CompletedTask;
    }

    Form BuildLaboratory(bool compare)
    {
        var dialog = new Form { Text = compare ? "Vergleichslabor" : "Experimentallabor", Width = 1050, Height = 740,
            MinimumSize = new Size(820, 600), StartPosition = FormStartPosition.CenterParent };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5, Padding = new Padding(14) };
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize)); layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 25)); layout.RowStyles.Add(new RowStyle(SizeType.Percent, 75)); layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        dialog.Controls.Add(layout);
        var sources = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true };
        var a = new ComboBox { Width = 290, DropDownStyle = ComboBoxStyle.DropDownList };
        var b = new ComboBox { Width = 290, DropDownStyle = ComboBoxStyle.DropDownList };
        var entries = documents.Where(d => d != null).Select(d => d!.DeepClone().AsObject())
            .Concat(pieceHistory.Select(d => d.DeepClone().AsObject())).ToList();
        foreach (var document in entries) { string title = document["title"]?.GetValue<string>() ?? "Stück"; a.Items.Add(title); b.Items.Add(title); }
        if (entries.Count > 0) { a.SelectedIndex = 0; b.SelectedIndex = Math.Min(1, entries.Count - 1); }
        sources.Controls.Add(new Label { Text = compare ? "Quelle A" : "Vorlage / Verlauf", AutoSize = true, Padding = new Padding(0, 8, 0, 0) }); sources.Controls.Add(a);
        if (compare) { sources.Controls.Add(new Label { Text = "Quelle B", AutoSize = true, Padding = new Padding(0, 8, 0, 0) }); sources.Controls.Add(b); }
        layout.Controls.Add(sources, 0, 0);
        var parameters = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true };
        var bars = new NumericUpDown { Minimum = 1, Maximum = 16, Value = 4, Width = 55 };
        var labTempo = new TextBox { Width = 60, PlaceholderText = "Tempo" };
        var labEnsemble = new TextBox { Width = 140, Text = "Klavier solo" };
        var style = new TextBox { Width = 180, PlaceholderText = "Stil / Charakter" };
        if (!compare) { parameters.Controls.Add(new Label { Text = "Takte", AutoSize = true }); parameters.Controls.Add(bars); parameters.Controls.Add(new Label { Text = "Tempo", AutoSize = true }); parameters.Controls.Add(labTempo); parameters.Controls.Add(new Label { Text = "Besetzung", AutoSize = true }); parameters.Controls.Add(labEnsemble); parameters.Controls.Add(new Label { Text = "Stil", AutoSize = true }); parameters.Controls.Add(style); }
        layout.Controls.Add(parameters, 0, 1);
        var task = new TextBox { Multiline = true, Dock = DockStyle.Fill, ScrollBars = ScrollBars.Vertical, PlaceholderText = compare ? "Frage oder Auftrag zu A und B" : "Musikalischer Impuls für das Motiv" };
        var output = new RichTextBox { ReadOnly = true, Dock = DockStyle.Fill, Font = new Font("Segoe UI", 11), BackColor = SystemColors.Window };
        var taskHost = new Panel { Dock = DockStyle.Fill };
        taskHost.Controls.Add(task); taskHost.Controls.Add(new Label { Text = compare ? "Frage oder Auftrag zu A und B" : "Musikalischer Impuls für das Motiv", Dock = DockStyle.Top, Height = 24 });
        var outputHost = new Panel { Dock = DockStyle.Fill };
        outputHost.Controls.Add(output); outputHost.Controls.Add(new Label { Text = "Dialog und Ergebnis", Dock = DockStyle.Top, Height = 24 });
        layout.Controls.Add(taskHost, 0, 2); layout.Controls.Add(outputHost, 0, 3);
        var actions = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true }; layout.Controls.Add(actions, 0, 4);
        var labPlayer = new MidiPlayer { OutputDevice = player.OutputDevice };
        JsonObject? resultDocument = null;
        bool running = false;
        var cancellation = new CancellationTokenSource();
        var buttons = new List<Button>();
        void Button(string label, Func<Task> action)
        {
            var button = new Button { Text = label, AutoSize = true };
            buttons.Add(button); actions.Controls.Add(button);
            button.Click += async (_, _) => {
                if (running) return;
                running = true; foreach (var item in buttons) item.Enabled = false;
                try { await action(); }
                catch (OperationCanceledException) { if (!dialog.IsDisposed) output.AppendText("\nAbgebrochen. Letzte gültige Fassung bleibt erhalten."); }
                catch (Exception error) { if (!dialog.IsDisposed) output.AppendText("\n" + error.Message); }
                finally { running = false; if (!dialog.IsDisposed) foreach (var item in buttons) item.Enabled = true; }
            };
        }
        JsonObject Source(ComboBox choice) => choice.SelectedIndex >= 0 && choice.SelectedIndex < entries.Count ? entries[choice.SelectedIndex] : throw new InvalidOperationException("Bitte eine Vorlage wählen.");
        async Task<byte[]> Midi(JsonObject doc)
        {
            if (doc["sourceMidiData"] is JsonValue original && original.TryGetValue<string>(out var data)) return Convert.FromBase64String(data);
            var response = await core.RunAsync(new JsonObject { ["operation"] = "midi", ["score"] = doc["score"]!.DeepClone() }, cancellation.Token);
            return Convert.FromBase64String(response["data"]!.GetValue<string>());
        }
        async Task Play(JsonObject doc) { byte[] midi = await Midi(doc); cancellation.Token.ThrowIfCancellationRequested(); labPlayer.Load(midi); labPlayer.Play(); }
        async Task Ask(string kind)
        {
            string providerName = activeProvider, modelName = SelectedModelId, key = apiKey.Text.Trim();
            if (key.Length == 0) key = ProviderKey(providerName);
            if (key.Length == 0) throw new InvalidOperationException("Bitte den API-Schlüssel eintragen.");
            var promptRequest = new JsonObject { ["operation"] = "lab-prompt", ["kind"] = kind, ["task"] = task.Text,
                ["first"] = a.SelectedIndex < 0 ? "" : Source(a).ToJsonString(), ["second"] = !compare || b.SelectedIndex < 0 ? "" : Source(b).ToJsonString(),
                ["measures"] = (int)bars.Value, ["tempo"] = labTempo.Text, ["ensemble"] = labEnsemble.Text, ["style"] = style.Text };
            var prompt = await core.RunAsync(promptRequest, cancellation.Token);
            var response = await core.RunAsync(new JsonObject { ["operation"] = "chat", ["apiKey"] = key,
                ["request"] = new JsonObject { ["assignment"] = prompt["prompt"]!.DeepClone(), ["provider"] = providerName, ["model"] = modelName,
                    ["effort"] = effort.SelectedIndex switch { 0 => "low", 2 => "high", _ => "medium" } } }, cancellation.Token);
            var diagnostic = response["result"]!.AsObject();
            lastDiagnostic = diagnostic.DeepClone().AsObject(); UpdateDiagnostic(); SaveLocalState();
            string answer = diagnostic["text"]!.GetValue<string>();
            if (kind == "route") {
                var routed = await core.RunAsync(new JsonObject { ["operation"] = "lab-route", ["response"] = answer }, cancellation.Token);
                if (!dialog.IsDisposed) output.AppendText("\nKI: " + routed["route"]!["reply"]!.GetValue<string>() + "\n");
                if (routed["route"]!["compose"]!.GetValue<bool>()) await Ask("revision");
                return;
            }
            if (!dialog.IsDisposed) output.AppendText("\nKI: " + answer + "\n");
            if (kind is "compare" or "analysis") return;
            // Preserve paid original before any local interpretation can fail.
            var interpreted = await ImportAIResponseLocallyAsync(answer, diagnostic, cancellation.Token)
                ?? throw new InvalidDataException("Originalantwort in Diagnose gesichert; Format ist nicht lokal lesbar.");
            if (kind == "motif") await core.RunAsync(new JsonObject { ["operation"] = "validate-motif", ["score"] = interpreted["score"]!.DeepClone(), ["measures"] = (int)bars.Value }, cancellation.Token);
            cancellation.Token.ThrowIfCancellationRequested();
            var candidate = CreateDocument(interpreted["score"]!.DeepClone().AsObject(), answer, task.Text);
            foreach (var field in interpreted) if (field.Key is "directLilyPond" or "sourceMidiData" or "octaveReview" or "originalLilyPond") candidate[field.Key] = field.Value?.DeepClone();
            candidate["provider"] = providerName; candidate["model"] = modelName; candidate["area"] = compare ? "comparison" : "experiment";
            candidate["costUSD"] = diagnostic["estimatedCostUSD"]?.DeepClone(); candidate["inputTokens"] = diagnostic["inputTokens"]?.DeepClone(); candidate["outputTokens"] = diagnostic["outputTokens"]?.DeepClone();
            resultDocument = candidate;
            RememberPiece(candidate); SaveLocalState();
            if (!dialog.IsDisposed) output.AppendText("\nErgebnis bereit. Hauptkomposition unverändert.\n");
        }
        Button("Vorlage importieren …", async () => {
            using var open = new OpenFileDialog { Filter = "Musik|*.mid;*.midi;*.musicxml;*.xml;*.clab" };
            if (open.ShowDialog(dialog) != DialogResult.OK) return;
            byte[] data = await File.ReadAllBytesAsync(open.FileName, cancellation.Token);
            JsonObject doc;
            string ext = Path.GetExtension(open.FileName).ToLowerInvariant();
            if (ext == ".clab") { doc = JsonNode.Parse(data)!.AsObject(); await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = doc.DeepClone() }, cancellation.Token); }
            else {
                var imported = await core.RunAsync(new JsonObject { ["operation"] = ext is ".xml" or ".musicxml" ? "import-musicxml" : "import-midi", ["data"] = Convert.ToBase64String(data), ["title"] = Path.GetFileNameWithoutExtension(open.FileName) }, cancellation.Token);
                doc = CreateDocument(imported["score"]!.AsObject(), "Import: " + Path.GetFileName(open.FileName));
                if (ext is ".mid" or ".midi") doc["sourceMidiData"] = Convert.ToBase64String(data);
            }
            entries.Add(doc); a.Items.Add(doc["title"]?.ToString() ?? "Import"); b.Items.Add(doc["title"]?.ToString() ?? "Import"); a.SelectedIndex = entries.Count - 1;
        });
        Button("A anhören", () => Play(Source(a)));
        if (compare) Button("B anhören", () => Play(Source(b)));
        Button("Stopp", () => { labPlayer.Stop(); return Task.CompletedTask; });
        if (compare) { Button("Vergleichen", () => Ask("compare")); Button("Senden", () => Ask("route")); }
        else { Button("Motiv erzeugen", () => Ask("motif")); Button("Besprechen", () => Ask("analysis")); }
        Button("Ergebnis anhören", () => Play(resultDocument ?? throw new InvalidOperationException("Noch kein Laborergebnis.")));
        Button("MIDI sichern …", async () => {
            var doc = resultDocument ?? Source(a);
            using var save = new SaveFileDialog { Filter = "MIDI|*.mid", FileName = SafeName(doc["title"]?.ToString() ?? "Labor") + ".mid" };
            if (save.ShowDialog(dialog) == DialogResult.OK) await File.WriteAllBytesAsync(save.FileName, await Midi(doc), cancellation.Token);
        });
        Button("An Komposition übergeben", async () => {
            var doc = resultDocument ?? Source(a);
            int destination = documents.FirstFreeIndex();
            if (destination < 0) throw new InvalidOperationException("Bitte einen Slot freimachen.");
            await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = doc.DeepClone() }, cancellation.Token);
            compositionReference = new JsonObject { ["name"] = doc["title"]?.DeepClone(), ["score"] = doc["score"]!.DeepClone() };
            documents[destination] = doc.DeepClone().AsObject(); RefreshSlots();
            slots.SelectedIndex = destination; await DisplayCurrentAsync(); SaveLocalState();
        });
        dialog.FormClosing += (_, _) => cancellation.Cancel();
        dialog.FormClosed += (_, _) => { labPlayer.Dispose(); cancellation.Dispose(); };
        return dialog;
    }
}

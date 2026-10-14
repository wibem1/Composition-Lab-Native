using System.Text;
using System.Diagnostics;
using System.Text.RegularExpressions;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace CompositionLab;

internal sealed partial class MainForm : Form
{
    const string Version = "4.0.0-alpha.8 · Build 4008";
    readonly CoreClient core = new();
    readonly MidiPlayer player = new();
    readonly string dataDirectory;
    readonly SecretStore secrets;
    Dictionary<string, string> keys = [];
    readonly Dictionary<string, string> models = new()
    { ["anthropic"] = "claude-sonnet-5", ["openai"] = "gpt-5.6-sol", ["gemini"] = "gemini-3.7-flash" };
    readonly JsonObject?[] documents = new JsonObject?[10];
    readonly ListBox slots = new() { Dock = DockStyle.Fill, IntegralHeight = false };
    readonly ComboBox provider = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 155 };
    readonly ComboBox model = new() { Width = 250, DropDownStyle = ComboBoxStyle.DropDownList, DropDownWidth = 190 };
    readonly ComboBox effort = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 145 };
    readonly TextBox apiKey = new() { Width = 240, UseSystemPasswordChar = true };
    readonly CheckBox remember = new() { Text = "Schlüssel speichern", AutoSize = true };
    readonly TextBox assignment = new() { Multiline = true, ScrollBars = ScrollBars.Vertical, Dock = DockStyle.Fill };
    readonly RichTextBox chat = new() { Dock = DockStyle.Fill, ReadOnly = true, BackColor = Color.White, DetectUrls = true };
    readonly RichTextBox diagnostic = new() { Dock = DockStyle.Fill, ReadOnly = true, Font = new Font("Consolas", 10) };
    readonly RichTextBox composition = new() { Dock = DockStyle.Fill, ReadOnly = true, BackColor = Color.White };
    readonly ComboBox measures = new() { Width = 55, DropDownStyle = ComboBoxStyle.DropDown, AutoCompleteMode = AutoCompleteMode.None };
    readonly TextBox tempo = new() { Width = 55 };
    readonly TextBox musicalKey = new() { Width = 90 };
    readonly TextBox ensemble = new() { Width = 130, Text = "Klavier" };
    readonly CheckBox useSource = new() { Text = "Aktuelles Stück als Vorlage", AutoSize = true };
    readonly Button compose = new StudioButton() { Text = "Komponieren", AutoSize = true, Primary = true };
    readonly Button send = new StudioButton() { Text = "Chat", AutoSize = true };
    readonly Button cancel = new StudioButton() { Text = "Abbrechen", AutoSize = true, Enabled = false };
    readonly ToolStripStatusLabel status = new() { Text = "Bereit", Spring = true, TextAlign = ContentAlignment.MiddleLeft };
    readonly ToolStripStatusLabel cost = new() { Text = "Kosten: –" };
    readonly Label pieceTitle = new() { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(8), Text = "Kein Stück geladen" };
    readonly Label playback = new() { AutoSize = true, Padding = new Padding(10, 7, 0, 0), Text = "00:00 / 00:00" };
    readonly Panel notationHost = new() { Dock = DockStyle.Fill, BackColor = Color.White };
    readonly WebView2 web = new() { Dock = DockStyle.Fill };
    readonly System.Windows.Forms.Timer playbackTimer = new() { Interval = 300 };
    readonly WorkspaceHost tabs = new() { Dock = DockStyle.Fill };
    readonly List<Button> slotCards = [];
    readonly List<StudioButton> navButtons = [];
    readonly Label libraryCount = new();
    readonly Label pieceInfo = new();
    readonly List<Button> slotActions = [];
    readonly ToolTip slotTips = new();
    readonly bool testMode;
    CancellationTokenSource? pending;
    bool loadingSettings;
    bool webReady;
    string activeProvider = "anthropic";
    byte[]? currentMidi;
    string? currentXML;
    string? currentPath;
    JsonObject? lastDiagnostic;
    bool busy;
    int displayGeneration;
    JsonObject? Current => slots.SelectedIndex >= 0 ? documents[slots.SelectedIndex] : null;
    JsonObject? Score => Current?["score"]?.AsObject();

    public MainForm(bool testMode)
    {
        SuspendLayout();
        this.testMode = testMode;
        dataDirectory = testMode ? Path.Combine(Path.GetTempPath(), "clab-v4-test-" + Guid.NewGuid().ToString("N"))
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Klangwerke", "Composition Lab 4.0");
        secrets = new SecretStore(dataDirectory);
        Text = "Composition Lab Native · Windows · " + Version;
        MinimumSize = new Size(900, 680); ClientSize = new Size(1260, 950);
        StartPosition = FormStartPosition.CenterScreen;
        Font = MacFont(13); ForeColor = StudioTheme.Ink;
        BackColor = StudioTheme.Canvas;
        AutoScaleMode = AutoScaleMode.Dpi;
        AutoScaleDimensions = new SizeF(96, 96);
        BuildUI();
        ResumeLayout(true);
        LoadLocalState();
        mainSplitReady = true;
        RefreshSlots();
        slots.SelectedIndex = 0;
        Shown += async (_, _) =>
        {
            if (!testMode)
            {
                // Fit after Windows has applied the monitor DPI; keep the title bar reachable.
                var area = Screen.FromControl(this).WorkingArea;
                MinimumSize = new Size(Math.Min(MinimumSize.Width, area.Width - 40), Math.Min(MinimumSize.Height, area.Height - 40));
                Size = new Size(Math.Min(Width, area.Width - 40), Math.Min(Height, area.Height - 40));
                Location = new Point(area.Left + (area.Width - Width) / 2, area.Top + (area.Height - Height) / 2);
                await InitializeNotationAsync();
            }
            try
            {
                var result = await core.RunAsync(new JsonObject { ["operation"] = "version" });
                SetStatus("Bereit · gemeinsamer Kern " + result["version"]?.GetValue<string>());
            }
            catch (Exception e) { SetStatus(e.Message, true); }
        };
        FormClosing += (_, _) => { pending?.Cancel(); SaveLocalState(); player.Close(); };
        playbackTimer.Tick += (_, _) =>
        {
            if (!player.Loaded) return;
            try { UpdateTransport(); }
            catch (Exception e) { SetStatus(e.Message, true); playbackTimer.Stop(); }
        };
        playbackTimer.Start();
    }

    void BuildUI() => BuildMacUI();

    static TableLayoutPanel Grid(int columns, int rows)
    {
        var grid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = columns, RowCount = rows, Margin = Padding.Empty, BackColor = Color.Transparent };
        for (int i = 0; i < columns; i++) grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f / columns));
        return grid;
    }
    static Control Field(string title, Control control)
    {
        var field = Grid(1, 2); field.Margin = new Padding(3, 0, 5, 4);
        field.RowStyles.Add(new RowStyle(SizeType.Absolute, 19)); field.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        field.Controls.Add(new Label { Text = title, Dock = DockStyle.Fill, Font = new Font("Segoe UI", 8.5f), ForeColor = StudioTheme.Muted }, 0, 0);
        control.Dock = DockStyle.Top; control.Margin = Padding.Empty;
        if (control is TextBox box) { box.BorderStyle = BorderStyle.FixedSingle; box.BackColor = Color.White; }
        field.Controls.Add(control, 0, 1); return field;
    }
    static Control TextSurface(string title, string subtitle, RichTextBox text)
    {
        var surface = new StudioSurface { Dock = DockStyle.Fill, Padding = new Padding(14) };
        var grid = Grid(1, 3); grid.RowStyles.Add(new RowStyle(SizeType.Absolute, 26)); grid.RowStyles.Add(new RowStyle(SizeType.Absolute, 24)); grid.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        grid.Controls.Add(new Label { Text = title, Font = new Font("Segoe UI", 12, FontStyle.Bold), ForeColor = StudioTheme.Ink, Dock = DockStyle.Fill }, 0, 0);
        grid.Controls.Add(new Label { Text = subtitle, Font = new Font("Segoe UI", 9), ForeColor = StudioTheme.Muted, Dock = DockStyle.Fill, AutoEllipsis = true }, 0, 1);
        text.BorderStyle = BorderStyle.None; text.ForeColor = StudioTheme.Ink; text.Font = new Font(title == "Komposition" ? "Consolas" : "Segoe UI", 10);
        grid.Controls.Add(text, 0, 2); surface.Controls.Add(grid); return surface;
    }

    static FlowLayoutPanel Row() => new() { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Padding = new Padding(4, 2, 4, 2) };
    static void Add(Control row, string label, Control field)
    { row.Controls.Add(new Label { Text = label, AutoSize = true, Padding = new Padding(5, 7, 0, 0) }); row.Controls.Add(field); }
    StudioButton AddButton(Control row, string title, Func<Task> action)
    {
        var button = new StudioButton { Text = title, AutoSize = true };
        button.Click += async (_, _) => { try { await action(); } catch (Exception e) { SetStatus(e.Message, true); } };
        row.Controls.Add(button); guiChecks.Add(button); return button;
    }

    void ProviderChanged()
    {
        if (loadingSettings) return;
        models[activeProvider] = SelectedModelId;
        activeProvider = provider.SelectedIndex switch { 1 => "anthropic", 2 => "openai", _ => "gemini" };
        SelectModel();
        apiKey.Text = keys.GetValueOrDefault(activeProvider, ""); remember.Checked = keys.ContainsKey(activeProvider);
        SaveLocalState();
    }

    void StoreKey()
    {
        if (remember.Checked) keys[activeProvider] = apiKey.Text.Trim();
        else keys.Remove(activeProvider);
        secrets.Save(keys);
        SetStatus(remember.Checked ? "Schlüssel verschlüsselt gespeichert." : "Schlüssel wird nur in dieser Sitzung verwendet.");
    }

    async Task RequestAIAsync(bool makeMusic)
    {
        if (busy) return;
        if (makeMusic) assignment.Text = composition.Text.Length > 0 ? composition.Text : assignment.Text;
        string inputText = makeMusic ? assignment.Text : chatInput.Text;
        if (string.IsNullOrWhiteSpace(inputText)) { SetStatus("Bitte einen Auftrag eingeben.", true); return; }
        if (string.IsNullOrWhiteSpace(apiKey.Text)) { SetStatus("Bitte API-Schlüssel eingeben.", true); return; }
        int destination = -1;
        if (makeMusic)
        {
            destination = Current == null ? slots.SelectedIndex : Array.FindIndex(documents, d => d == null);
            if (destination < 0) { SetStatus("Alle zehn Slots sind belegt. Bitte zuerst ein Stück speichern und einen Slot leeren.", true); return; }
        }
        string userText = inputText.Trim();
        string instruction = userText;
        if (makeMusic)
        {
            if (!string.IsNullOrWhiteSpace(measures.Text)) instruction += "\nTaktanzahl: " + measures.Text;
            if (!string.IsNullOrWhiteSpace(meter.Text)) instruction += "\nTaktart: " + meter.Text;
            if (!string.IsNullOrWhiteSpace(tempo.Text)) instruction += "\nTempo (BPM): " + tempo.Text;
            if (!string.IsNullOrWhiteSpace(musicalKey.Text)) instruction += "\nTonart: " + musicalKey.Text;
            if (!string.IsNullOrWhiteSpace(ensemble.Text)) instruction += "\nBesetzung: " + ensemble.Text;
        }
        else if (!string.IsNullOrEmpty(chat.Text)) instruction = "Bisheriger musikalischer Dialog:\n" +
                (chat.Text.Length > 16000 ? chat.Text[^16000..] : chat.Text) + "\n\nAktuelle Nachricht:\n" + instruction;
        if (useSource.Checked && Score != null) instruction += "\nBewusst gewählte musikalische Vorlage:\n" + Score.ToJsonString();
        var request = new JsonObject { ["assignment"] = instruction, ["provider"] = activeProvider,
            ["model"] = SelectedModelId, ["effort"] = effort.SelectedIndex switch { 0 => "low", 2 => "high", _ => "medium" } };
        string selectedProvider = activeProvider, selectedModel = SelectedModelId;
        try
        {
            StoreKey(); pending = new CancellationTokenSource(); SetBusy(true);
            chat.AppendText("Du: " + userText + "\n\n");
            SetStatus(makeMusic ? "KI komponiert …" : "KI antwortet …");
            var response = await core.RunAsync(new JsonObject { ["operation"] = makeMusic ? "compose" : "chat",
                ["apiKey"] = apiKey.Text.Trim(), ["request"] = request }, pending.Token,
                stage => SetStatus(stage == "technical-translation-request" ? "Technische Übertragung der fertigen Komposition …" : "KI komponiert …"));
            var result = response["result"]!.AsObject();
            lastDiagnostic = result.DeepClone().AsObject();
            lastDiagnostic["interface"] = "Windows WinForms"; lastDiagnostic["interfaceVersion"] = Version;
            UpdateDiagnostic();
            if (makeMusic)
            {
                var document = CreateDocument(result["score"]!.DeepClone().AsObject(), result["composition"]!.GetValue<string>(), userText);
                document["provider"] = selectedProvider; document["model"] = selectedModel;
                document["costUSD"] = result["estimatedCostUSD"]!.DeepClone();
                document["inputTokens"] = result["inputTokens"]!.DeepClone(); document["outputTokens"] = result["outputTokens"]!.DeepClone();
                documents[destination] = document; RememberPiece(document); RefreshSlots(); slots.SelectedIndex = destination;
                await DisplayCurrentAsync();
                chat.AppendText("KI: Stück fertig: " + document["title"]?.GetValue<string>() + "\n\n");
            }
            else { string answer = result["text"]!.GetValue<string>(); chat.AppendText("KI: " + answer + "\n\n"); if (string.IsNullOrWhiteSpace(composition.Text)) composition.Text = answer; chatInput.Clear(); }
            cost.Text = "Anfrage ca. $" + result["estimatedCostUSD"]!.GetValue<double>().ToString("0.0000");
            SetStatus(makeMusic ? "Komposition abgeschlossen." : "Antwort erhalten."); SaveLocalState();
        }
        catch (OperationCanceledException) { SetStatus("Anfrage lokal abgebrochen."); }
        catch (CoreRequestException e)
        { lastDiagnostic = e.Diagnostic; UpdateDiagnostic(); SetStatus(e.Message, true); SaveLocalState(); }
        catch (Exception e) { SetStatus(e.Message, true); }
        finally { pending?.Dispose(); pending = null; SetBusy(false); }
    }

    void SetBusy(bool value)
    {
        busy = value; compose.Enabled = !value; send.Enabled = !value; cancel.Enabled = value;
        provider.Enabled = !value; model.Enabled = !value; effort.Enabled = !value; apiKey.Enabled = !value;
    }

    JsonObject CreateDocument(JsonObject score, string concept, string userAssignment = "") => new()
    {
        ["format"] = "composition-lab-document", ["version"] = 1,
        ["savedAt"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - 978307200,
        ["title"] = score["ti"]?.GetValue<string>() ?? "Komposition", ["score"] = score,
        ["concept"] = concept, ["measures"] = measures.Text, ["meter"] = meter.Text,
        ["tempo"] = tempo.Text, ["musicalKey"] = musicalKey.Text, ["ensemble"] = ensemble.Text,
        ["assignment"] = userAssignment
    };

    async Task DisplayCurrentAsync()
    {
        int generation = ++displayGeneration;
        player.Close(); currentMidi = null; currentXML = null; currentPath = null;
        var document = Current;
        playback.Text = "00:00 / 00:00";
        if (document == null) { cost.Text = "Kosten: –"; pieceInfo.Text = "Wähle links ein Stück oder komponiere etwas Neues."; pieceTitle.Text = "Raum für deine nächste Idee"; scoreJSON.Clear(); validation.Clear(); notationCurrent.Text = "Aktuelles Stück: –"; if (webReady) web.NavigateToString("<html><body>Kein Stück geladen.</body></html>"); return; }
        pieceTitle.Text = document["title"]?.GetValue<string>() ?? "Komposition"; notationCurrent.Text = "Aktuelles Stück: " + pieceTitle.Text;
        var scoreInfo = document["score"];
        pieceInfo.Text = string.Join("  ·  ", new[] { document["ensemble"]?.GetValue<string>(), scoreInfo?["k"]?.GetValue<string>(), scoreInfo?["bpm"]?.ToString() is string bpm ? bpm + " BPM" : null }.Where(v => !string.IsNullOrWhiteSpace(v)));
        scoreJSON.Text = document["score"]?.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) ?? "";
        validation.Text = "Technische Prüfung läuft …";
        playerBpm = double.TryParse(document["score"]?["bpm"]?.ToString(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out double bpmValue) ? (int)Math.Round(bpmValue) : 96; tempoOverride = false; foreach (var transport in transports) transport.Tempo.Text = playerBpm.ToString();
        try
        {
            var score = document["score"]!.DeepClone();
            var midi = await core.RunAsync(new JsonObject { ["operation"] = "midi", ["score"] = score });
            var xml = await core.RunAsync(new JsonObject { ["operation"] = "musicxml", ["score"] = score.DeepClone(), ["options"] = notationOptions?.DeepClone() });
            if (generation != displayGeneration) return;
            currentMidi = Convert.FromBase64String(midi["data"]!.GetValue<string>());
            currentXML = Encoding.UTF8.GetString(Convert.FromBase64String(xml["data"]!.GetValue<string>()));
            if (webReady) RenderNotation();
            validation.Text = "Technische Partiturprüfung bestanden. MIDI und MusicXML erzeugt.\n\n" + (document["title"]?.GetValue<string>() ?? "");
            cost.Text = document["costUSD"] is JsonValue c && c.TryGetValue<double>(out double n) ? "Stück ca. $" + n.ToString("0.0000") : "Kosten: –";
        }
        catch (Exception e) { if (generation == displayGeneration) SetStatus(e.Message, true); }
    }

    void RefreshSlots()
    {
        int selected = slots.SelectedIndex;
        slots.BeginUpdate(); slots.Items.Clear();
        for (int i = 0; i < documents.Length; i++) slots.Items.Add($"{i + 1:00}  " + (documents[i]?["title"]?.GetValue<string>() ?? "— frei —"));
        slots.SelectedIndex = selected < 0 ? 0 : selected; slots.EndUpdate(); RefreshCards();
    }
    void RefreshCards()
    {

        for (int i = 0; i < slotCards.Count; i++)
        {
            var title = documents[i]?["title"]?.GetValue<string>() ?? "";
            var card = (PieceCard)slotCards[i]; card.PieceTitle = title; card.Occupied = documents[i] != null;
            card.Selected = i == slots.SelectedIndex; card.Text = (i + 1) + ": " + title; card.Invalidate();
            slotTips.SetToolTip(card, title + "\nKlick: auswählen / freien Platz laden. Rechtsklick: laden, speichern, löschen. Dateidrop möglich.");
        }
        for (int i = 0; i < notationCards.Count; i++) { notationCards[i].Text = (documents[i] == null ? "" : "●") + (i + 1); notationCards[i].Selected = i == slots.SelectedIndex; notationCards[i].Invalidate(); }
    }
    void SelectFreeSlot()
    { int free = Array.FindIndex(documents, d => d == null); if (free < 0) SetStatus("Alle Slots belegt.", true); else slots.SelectedIndex = free; }

    async Task OpenAsync(int? destination = null)
    {
        if (busy) return;
        using var dialog = new OpenFileDialog { Filter = "Musikdateien und Diagnosen|*.clab;*.mid;*.midi;*.musicxml;*.xml;*.json;*.clabproject|Alle Dateien|*.*" };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        if (destination.HasValue) await ImportIntoSlotAsync(dialog.FileName, destination.Value);
        else await ImportPathAsync(dialog.FileName);
    }
    async Task ImportPathAsync(string path, int? targetSlot = null)
    {
        int destination = targetSlot ?? (Current == null ? slots.SelectedIndex : Array.FindIndex(documents, d => d == null));
        if (destination < 0) throw new InvalidOperationException("Alle Slots belegt. Bitte einen Slot freimachen.");
        if (Path.GetExtension(path).Equals(".clabproject", StringComparison.OrdinalIgnoreCase)) { await LoadProjectPathAsync(path); return; }
        var data = await File.ReadAllBytesAsync(path); JsonObject document;
        if (Path.GetExtension(path).Equals(".clab", StringComparison.OrdinalIgnoreCase))
        {
            document = JsonNode.Parse(data)!.AsObject();
            await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = document.DeepClone() });
        }
        else if (Path.GetExtension(path).Equals(".json", StringComparison.OrdinalIgnoreCase))
        {
            var sourceDiagnostic = JsonNode.Parse(data)!.AsObject();
            var raw = RepairLegacyText(sourceDiagnostic["scoreResponse"]?.GetValue<string>() ?? throw new InvalidDataException("Diese Diagnose enthält keine technische Partiturantwort."));
            var response = await core.RunAsync(new JsonObject { ["operation"] = "recover-score", ["response"] = raw });
            document = CreateDocument(response["score"]!.DeepClone().AsObject(),
                RepairLegacyText(sourceDiagnostic["composition"]?.GetValue<string>() ?? ""), RepairLegacyText(sourceDiagnostic["assignment"]?.GetValue<string>() ?? ""));
            foreach (string field in new[] { "provider", "model", "inputTokens", "outputTokens" })
                if (sourceDiagnostic[field] != null) document[field] = sourceDiagnostic[field]!.DeepClone();
            document["costUSD"] = sourceDiagnostic["estimatedCostUSD"]?.DeepClone();
            lastDiagnostic = sourceDiagnostic.DeepClone().AsObject();
            lastDiagnostic["recoveredScore"] = document["score"]!.DeepClone();
            lastDiagnostic["recoveryVersion"] = Version; UpdateDiagnostic();
        }
        else
        {
            bool midi = new[] { ".mid", ".midi" }.Contains(Path.GetExtension(path).ToLowerInvariant());
            var response = await core.RunAsync(new JsonObject { ["operation"] = midi ? "import-midi" : "import-musicxml",
                ["data"] = Convert.ToBase64String(data), ["title"] = Path.GetFileNameWithoutExtension(path) });
            document = CreateDocument(response["score"]!.DeepClone().AsObject(), "Import: " + Path.GetFileName(path));
            if (!midi) document["originalMusicXMLData"] = Convert.ToBase64String(data);
        }
        documents[destination] = document; RememberPiece(document); RefreshSlots(); slots.SelectedIndex = destination;
        await DisplayCurrentAsync(); currentPath = Path.GetExtension(path).Equals(".clab", StringComparison.OrdinalIgnoreCase) ? path : null;
        SaveLocalState(); SetStatus("Datei geladen.");
    }
    async Task GuardAsync(Func<Task> action)
    { try { await action(); } catch (Exception e) { SetStatus(e.Message, true); } }

    async Task ImportIntoSlotAsync(string path, int index)
    {
        if (busy) return;
        if (documents[index] != null && !testMode && MessageBox.Show(this,
            $"Stück {index + 1} durch die gewählte Datei ersetzen? Die gespeicherte Datei bleibt erhalten.", "Stück laden", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        // Parse and validate before assigning: failed imports leave the old piece intact.
        await ImportPathAsync(path, index);
    }
    async Task DeleteSlotAsync(int index)
    {
        if (busy || documents[index] == null) return;
        if (!testMode && MessageBox.Show(this, $"Stück {index + 1} aus der App entfernen? Gespeicherte Dateien bleiben erhalten.",
            "Stück löschen", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
        documents[index] = null; RefreshCards(); SaveLocalState();
        if (slots.SelectedIndex == index) await DisplayCurrentAsync();
        SetStatus($"Stück {index + 1} gelöscht.");
    }

    internal static string ExtractLilyPond(string text)
    {
        var fenced = Regex.Match(text, @"```(?:lilypond|ly)?[^\S\r\n]*\r?\n(?<source>[\s\S]*?)```", RegexOptions.IgnoreCase);
        string source = fenced.Success ? fenced.Groups["source"].Value.Trim() : text.Trim();
        if (!source.Contains(@"\version") && !source.Contains(@"\score"))
            throw new InvalidOperationException("Dieses Stück enthält keinen LilyPond-Quelltext. MIDI- und MusicXML-Exporte sind weiterhin verfügbar.");
        return source + "\n";
    }
    async Task ExportLilyPondAsync()
    {
        if (Current == null) throw new InvalidOperationException("Kein Stück geladen.");
        string source = ExtractLilyPond(Current["concept"]?.GetValue<string>() ?? "");
        using var dialog = new SaveFileDialog { Filter = "LilyPond|*.ly", FileName = SafeName(pieceTitle.Text) + ".ly", OverwritePrompt = true };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        await File.WriteAllTextAsync(dialog.FileName, source, new UTF8Encoding(false));
        SetStatus("LilyPond-Quelltext gespeichert.");
    }
    void OpenHacklily()
    {
        if (Current == null) throw new InvalidOperationException("Kein Stück geladen.");
        string source = ExtractLilyPond(Current["concept"]?.GetValue<string>() ?? "");
        // Clipboard handoff avoids browser/shell length limits for complete compositions.
        Clipboard.SetText(source);
        Process.Start(new ProcessStartInfo("https://www.hacklily.org/wasm") { UseShellExecute = true });
        SetStatus("Hacklily geöffnet; der LilyPond-Code liegt in der Zwischenablage. Im Editor Strg+A, dann Strg+V.");
        MessageBox.Show(this, "Der vollständige LilyPond-Quelltext liegt in der Zwischenablage.\n\nIn Hacklily links in den Code-Editor klicken, Strg+A und anschließend Strg+V drücken.", "An Hacklily übergeben", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    async Task SaveDocumentAsync()
    {
        if (Current == null) throw new InvalidOperationException("Kein Stück geladen.");
        using var dialog = new SaveFileDialog { Filter = "Composition Lab Stück|*.clab", FileName = SafeName(pieceTitle.Text) + ".clab", OverwritePrompt = true };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = Current.DeepClone() });
        AtomicFile.WriteText(dialog.FileName, Current.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
        currentPath = dialog.FileName; SetStatus("Stück gespeichert.");
    }
    async Task ExportAsync(string extension)
    {
        if (Score == null) throw new InvalidOperationException("Kein Stück geladen.");
        using var dialog = new SaveFileDialog { Filter = extension == "mid" ? "MIDI|*.mid" : "MusicXML|*.musicxml",
            FileName = SafeName(pieceTitle.Text) + "." + extension, OverwritePrompt = true };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        var result = await core.RunAsync(new JsonObject { ["operation"] = extension == "mid" ? "midi" : "musicxml", ["score"] = Score.DeepClone(), ["options"] = extension == "mid" ? null : notationOptions?.DeepClone() });
        AtomicFile.WriteBytes(dialog.FileName, Convert.FromBase64String(result["data"]!.GetValue<string>()));
        SetStatus("Export gespeichert.");
    }
    void SaveDiagnostic()
    {
        if (lastDiagnostic == null) throw new InvalidOperationException("Noch keine Diagnose vorhanden.");
        using var dialog = new SaveFileDialog { Filter = "Diagnose|*.json", FileName = "Composition-Lab-Windows-Diagnose.json", OverwritePrompt = true };
        if (dialog.ShowDialog(this) == DialogResult.OK) AtomicFile.WriteText(dialog.FileName, diagnostic.Text);
    }
    void UpdateDiagnostic() => diagnostic.Text = lastDiagnostic?.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) ?? "";

    async Task InitializeNotationAsync()
    {
        try
        {
            var environment = await CoreWebView2Environment.CreateAsync(userDataFolder: Path.Combine(dataDirectory, "WebView2"));
            await web.EnsureCoreWebView2Async(environment);
            webReady = true; web.CoreWebView2.WebMessageReceived += (_, e) => { try { var message = JsonNode.Parse(e.WebMessageAsJson)!; previewPage.Text = "Seite " + message["page"] + " / " + message["count"]; previewZoom.Text = message["zoom"] + " %"; } catch (JsonException) { } }; web.CoreWebView2.Settings.AreDevToolsEnabled = false;
            web.CoreWebView2.Settings.IsStatusBarEnabled = false;
            web.CoreWebView2.NewWindowRequested += (_, e) => e.Handled = true;
            RenderNotation();
        }
        catch (Exception e)
        {
            web.Visible = false;
            notationHost.Controls.Add(new Label { Dock = DockStyle.Fill, Padding = new Padding(20), Text =
                "Die eingebettete Notenanzeige ist nicht verfügbar. MIDI-Wiedergabe und MusicXML-Export funktionieren unabhängig davon.\n\n" +
                "Installiere Microsoft Edge WebView2 Runtime und starte die App neu.\n\n" + e.Message });
        }
    }
    void RenderNotation()
    {
        if (!webReady) return;
        var xml = JsonSerializer.Serialize(currentXML ?? "");
        var html = """
            <!doctype html><html><head><meta charset="utf-8"><style>
            body{font:13px Segoe UI,sans-serif;margin:10px;background:white;color:#222} svg{display:block;max-width:100%;height:auto}button{padding:5px 12px;margin-right:8px}
            </style></head><body><div><span id="msg">Notensatz wird geladen …</span></div><div id="score"></div>
            <script>let toolkit,scale=40,currentPage=1;const xml=XML_VALUE;
            function render(){if(!xml){document.getElementById('msg').textContent='Kein Stück geladen.';return}try{toolkit.setOptions({scale:scale,pageWidth:1700,pageHeight:2400,adjustPageHeight:true});toolkit.loadData(xml);currentPage=Math.max(1,Math.min(currentPage,toolkit.getPageCount()));document.getElementById('score').innerHTML=toolkit.renderToSVG(currentPage);document.getElementById('msg').textContent='';window.chrome.webview.postMessage({page:currentPage,count:toolkit.getPageCount(),zoom:Math.round(scale/40*100)})}catch(e){document.getElementById('msg').textContent='Notensatz: '+e.message}}
            function page(delta){currentPage+=delta;if(toolkit)render()}
            function zoom(delta){scale=Math.max(20,Math.min(100,scale+delta*0.4));if(toolkit)render()}
            function ready(){toolkit=new verovio.toolkit();render()}
            const script=document.createElement('script');script.src='https://www.verovio.org/javascript/latest/verovio-toolkit-wasm.js';script.onload=()=>{if(verovio.module.calledRun||verovio.module.runtimeInitialized)ready();else verovio.module.onRuntimeInitialized=ready};script.onerror=()=>document.getElementById('msg').textContent='Verovio konnte nicht geladen werden. Internetverbindung prüfen.';document.head.appendChild(script);
            </script></body></html>
            """;
        // JSON serialization escapes < as \u003C, including an embedded </script>.
        web.NavigateToString(html.Replace("XML_VALUE", xml));
    }

    void LoadLocalState()
    {
        loadingSettings = true;
        try
        {
            keys = secrets.Load();
            string path = Path.Combine(dataDirectory, "workspace.json");
            if (File.Exists(path))
            {
                var state = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
                if (state["slots"] is JsonArray list)
                    for (int i = 0; i < Math.Min(10, list.Count); i++) documents[i] = list[i]?.DeepClone().AsObject();
                chat.Text = state["chat"]?.GetValue<string>() ?? "";
                lastDiagnostic = state["diagnostic"]?.DeepClone().AsObject(); UpdateDiagnostic();
                if (state["models"] is JsonObject savedModels)
                    foreach (var pair in savedModels) if (models.ContainsKey(pair.Key)) models[pair.Key] = pair.Value?.GetValue<string>() ?? models[pair.Key];
                activeProvider = state["provider"]?.GetValue<string>() ?? "anthropic";
                if (!models.ContainsKey(activeProvider)) activeProvider = "anthropic";
                editableIdea = state["editableIdea"]?.GetValue<string>() ?? ""; loadingIdea = true; composition.Text = editableIdea; loadingIdea = false;
                mainSplitRatio = Math.Clamp(state["mainSplitRatio"]?.GetValue<double>() ?? .5, .15, .85); ArrangeMainSplit();
                meter.Text = state["meter"]?.GetValue<string>() ?? "";
                if (state["history"] is JsonArray savedHistory) foreach (var item in savedHistory.OfType<JsonObject>()) pieceHistory.Add(item.DeepClone().AsObject()); RefreshHistory();
                projectName = state["projectName"]?.GetValue<string>() ?? "Unbenannt";
                if (state["notation"] is JsonArray notationState && notationState.Count == 9) { updatingNotation = true; for (int i = 0; i < 9; i++) notationSettings[i].SelectedIndex = Math.Clamp(notationState[i]!.GetValue<int>(), 0, notationSettings[i].Items.Count - 1); splitBeats.Checked = state["splitBeats"]?.GetValue<bool>() ?? true; updatingNotation = false; notationOptions = BuildNotationOptions(); }
                assignment.Text = state["assignment"]?.GetValue<string>() ?? assignment.Text;
                measures.Text = state["measures"]?.GetValue<string>() ?? "";
                tempo.Text = state["tempo"]?.GetValue<string>() ?? "";
                musicalKey.Text = state["key"]?.GetValue<string>() ?? "";
                ensemble.Text = state["ensemble"]?.GetValue<string>() ?? "Klavier";
            }
        }
        catch (Exception e) { SetStatus("Gespeicherter Stand konnte nicht geladen werden: " + e.Message, true); }
        finally
        {
            provider.SelectedIndex = activeProvider switch { "openai" => 2, "gemini" => 0, _ => 1 };
            SelectModel(); apiKey.Text = keys.GetValueOrDefault(activeProvider, "");
            remember.Checked = keys.ContainsKey(activeProvider); loadingSettings = false;
        }
    }
    void SaveLocalState()
    {
        if (loadingSettings) return;
        try
        {
            models[activeProvider] = SelectedModelId;
            var state = new JsonObject { ["format"] = "composition-lab-windows-workspace", ["version"] = 1,
                ["slots"] = new JsonArray(documents.Select(d => d?.DeepClone()).ToArray()), ["chat"] = chat.Text,
                ["diagnostic"] = lastDiagnostic?.DeepClone(), ["provider"] = activeProvider,
                ["models"] = JsonSerializer.SerializeToNode(models), ["assignment"] = assignment.Text,
                ["mainSplitRatio"] = mainSplitRatio, ["editableIdea"] = editableIdea, ["meter"] = meter.Text, ["projectName"] = projectName, ["history"] = new JsonArray(pieceHistory.Select(d => d.DeepClone()).ToArray()), ["notation"] = new JsonArray(notationSettings.Select(c => (JsonNode?)JsonValue.Create(c.SelectedIndex)).ToArray()), ["splitBeats"] = splitBeats.Checked,
                ["measures"] = measures.Text, ["tempo"] = tempo.Text, ["key"] = musicalKey.Text, ["ensemble"] = ensemble.Text };
            AtomicFile.WriteText(Path.Combine(dataDirectory, "workspace.json"), state.ToJsonString());
        }
        catch (Exception e) { SetStatus("Speichern fehlgeschlagen: " + e.Message, true); }
    }
    void SetStatus(string text, bool error = false) { status.Text = text; status.ForeColor = error ? Color.DarkRed : Color.Black; }
    static string FormatTime(int ms) => TimeSpan.FromMilliseconds(ms).ToString(@"mm\:ss");
    static string SafeName(string title) => string.Concat(title.Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '_' : c));
    static string RepairLegacyText(string text)
    {
        if (!text.Contains("Ã") && !text.Contains("â€") && !text.Contains("Â")) return text;
        try
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
            var legacy = Encoding.GetEncoding(1252, EncoderFallback.ExceptionFallback, DecoderFallback.ExceptionFallback);
            return new UTF8Encoding(false, true).GetString(legacy.GetBytes(text));
        }
        catch (ArgumentException) { return text; }
    }

    public async Task<string> RunSelfTestAsync(string output)
    {
        Directory.CreateDirectory(output);
        const string probe = "ÄÖÜ äöü ß – musikalischer Dialog";
        var version = await core.RunAsync(new JsonObject { ["operation"] = "version", ["title"] = probe });
        if (version["titleEcho"]?.GetValue<string>() != probe) throw new Exception("UTF-8-Prozesskommunikation beschädigt.");
        if (version["version"]?.GetValue<string>() != "4.0.0-alpha.8") throw new Exception("Falscher Kern.");
        var fixture = JsonNode.Parse("""{"ti":"Windows Starttest","bpm":96,"ts":{"n":4,"d":4},"k":"C major","sm":"","tr":[{"nm":"Piano","ch":0,"pg":0,"nt":[[0,1,60,80,0,1],[1,1,64,80,0,1],[2,2,67,80,0,1]]}]}""")!.AsObject();
        documents[0] = CreateDocument(fixture, "Automatischer Test ohne KI-Kosten."); RefreshSlots();
        await DisplayCurrentAsync();
        if (currentMidi == null || currentXML == null || !currentXML.Contains("score-partwise")) throw new Exception("Export fehlgeschlagen.");
        var round = await core.RunAsync(new JsonObject { ["operation"] = "import-midi", ["data"] = Convert.ToBase64String(currentMidi), ["title"] = "Test" });
        if (round["score"]?["tr"]?[0]?["nt"]?.AsArray().Count != 3) throw new Exception("MIDI-Rückimport fehlgeschlagen.");
        await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = Current!.DeepClone() });
        string clab = Path.Combine(output, "Windows-Starttest.clab"); AtomicFile.WriteText(clab, Current!.ToJsonString());
        await ImportPathAsync(clab);
        // Explicit imports replace only their requested slot; deletion leaves neighbours intact.
        var neighbour = documents[0]!.ToJsonString();
        await ImportIntoSlotAsync(clab, 7);
        if (documents[7] == null || documents[0]!.ToJsonString() != neighbour) throw new Exception("Gezielter Slotimport fehlgeschlagen.");
        string invalid = Path.Combine(output, "invalid.clab"); AtomicFile.WriteText(invalid, "{}");
        var before = documents[7]!.ToJsonString();
        bool rejected = false;
        try { await ImportIntoSlotAsync(invalid, 7); }
        catch (Exception e) when (e is InvalidOperationException or CoreRequestException) { rejected = true; }
        if (!rejected) throw new Exception("Ungültiger Import akzeptiert.");
        if (documents[7]!.ToJsonString() != before) throw new Exception("Fehlgeschlagener Import überschreibt das Stück.");
        await DeleteSlotAsync(7);
        if (documents[7] != null || documents[0]!.ToJsonString() != neighbour) throw new Exception("Einzellöschung fehlgeschlagen.");
        const string lily = "\\version \"2.24.0\"\n\\score { { c'4 d' e' f' } }";
        var extracted = ExtractLilyPond("Einleitung\n```lilypond\n" + lily + "\n```\nNachwort");
        if (extracted != lily + "\n") throw new Exception("LilyPond-Code verändert.");
        string lyPath = Path.Combine(output, "Windows-Starttest.ly"); await File.WriteAllTextAsync(lyPath, extracted, new UTF8Encoding(false));
        Clipboard.SetText(extracted);
        if (Clipboard.GetText() != extracted) throw new Exception("Hacklily-Zwischenablage beschädigt.");
        if (await File.ReadAllTextAsync(lyPath) != extracted) throw new Exception("LilyPond-Export beschädigt.");
        try { ExtractLilyPond("Import: test.mid"); throw new Exception("Import fälschlich als LilyPond erkannt."); } catch (InvalidOperationException) { }
        var recoveryScore = JsonNode.Parse("""{"ti":"Format-Rettung","bpm":96,"ts":{"n":4,"d":4},"k":"C major","sm":"","tr":[{"nm":"Piano","ch":0,"pg":0,"nt":[[0,1,60,80,1,1],[1,1,64,80,1,1],[2,2,67,80,1,1]],"ev":[{"t":"slur","staff":1,"ranges":[[0,4]]},{"b":0,"t":"dynamic","staff":1,"v":"p"},{"b":0,"t":"tempo","qpm":96,"text":"Mäßig"}]}]}""")!;
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        const string recoveredText = "Für Klavier – vollständiges Stück";
        var oldEncodingText = Encoding.GetEncoding(1252).GetString(Encoding.UTF8.GetBytes(recoveredText));
        string recoveryFile = Path.Combine(output, "Diagnose-Starttest.json");
        AtomicFile.WriteText(recoveryFile, new JsonObject { ["scoreResponse"] = recoveryScore.ToJsonString(),
            ["composition"] = oldEncodingText, ["assignment"] = "Test", ["estimatedCostUSD"] = 0.1 }.ToJsonString());
        await ImportPathAsync(recoveryFile);
        if (Current?["concept"]?.GetValue<string>() != recoveredText) throw new Exception("Ältere Diagnose nicht korrekt gerettet.");
        keys["anthropic"] = "SELF-TEST-NO-REAL-KEY"; secrets.Save(keys);
        if (secrets.Load()["anthropic"] != "SELF-TEST-NO-REAL-KEY") throw new Exception("DPAPI-Rückprüfung fehlgeschlagen.");
        if (Encoding.UTF8.GetString(File.ReadAllBytes(Path.Combine(dataDirectory, "keys.dpapi"))).Contains("SELF-TEST-NO-REAL-KEY")) throw new Exception("Unverschlüsselter Schlüssel.");
        SaveLocalState();
        if (File.ReadAllText(Path.Combine(dataDirectory, "workspace.json")).Contains("SELF-TEST-NO-REAL-KEY")) throw new Exception("Schlüssel in Projektdatei.");
        bool midiDevice = false; string playbackInfo = "";
        try { player.Load(currentMidi); player.Play(); await Task.Delay(500); midiDevice = player.Position > 0; playbackInfo = midiDevice ? "Sequencer läuft; hörbarer Klang nicht automatisch geprüft." : "Kein Positionsfortschritt."; player.Stop(); }
        catch (Exception e) { playbackInfo = "Runner ohne nutzbaren MIDI-Synthesizer: " + e.Message; }
        // Synthetic demo music for visual QA; no user composition or real API call.
        documents[0] = CreateDocument(fixture.DeepClone().AsObject(), "Elegie im Abendlicht\n\n" + lily, "Ein ruhiges Klavierstück mit einer klaren musikalischen Idee.");
        documents[0]!["title"] = "Elegie im Abendlicht"; documents[0]!["ensemble"] = "Klavier";
        documents[2] = CreateDocument(fixture.DeepClone().AsObject(), lily); documents[2]!["title"] = "Kleine Fuge";
        documents[4] = CreateDocument(fixture.DeepClone().AsObject(), lily); documents[4]!["title"] = "Tanz der Schatten";
        RefreshSlots(); slots.SelectedIndex = 0; await DisplayCurrentAsync();
        chat.Text = "Du: Ein ruhiges Klavierstück mit einer klaren musikalischen Idee.\n\nKI: Stück fertig: Elegie im Abendlicht\n\nDu: Die Melodie soll beim nächsten Abschnitt etwas mehr Raum bekommen.";
        SetStatus("Bereit · alle Windows-Prüfungen bestanden.");
        composition.Text = "Eine ruhige, gesangliche Melodie mit Raum zum Atmen.\n\nDie Begleitung trägt die Linie und entwickelt sich mit ihr. Ein kurzer Kontrast führt zum ursprünglichen Gedanken zurück.";
        string unchangedIdea = composition.Text; slots.SelectedIndex = 2; await DisplayCurrentAsync(); if (composition.Text != unchangedIdea) throw new Exception("Stückwahl verändert die Kompositionsidee."); slots.SelectedIndex = 0; await DisplayCurrentAsync();
        var decimalTempo = fixture.DeepClone().AsObject(); decimalTempo["bpm"] = 81.25; documents[9] = CreateDocument(decimalTempo, "Tempo-Rückprüfung"); RefreshSlots(); slots.SelectedIndex = 9; await DisplayCurrentAsync(); if (currentMidi == null || playerBpm != 81) throw new Exception("Dezimaltempo nicht lesbar.");
        slots.SelectedIndex = 0; await DisplayCurrentAsync();
        var midiBefore = currentMidi!.ToArray(); notationSettings[0].SelectedIndex = 1; await NotationChangedAsync(0);
        if (!midiBefore.SequenceEqual(currentMidi!)) throw new Exception("Notationsprofil verändert MIDI.");
        static IEnumerable<Control> Descendants(Control root)
        {
            foreach (Control child in root.Controls) { yield return child; foreach (var nested in Descendants(child)) yield return nested; }
        }
        float previousScale = 1;
        foreach (float scale in new[] { 1f, 1.25f, 1.5f, 2f })
        {
            // Exercise real WinForms layout with scaled geometry AND font metrics.
            // CI has one 96-DPI monitor, so this explicitly simulates the other monitor scales.
            float ratio = scale / previousScale;
            var fonts = Descendants(this).Prepend(this).ToDictionary(c => c, c => (c.Font.FontFamily, c.Font.Size, c.Font.Style));
            SuspendLayout(); testLayoutScale = scale;
            Scale(new SizeF(ratio, ratio));
            foreach (var entry in fonts) entry.Key.Font = new Font(entry.Value.FontFamily, entry.Value.Size * ratio, entry.Value.Style);
            ResumeLayout(true); previousScale = scale;
        MinimumSize = new Size(640, 480);
        foreach (var size in new[] { new Size(1500, 1100), new Size(1000, 700) })
        {
            Size = size;
            for (int page = 0; page < 3; page++)
            {
                tabs.SelectedIndex = page; PerformLayout();
                if (page == 0)
                {
                    ArrangeMainSplit();
                    if (mainSplit == null || mainSplit.Panel2.Width < Math.Min(LayoutPixels(220), mainSplit.Width / 3)) throw new Exception("Kompositionsidee zu schmal.");
                    var right = mainSplit.Panel2.RectangleToScreen(mainSplit.Panel2.ClientRectangle);
                    var viewport = tabs.RectangleToScreen(tabs.ClientRectangle);
                    if (right.Left < viewport.Left || right.Right > viewport.Right) throw new Exception("Kompositionsidee außerhalb der sichtbaren Fensterbreite.");
                    int previousDistance = mainSplit.SplitterDistance;
                    mainSplit.SplitterDistance = mainSplit.Panel1MinSize;
                    if (mainSplit.SplitterDistance >= previousDistance || mainSplit.Panel2.Width <= 0) throw new Exception("Trennlinie nicht verstellbar.");
                    double savedRatio = mainSplitRatio; SaveLocalState();
                    var saved = JsonNode.Parse(File.ReadAllText(Path.Combine(dataDirectory, "workspace.json")))!;
                    if (Math.Abs(saved["mainSplitRatio"]!.GetValue<double>() - savedRatio) > .001) throw new Exception("Trennlinie nicht gespeichert.");
                    mainSplitRatio = .5; ArrangeMainSplit();
                }
                foreach (var label in Descendants(this).OfType<Label>())
                {
                    if (!label.Visible || !label.AutoSize || label.AutoEllipsis) continue;
                    var required = label.GetPreferredSize(label.MaximumSize.Width > 0 ? new Size(label.MaximumSize.Width, 0) : Size.Empty);
                    if (label.Width < required.Width || label.Height < required.Height)
                        throw new Exception($"Beschriftung abgeschnitten bei {scale * 100}%: {label.Text} / {label.Size} / benötigt {required}");
                }
                foreach (var inputControl in new Control[] { provider, model, effort, measures, meter, tempo, musicalKey, ensemble })
                    if (inputControl.Visible && inputControl.Height < inputControl.Font.Height + inputControl.Padding.Vertical + 4)
                        throw new Exception($"Eingabefeld zu flach bei {scale * 100}%: {inputControl.Name}");
                foreach (var control in slotCards.Cast<Control>().Concat(guiChecks))
                {
                    if (!control.Visible) continue;
                    if (control.Width < 10 || control.Height < 10) throw new Exception("Bedienelement unbedienbar: " + control.Text);
                    for (Control? ancestor = control.Parent; ancestor != null; ancestor = ancestor.Parent)
                    {
                        if (ancestor is ScrollableControl viewport && viewport.AutoScroll) break;
                        if (!ancestor.RectangleToScreen(ancestor.ClientRectangle).Contains(control.RectangleToScreen(control.ClientRectangle)))
                            throw new Exception("Bedienelement außerhalb seines Panels: " + control.Text + " / " + ancestor.GetType().Name + " / " + control.Bounds + " / parent " + ancestor.ClientRectangle);
                    }
                    // Native Mac has a horizontal card deck; Windows also allows the full
                    // fixed layout to scroll when smaller than the original minimum content.
                    for (Control? parent = control.Parent; parent != null; parent = parent.Parent)
                        if (parent is ScrollableControl scroll && scroll.AutoScroll) { scroll.ScrollControlIntoView(control); }
                }
                if (page == 0)
                {
                    for (Control? parent = slotCards[0].Parent; parent != null; parent = parent.Parent) if (parent is ScrollableControl scroll && scroll.AutoScroll) scroll.AutoScrollPosition = Point.Empty;
                }
                using var bitmap = new Bitmap(Width, Height); DrawToBitmap(bitmap, new Rectangle(Point.Empty, Size));
                bitmap.Save(Path.Combine(output, $"DPI-{scale * 100:0}-" + (size.Width == 1500 ? "Windows-" : "Windows-Klein-") + new[] { "Main", "Noten", "Technik" }[page] + ".png"));
            }
        }
        }
        tabs.SelectedIndex = 0;
        return JsonSerializer.Serialize(new { passed = true, version = Version, tests = new[] { "UI start", "UTF-8 process roundtrip", "diagnostic recovery with range events", "legacy text recovery", "bundled core", "MIDI export/import", "MusicXML export", "CLAB save/load", "targeted slot import", "failed import retains piece", "individual slot deletion", "LilyPond source export", "Hacklily clipboard handoff", "DPAPI", "no secrets in workspace", "Mac layout builders and ten 116x164 cards", "editable idea retained on piece changes", "MusicXML settings do not alter MIDI", "fractional imported MIDI tempo", "three Mac workspaces, large/small window with reachable scroll content", "unclipped label and input sizes at simulated 100/125/150/200 percent geometry and font metrics", "visible right pane with movable and persisted splitter at every tested window width and scale" }, midiDevice, playbackInfo }, new JsonSerializerOptions { WriteIndented = true });
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing) { pending?.Cancel(); playbackTimer.Dispose(); player.Dispose(); web.Dispose(); slotTips.Dispose(); }
        base.Dispose(disposing);
    }
}


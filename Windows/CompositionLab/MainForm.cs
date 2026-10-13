using System.Text;
using System.Diagnostics;
using System.Text.RegularExpressions;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace CompositionLab;

internal sealed class MainForm : Form
{
    const string Version = "4.0.0-alpha.4 · Build 4004";
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
    readonly TextBox model = new() { Width = 250 };
    readonly ComboBox effort = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 145 };
    readonly TextBox apiKey = new() { Width = 240, UseSystemPasswordChar = true };
    readonly CheckBox remember = new() { Text = "Schlüssel speichern", AutoSize = true };
    readonly TextBox assignment = new() { Multiline = true, ScrollBars = ScrollBars.Vertical, Dock = DockStyle.Fill };
    readonly RichTextBox chat = new() { Dock = DockStyle.Fill, ReadOnly = true, BackColor = Color.White, DetectUrls = true };
    readonly RichTextBox diagnostic = new() { Dock = DockStyle.Fill, ReadOnly = true, Font = new Font("Consolas", 10) };
    readonly RichTextBox composition = new() { Dock = DockStyle.Fill, ReadOnly = true, BackColor = Color.White };
    readonly TextBox measures = new() { Width = 55 };
    readonly TextBox tempo = new() { Width = 55 };
    readonly TextBox musicalKey = new() { Width = 90 };
    readonly TextBox ensemble = new() { Width = 130, Text = "Klavier" };
    readonly CheckBox useSource = new() { Text = "Aktuelles Stück als Vorlage", AutoSize = true };
    readonly Button compose = new() { Text = "Komponieren", AutoSize = true };
    readonly Button send = new() { Text = "Chat", AutoSize = true };
    readonly Button cancel = new() { Text = "Abbrechen", AutoSize = true, Enabled = false };
    readonly ToolStripStatusLabel status = new() { Text = "Bereit", Spring = true, TextAlign = ContentAlignment.MiddleLeft };
    readonly ToolStripStatusLabel cost = new() { Text = "Kosten: –" };
    readonly Label pieceTitle = new() { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(8), Text = "Kein Stück geladen" };
    readonly Label playback = new() { AutoSize = true, Padding = new Padding(10, 7, 0, 0), Text = "00:00 / 00:00" };
    readonly Panel notationHost = new() { Dock = DockStyle.Fill, BackColor = Color.White };
    readonly WebView2 web = new() { Dock = DockStyle.Fill };
    readonly System.Windows.Forms.Timer playbackTimer = new() { Interval = 300 };
    readonly TabControl tabs = new() { Dock = DockStyle.Fill };
    readonly List<Button> slotCards = [];
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
        this.testMode = testMode;
        dataDirectory = testMode ? Path.Combine(Path.GetTempPath(), "clab-v4-test-" + Guid.NewGuid().ToString("N"))
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Klangwerke", "Composition Lab 4.0");
        secrets = new SecretStore(dataDirectory);
        Text = "Composition Lab Native · Windows · " + Version;
        MinimumSize = new Size(900, 700); Size = new Size(1240, 880);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 9);
        BackColor = Color.FromArgb(245, 246, 248);
        AutoScaleMode = AutoScaleMode.Dpi;
        BuildUI();
        LoadLocalState();
        RefreshSlots();
        slots.SelectedIndex = 0;
        Shown += async (_, _) =>
        {
            if (!testMode) await InitializeNotationAsync();
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
            try { playback.Text = FormatTime(player.Position) + " / " + FormatTime(player.Length); }
            catch (Exception e) { SetStatus(e.Message, true); playbackTimer.Stop(); }
        };
        playbackTimer.Start();
    }

    void BuildUI()
    {
        var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5 };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        Controls.Add(root);
        var files = new MenuStrip { Dock = DockStyle.Fill, BackColor = Color.White };
        MainMenuStrip = files;
        var fileMenu = new ToolStripMenuItem("Datei"); files.Items.Add(fileMenu);
        void FileAction(string title, Func<Task> action) { var item = new ToolStripMenuItem(title); item.Click += async (_, _) => { try { await action(); } catch (Exception e) { SetStatus(e.Message, true); } }; fileMenu.DropDownItems.Add(item); }
        FileAction( "Öffnen / Import", async () => await OpenAsync());
        FileAction( "Stück speichern", async () => await SaveDocumentAsync());
        FileAction( "MIDI exportieren", async () => await ExportAsync("mid"));
        FileAction( "MusicXML exportieren", async () => await ExportAsync("musicxml"));
        FileAction( "Diagnose speichern", () => { SaveDiagnostic(); return Task.CompletedTask; });
        FileAction("LilyPond exportieren …", () => ExportLilyPondAsync());
        FileAction("An Hacklily übergeben", () => { OpenHacklily(); return Task.CompletedTask; });
        root.Controls.Add(files, 0, 0);
        var settings = Row();
        provider.Items.AddRange(["Claude / Anthropic", "OpenAI", "Google / Gemini"]);
        effort.Items.AddRange(["Sparsam", "Standard", "Hoch"]); effort.SelectedIndex = 1;
        Add(settings, "KI", provider); Add(settings, "Modell", model); Add(settings, "Denkaufwand", effort);
        provider.SelectedIndexChanged += (_, _) => ProviderChanged();
        root.Controls.Add(settings, 0, 1);
        var credentials = Row();
        Add(credentials, "API-Schlüssel", apiKey); credentials.Controls.Add(remember);
        AddButton(credentials, "Schlüssel übernehmen", () => { StoreKey(); return Task.CompletedTask; });
        AddButton(credentials, "Gespeicherten Schlüssel löschen", () =>
        { keys.Remove(activeProvider); apiKey.Clear(); remember.Checked = false; secrets.Save(keys); SetStatus("Schlüssel gelöscht."); return Task.CompletedTask; });
        // API keys are on Technik, matching the Mac workspace.
        var work = new SplitContainer { Size = new Size(1180, 650), Dock = DockStyle.Fill, FixedPanel = FixedPanel.Panel1, SplitterDistance = 190, Panel1MinSize = 160, Panel1Collapsed = true };
        var left = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
        left.RowStyles.Add(new RowStyle(SizeType.AutoSize)); left.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        left.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        left.Controls.Add(new Label { Text = "Stück-Slots", AutoSize = true, Padding = new Padding(8) }, 0, 0);
        left.Controls.Add(slots, 0, 1);
        var slotButtons = Row();
        AddButton(slotButtons, "Freier Slot", () => { SelectFreeSlot(); return Task.CompletedTask; });
        left.Controls.Add(slotButtons, 0, 2); work.Panel1.Controls.Add(left);
        var workshop = new TabPage("Main");
        var workshopSplit = new SplitContainer { Size = new Size(950, 450), Dock = DockStyle.Fill, Orientation = Orientation.Vertical, SplitterDistance = 460 };
        var musicChatBox = new GroupBox { Text = "MusicChat", Dock = DockStyle.Fill, Padding = new Padding(10) };
        var compositionBox = new GroupBox { Text = "Aktuelle Komposition", Dock = DockStyle.Fill, Padding = new Padding(10) };
        musicChatBox.Controls.Add(chat); compositionBox.Controls.Add(composition);
        workshopSplit.Panel1.Controls.Add(musicChatBox); workshopSplit.Panel2.Controls.Add(compositionBox);
        workshop.Controls.Add(workshopSplit); tabs.TabPages.Add(workshop);
        var notation = new TabPage("Noten"); notation.Controls.Add(notationHost); notationHost.Controls.Add(web); tabs.TabPages.Add(notation);
        var technology = new TabPage("Technik");
        var technicalLayout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2 };
        technicalLayout.RowStyles.Add(new RowStyle(SizeType.AutoSize)); technicalLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        technicalLayout.Controls.Add(credentials, 0, 0);
        var technicalTabs = new TabControl { Dock = DockStyle.Fill };
        var diagnostics = new TabPage("Diagnose"); diagnostics.Controls.Add(diagnostic); technicalTabs.TabPages.Add(diagnostics);
        technicalLayout.Controls.Add(technicalTabs, 0, 1); technology.Controls.Add(technicalLayout); tabs.TabPages.Add(technology);
        var info = new TabPage("Info");
        info.Controls.Add(new RichTextBox { Dock = DockStyle.Fill, ReadOnly = true, BackColor = Color.White, Text =
            "Composition Lab Native · Windows · " + Version + "\n\n" +
            "Die App verwendet denselben Swift-Kern wie die Mac-Version 4.0.\n\n" +
            "Chat bespricht Musik. Komponieren erzeugt das fertige Stück und überträgt es technisch. " +
            "Ein Modellname kann frei eingegeben werden. Verwende einen Modellnamen, den dein Anbieter für deinen API-Schlüssel freigeschaltet hat.\n\n" +
            "Stücke lassen sich als .clab zwischen Mac und Windows austauschen. MIDI und MusicXML werden im gemeinsamen Kern verarbeitet. " +
            "Alle zehn Slots und der Dialog werden lokal wiederhergestellt. API-Schlüssel werden nur auf Wunsch gespeichert, mit Windows-DPAPI für dein Benutzerkonto verschlüsselt.\n\n" +
            "Die Kostenanzeige verwendet die vorhandene Schätzung des Kerns. Für frei eingegebene Modelle kann sie abweichen. " +
            "Abbrechen beendet die lokale Anfrage; bereits entstandene Anbieter-Kosten können bleiben.\n\n" +
            "Wiedergabe: Windows-General-MIDI über den System-Synthesizer. Noch keine Soundfont-Auswahl und keine direkten MIDI-Geräte. " +
            "Notenanzeige: Verovio; beim ersten Laden ist Internet erforderlich. Zusätzlich wird Microsoft Edge WebView2 Runtime benötigt. " +
            "Ohne Runtime bleiben Komposition, Wiedergabe und Export verwendbar.\n\n" +
            "Diese erste Windows-Alpha ist getrennt von der bisherigen Mac-App. Es gibt keine automatische DAW-Übergabe oder automatische Aktualisierung." });
        technicalTabs.TabPages.Add(info);
        var right = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 6, ColumnCount = 1 };
        right.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        right.RowStyles.Add(new RowStyle(SizeType.AutoSize)); right.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        right.RowStyles.Add(new RowStyle(SizeType.AutoSize)); right.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        right.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        right.RowStyles.Add(new RowStyle(SizeType.Absolute, 112));
        right.Controls.Add(pieceTitle, 0, 0); right.Controls.Add(tabs, 0, 1);
        var deck = new TableLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, ColumnCount = 1, RowCount = 1, Padding = new Padding(6, 4, 6, 4) };
        deck.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        deck.RowStyles.Add(new RowStyle(SizeType.Absolute, 104));
        var cards = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 10, RowCount = 1 };
        cards.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        for (int i = 0; i < 10; i++)
        {
            int index = i; cards.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 10));
            var cell = new Panel { Dock = DockStyle.Fill, Margin = new Padding(3) };
            var card = new Button { Dock = DockStyle.Fill, Font = new Font("Segoe UI", 9), FlatStyle = FlatStyle.Flat, AllowDrop = true, Margin = Padding.Empty };
            card.FlatAppearance.BorderColor = Color.FromArgb(208, 214, 223);
            card.Click += async (_, _) => { if (busy) return; if (documents[index] == null) await GuardAsync(() => OpenAsync(index)); else slots.SelectedIndex = index; };
            card.DragEnter += (_, e) => e.Effect = !busy && e.Data?.GetDataPresent(DataFormats.FileDrop) == true ? DragDropEffects.Copy : DragDropEffects.None;
            card.DragDrop += async (_, e) => { if (!busy && e.Data?.GetData(DataFormats.FileDrop) is string[] paths && paths.Length == 1) await GuardAsync(() => ImportIntoSlotAsync(paths[0], index)); };
            var menu = new ContextMenuStrip();
            menu.Items.Add("Datei in diesen Platz laden …", null, async (_, _) => await GuardAsync(() => OpenAsync(index)));
            menu.Items.Add("Dieses Stück speichern …", null, async (_, _) => { if (busy) return; slots.SelectedIndex = index; await GuardAsync(SaveDocumentAsync); });
            menu.Items.Add("Dieses Stück löschen", null, async (_, _) => await DeleteSlotAsync(index)); card.ContextMenuStrip = menu;
            var tools = new Panel { Dock = DockStyle.Bottom, Height = 28 };
            var load = new Button { Text = "Laden", Dock = DockStyle.Fill, Margin = Padding.Empty, FlatStyle = FlatStyle.Flat, Font = new Font("Segoe UI", 8) };
            var delete = new Button { Text = "×", Dock = DockStyle.Right, Width = 28, Margin = Padding.Empty, FlatStyle = FlatStyle.Flat };
            load.Click += async (_, _) => await GuardAsync(() => OpenAsync(index)); delete.Click += async (_, _) => await DeleteSlotAsync(index);
            slotTips.SetToolTip(delete, "Stück " + (index + 1) + " löschen"); slotTips.SetToolTip(load, "Datei in Stück " + (index + 1) + " laden");
            tools.Controls.Add(load); tools.Controls.Add(delete); cell.Controls.Add(card); cell.Controls.Add(tools);
            slotActions.Add(load); slotActions.Add(delete);
            slotCards.Add(card); cards.Controls.Add(cell, i, 0);
        }
        deck.Controls.Add(cards, 0, 0); right.Controls.Add(deck, 0, 2);
        var play = Row();
        AddButton(play, "▶ Abspielen", async () =>
        { if (currentMidi == null) throw new InvalidOperationException("Kein Stück geladen."); if (!player.Loaded) player.Load(currentMidi); player.Play(); await Task.CompletedTask; });
        AddButton(play, "Pause", () => { player.Pause(); return Task.CompletedTask; });
        AddButton(play, "Stopp", () => { player.Stop(); return Task.CompletedTask; }); play.Controls.Add(playback);
        AddButton(play, "LilyPond …", ExportLilyPondAsync);
        AddButton(play, "Hacklily ↗", () => { OpenHacklily(); return Task.CompletedTask; });
        right.Controls.Add(play, 0, 3);
        var musicalSettings = Row();
        Add(musicalSettings, "Takte", measures); Add(musicalSettings, "BPM", tempo);
        Add(musicalSettings, "Tonart", musicalKey); Add(musicalSettings, "Besetzung", ensemble);
        right.Controls.Add(musicalSettings, 0, 4);
        var inputPanel = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1 };
        inputPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); inputPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        inputPanel.Controls.Add(assignment, 0, 0);
        var actions = Row(); actions.Controls.Add(useSource); actions.Controls.Add(send); actions.Controls.Add(compose); actions.Controls.Add(cancel);
        send.Click += async (_, _) => await RequestAIAsync(false);
        compose.Click += async (_, _) => await RequestAIAsync(true);
        cancel.Click += (_, _) => pending?.Cancel();
        inputPanel.Controls.Add(actions, 0, 1); right.Controls.Add(inputPanel, 0, 5);
        work.Panel2.Controls.Add(right); root.Controls.Add(work, 0, 3);
        var strip = new StatusStrip(); strip.Items.Add(status); strip.Items.Add(cost); root.Controls.Add(strip, 0, 4);
        slots.SelectedIndexChanged += async (_, _) => { RefreshCards(); await DisplayCurrentAsync(); };
        assignment.Text = "Komponiere ein eigenständiges Klavierstück mit einer tragenden musikalischen Idee.";
    }

    static FlowLayoutPanel Row() => new() { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true, Padding = new Padding(4, 2, 4, 2) };
    static void Add(Control row, string label, Control field)
    { row.Controls.Add(new Label { Text = label, AutoSize = true, Padding = new Padding(5, 7, 0, 0) }); row.Controls.Add(field); }
    void AddButton(Control row, string title, Func<Task> action)
    {
        var button = new Button { Text = title, AutoSize = true };
        button.Click += async (_, _) => { try { await action(); } catch (Exception e) { SetStatus(e.Message, true); } };
        row.Controls.Add(button);
    }

    void ProviderChanged()
    {
        if (loadingSettings) return;
        models[activeProvider] = model.Text;
        activeProvider = provider.SelectedIndex switch { 1 => "openai", 2 => "gemini", _ => "anthropic" };
        model.Text = models[activeProvider];
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
        if (string.IsNullOrWhiteSpace(assignment.Text)) { SetStatus("Bitte einen Auftrag eingeben.", true); return; }
        if (string.IsNullOrWhiteSpace(apiKey.Text)) { SetStatus("Bitte API-Schlüssel eingeben.", true); return; }
        int destination = -1;
        if (makeMusic)
        {
            destination = Current == null ? slots.SelectedIndex : Array.FindIndex(documents, d => d == null);
            if (destination < 0) { SetStatus("Alle zehn Slots sind belegt. Bitte zuerst ein Stück speichern und einen Slot leeren.", true); return; }
        }
        string userText = assignment.Text.Trim();
        string instruction = userText;
        if (makeMusic)
        {
            if (!string.IsNullOrWhiteSpace(measures.Text)) instruction += "\nTaktanzahl: " + measures.Text;
            if (!string.IsNullOrWhiteSpace(tempo.Text)) instruction += "\nTempo (BPM): " + tempo.Text;
            if (!string.IsNullOrWhiteSpace(musicalKey.Text)) instruction += "\nTonart: " + musicalKey.Text;
            if (!string.IsNullOrWhiteSpace(ensemble.Text)) instruction += "\nBesetzung: " + ensemble.Text;
        }
        else if (!string.IsNullOrEmpty(chat.Text)) instruction = "Bisheriger musikalischer Dialog:\n" +
                (chat.Text.Length > 16000 ? chat.Text[^16000..] : chat.Text) + "\n\nAktuelle Nachricht:\n" + instruction;
        if (useSource.Checked && Score != null) instruction += "\nBewusst gewählte musikalische Vorlage:\n" + Score.ToJsonString();
        var request = new JsonObject { ["assignment"] = instruction, ["provider"] = activeProvider,
            ["model"] = model.Text.Trim(), ["effort"] = effort.SelectedIndex switch { 0 => "low", 2 => "high", _ => "medium" } };
        string selectedProvider = activeProvider, selectedModel = model.Text.Trim();
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
                documents[destination] = document; RefreshSlots(); slots.SelectedIndex = destination;
                await DisplayCurrentAsync();
                chat.AppendText("KI: Stück fertig: " + document["title"]?.GetValue<string>() + "\n\n");
            }
            else chat.AppendText("KI: " + result["text"]!.GetValue<string>() + "\n\n");
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
        ["concept"] = concept, ["measures"] = measures.Text, ["meter"] = "",
        ["tempo"] = tempo.Text, ["musicalKey"] = musicalKey.Text, ["ensemble"] = ensemble.Text,
        ["assignment"] = userAssignment
    };

    async Task DisplayCurrentAsync()
    {
        int generation = ++displayGeneration;
        player.Close(); currentMidi = null; currentXML = null; currentPath = null;
        var document = Current;
        playback.Text = "00:00 / 00:00";
        if (document == null) { cost.Text = "Kosten: –"; pieceTitle.Text = "Freier Stück-Slot"; composition.Clear(); if (webReady) web.NavigateToString("<html><body>Kein Stück geladen.</body></html>"); return; }
        pieceTitle.Text = document["title"]?.GetValue<string>() ?? "Komposition";
        composition.Text = document["concept"]?.GetValue<string>() ?? "";
        try
        {
            var score = document["score"]!.DeepClone();
            var midi = await core.RunAsync(new JsonObject { ["operation"] = "midi", ["score"] = score });
            var xml = await core.RunAsync(new JsonObject { ["operation"] = "musicxml", ["score"] = score.DeepClone() });
            if (generation != displayGeneration) return;
            currentMidi = Convert.FromBase64String(midi["data"]!.GetValue<string>());
            currentXML = Encoding.UTF8.GetString(Convert.FromBase64String(xml["data"]!.GetValue<string>()));
            if (webReady) RenderNotation();
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
        for (int i = 0; i < slotCards.Count; i++) { var title = documents[i]?["title"]?.GetValue<string>() ?? "frei";
            slotCards[i].Text = (i + 1) + "\n" + (title.Length > 12 ? title[..11] + "…" : title);
            slotCards[i].BackColor = i == slots.SelectedIndex ? Color.FromArgb(213, 229, 249) : Color.White;
            slotTips.SetToolTip(slotCards[i], title + "\nKlick: auswählen / freien Platz laden. Rechtsklick: laden, speichern, löschen. Dateidrop möglich."); }
    }
    void SelectFreeSlot()
    { int free = Array.FindIndex(documents, d => d == null); if (free < 0) SetStatus("Alle Slots belegt.", true); else slots.SelectedIndex = free; }

    async Task OpenAsync(int? destination = null)
    {
        if (busy) return;
        using var dialog = new OpenFileDialog { Filter = "Musikdateien und Diagnosen|*.clab;*.mid;*.midi;*.musicxml;*.xml;*.json|Alle Dateien|*.*" };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        if (destination.HasValue) await ImportIntoSlotAsync(dialog.FileName, destination.Value);
        else await ImportPathAsync(dialog.FileName);
    }
    async Task ImportPathAsync(string path, int? targetSlot = null)
    {
        int destination = targetSlot ?? (Current == null ? slots.SelectedIndex : Array.FindIndex(documents, d => d == null));
        if (destination < 0) throw new InvalidOperationException("Alle Slots belegt. Bitte einen Slot freimachen.");
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
        documents[destination] = document; RefreshSlots(); slots.SelectedIndex = destination;
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
        var result = await core.RunAsync(new JsonObject { ["operation"] = extension == "mid" ? "midi" : "musicxml", ["score"] = Score.DeepClone() });
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
            webReady = true; web.CoreWebView2.Settings.AreDevToolsEnabled = false;
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
            body{font:15px Segoe UI,sans-serif;margin:20px;background:white;color:#222} svg{display:block;max-width:100%;height:auto}button{padding:5px 12px;margin-right:8px}
            </style></head><body><div><button onclick="zoom(-10)">−</button><button onclick="zoom(10)">+</button><span id="msg">Notensatz wird geladen …</span></div><div id="score"></div>
            <script>let toolkit,scale=40;const xml=XML_VALUE;
            function render(){if(!xml){document.getElementById('msg').textContent='Kein Stück geladen.';return}try{toolkit.setOptions({scale:scale,pageWidth:1700,pageHeight:2400,adjustPageHeight:true});toolkit.loadData(xml);let html='';for(let p=1;p<=toolkit.getPageCount();p++)html+=toolkit.renderToSVG(p);document.getElementById('score').innerHTML=html;document.getElementById('msg').textContent=toolkit.getPageCount()+' Seiten'}catch(e){document.getElementById('msg').textContent='Notensatz: '+e.message}}
            function zoom(delta){scale=Math.max(20,Math.min(100,scale+delta));if(toolkit)render()}
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
            provider.SelectedIndex = activeProvider switch { "openai" => 1, "gemini" => 2, _ => 0 };
            model.Text = models[activeProvider]; apiKey.Text = keys.GetValueOrDefault(activeProvider, "");
            remember.Checked = keys.ContainsKey(activeProvider); loadingSettings = false;
        }
    }
    void SaveLocalState()
    {
        if (loadingSettings) return;
        try
        {
            models[activeProvider] = model.Text;
            var state = new JsonObject { ["format"] = "composition-lab-windows-workspace", ["version"] = 1,
                ["slots"] = new JsonArray(documents.Select(d => d?.DeepClone()).ToArray()), ["chat"] = chat.Text,
                ["diagnostic"] = lastDiagnostic?.DeepClone(), ["provider"] = activeProvider,
                ["models"] = JsonSerializer.SerializeToNode(models), ["assignment"] = assignment.Text,
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
        if (version["version"]?.GetValue<string>() != "4.0.0-alpha.4") throw new Exception("Falscher Kern.");
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
        chat.Text = "Automatischer Windows-Test: Kern gestartet, Stück geladen, Exporte und Schlüsselablage geprüft.";
        tabs.SelectedIndex = 0; SetStatus("Automatischer Test bestanden.");
        PerformLayout();
        var screenBounds = RectangleToScreen(ClientRectangle);
        foreach (var control in slotCards.Concat(slotActions).Cast<Control>().Concat(new Control[] { ensemble, composition, compose }))
            if (control.Visible && (!screenBounds.Contains(control.RectangleToScreen(control.ClientRectangle)) ||
                (control.Parent != null && !control.Parent.RectangleToScreen(control.Parent.ClientRectangle).Contains(control.RectangleToScreen(control.ClientRectangle)))))
                throw new Exception("Bedienelement liegt außerhalb des sichtbaren Fensters: " + control.Text + " / " + control.RectangleToScreen(control.ClientRectangle) + " / Fenster " + screenBounds);
        using var bitmap = new Bitmap(Width, Height); DrawToBitmap(bitmap, new Rectangle(Point.Empty, Size));
        bitmap.Save(Path.Combine(output, "Windows-Starttest.png"));
        return JsonSerializer.Serialize(new { passed = true, version = Version, tests = new[] { "UI start", "UTF-8 process roundtrip", "diagnostic recovery with range events", "legacy text recovery", "bundled core", "MIDI export/import", "MusicXML export", "CLAB save/load", "targeted slot import", "failed import retains piece", "individual slot deletion", "LilyPond source export", "Hacklily clipboard handoff", "DPAPI", "no secrets in workspace" }, midiDevice, playbackInfo }, new JsonSerializerOptions { WriteIndented = true });
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing) { pending?.Cancel(); playbackTimer.Dispose(); player.Dispose(); web.Dispose(); slotTips.Dispose(); }
        base.Dispose(disposing);
    }
}


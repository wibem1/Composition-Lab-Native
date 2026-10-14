using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CompositionLab;

// Layout port of Sources/MainViewController.swift (main a2aefd7).
// Each builder mirrors the corresponding build* function instead of redesigning it.
internal sealed partial class MainForm
{
    sealed record ModelChoice(string Id, string Label) { public override string ToString() => Label; }
    string SelectedModelId => (model.SelectedItem as ModelChoice)?.Id ?? model.Text;
    void SelectModel()
    {
        var values = activeProvider switch { "gemini" => new[] { new ModelChoice("gemini-3.7-flash", "Gemini 3.7 Flash") }, "openai" => new[] { new ModelChoice("gpt-5.6-sol", "GPT-5.6 Sol"), new ModelChoice("gpt-5.6-terra", "GPT-5.6 Terra"), new ModelChoice("gpt-5.6-luna", "GPT-5.6 Luna") }, _ => new[] { new ModelChoice("claude-sonnet-5", "Claude Sonnet 5") } };
        string selected = models[activeProvider]; model.Items.Clear(); model.Items.AddRange(values);
        var choice = values.FirstOrDefault(v => v.Id == selected); if (choice == null) { choice = new ModelChoice(selected, selected); model.Items.Add(choice); } model.SelectedItem = choice;
    }
    readonly TextBox chatInput = new() { PlaceholderText = "Kompositionsauftrag, Frage oder Änderungswunsch …" };
    readonly TextBox meter = new() { Width = 54, PlaceholderText = "4/4" };
    readonly List<StudioButton> notationCards = [];
    readonly List<Control> guiChecks = [];
    readonly RichTextBox validation = new() { ReadOnly = true, Dock = DockStyle.Fill };
    readonly RichTextBox scoreJSON = new() { ReadOnly = true, Dock = DockStyle.Fill, Font = new Font("Consolas", 9) };
    readonly ListBox historyList = new() { Dock = DockStyle.Fill, IntegralHeight = false };
    readonly List<JsonObject> pieceHistory = [];
    readonly List<Transport> transports = [];
    readonly ComboBox[] notationSettings = Enumerable.Range(0, 9).Select(_ => new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList }).ToArray();
    readonly CheckBox splitBeats = new() { Text = "Zusammengesetzte Notenwerte an Zählzeiten teilen und binden", Checked = true, AutoSize = true, MaximumSize = new Size(264, 0) };
    readonly Label notationSummary = new() { Dock = DockStyle.Fill, AutoSize = true };
    JsonObject? notationOptions;
    bool updatingNotation;
    string projectName = "Unbenannt";
    string editableIdea = "";
    bool loadingIdea;
    bool loopPlaying;
    bool seekUpdating;
    int playerBpm;
    int playerVolume = 90;
    sealed class Transport
    {
        public readonly Label Time = new() { AutoSize = true, Text = "0:00 / 0:00", Padding = new Padding(0, 6, 0, 0) };
        public readonly TrackBar Position = new() { Width = 260, Height = 26, Maximum = 1000, TickStyle = TickStyle.None, AutoSize = false };
        public readonly CheckBox Loop = new() { Text = "Loop", Appearance = Appearance.Button, AutoSize = true };
        public readonly TextBox Tempo = new() { Width = 50 };
        public readonly TrackBar Volume = new() { Width = 130, Height = 26, Maximum = 100, Value = 90, TickStyle = TickStyle.None, AutoSize = false };
    }
    static Font MacFont(float points, FontStyle style = FontStyle.Regular) => new("Segoe UI", points * .75f, style);
    static Label MacLabel(string text, float size = 12, bool bold = false) => new() { Text = text, AutoSize = true, Font = MacFont(size, bold ? FontStyle.Bold : FontStyle.Regular), ForeColor = StudioTheme.Ink, Margin = new Padding(0, 5, 7, 0) };
    static StudioSurface MacPanel() => new() { Dock = DockStyle.Fill, Padding = new Padding(14, 12, 14, 12), Margin = Padding.Empty };
    static FlowLayoutPanel MacRow(bool wrap = false) => new() { Dock = DockStyle.Fill, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, WrapContents = wrap, Margin = Padding.Empty, Padding = Padding.Empty };
    void BuildMacUI()
    {
        var root = Grid(1, 4); root.RowStyles.Add(new RowStyle(SizeType.AutoSize)); root.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); root.RowStyles.Add(new RowStyle(SizeType.Absolute, 28)); Controls.Add(root);
        root.Controls.Add(BuildMacMenus(), 0, 0);
        var header = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(233, 233, 233), Margin = Padding.Empty };
        var project = MacLabel("Composition Lab · Composition Engine 2.3.1 · Build 231", 15, true); project.Location = new Point(16, 18); header.Controls.Add(project);
        var navigation = MacRow(); navigation.Dock = DockStyle.None; navigation.Size = new Size(390, 30); navigation.WrapContents = false;
        foreach (string label in new[] { "Main", "Noten", "Technik" })
        { int index = navButtons.Count; var button = new StudioButton { Text = label, Width = 126, Height = 28, AutoSize = false, Selected = index == 0 }; button.Click += (_, _) => tabs.SelectedIndex = index; navButtons.Add(button); navigation.Controls.Add(button); }
        header.Controls.Add(navigation); header.Resize += (_, _) => navigation.Location = new Point((header.Width - navigation.Width) / 2, 11);
        // Mac centers the segmented control; a narrow Windows viewport may need horizontal scrolling.
        header.AutoScroll = true; header.AutoScrollMinSize = new Size(1160, 0);
        tabs.SelectedIndexChanged += (_, _) => { for (int i = 0; i < 3; i++) { navButtons[i].Selected = tabs.SelectedIndex == i; navButtons[i].Invalidate(); } };
        root.Controls.Add(header, 0, 1);
        tabs.AddPage(BuildMacMain()); tabs.AddPage(BuildMacNotation()); tabs.AddPage(BuildMacTechnology()); root.Controls.Add(tabs, 0, 2);
        var strip = new StatusStrip { Dock = DockStyle.Fill, BackColor = Color.FromArgb(233, 233, 233), SizingGrip = true }; strip.Items.Add(status); strip.Items.Add(cost); root.Controls.Add(strip, 0, 3);
        slots.SelectedIndexChanged += async (_, _) => { RefreshCards(); await DisplayCurrentAsync(); };
        send.Text = "Senden"; send.Click += async (_, _) => await RequestAIAsync(false);
        compose.Text = "Mit gewählter KI komponieren"; compose.Click += async (_, _) => await RequestAIAsync(true);
        cancel.Click += (_, _) => pending?.Cancel();
        composition.ReadOnly = false; composition.Font = MacFont(13);
        composition.TextChanged += (_, _) => { if (!loadingIdea) { editableIdea = composition.Text; assignment.Text = editableIdea; SaveLocalState(); } };
        chatInput.KeyDown += async (_, e) => { if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; await RequestAIAsync(false); } };
        guiChecks.AddRange([chatInput, compose, provider, model, effort, measures, meter, tempo, musicalKey, ensemble]);
        assignment.Text = "Komponiere ein eigenständiges Klavierstück mit einer tragenden musikalischen Idee.";
    }
    Control ScrollWorkspace(Control content, int width, int height)
    {
        var scroll = new Panel { Dock = DockStyle.Fill, AutoScroll = true, BackColor = StudioTheme.Canvas };
        content.Location = Point.Empty; content.Dock = DockStyle.None; scroll.Controls.Add(content);
        void SizeContent() { content.Size = new Size(Math.Max(width, scroll.ClientSize.Width - (scroll.VerticalScroll.Visible ? SystemInformation.VerticalScrollBarWidth : 0)), Math.Max(height, scroll.ClientSize.Height - (scroll.HorizontalScroll.Visible ? SystemInformation.HorizontalScrollBarHeight : 0))); }
        scroll.Resize += (_, _) => SizeContent(); SizeContent(); return scroll;
    }
    Control BuildMacMain()
    {
        var main = Grid(1, 4); main.Padding = new Padding(24, 18, 24, 18);
        main.RowStyles.Add(new RowStyle(SizeType.Absolute, 58)); main.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        main.RowStyles.Add(new RowStyle(SizeType.Absolute, 226)); main.RowStyles.Add(new RowStyle(SizeType.Absolute, 92));
        var controls = MacPanel(); var row = MacRow(); row.WrapContents = false;
        provider.Items.AddRange(["Google / Gemini", "Anthropic / Claude", "OpenAI"]); effort.Items.AddRange(["Sparsam – Low", "Standard – Medium", "Maximum – High"]); effort.SelectedIndex = 1;
        provider.Width = 130; model.Width = 148; effort.Width = 94;
        provider.SelectedIndexChanged += (_, _) => ProviderChanged();
        row.Controls.Add(MacLabel("KI", 12, true)); row.Controls.Add(provider); row.Controls.Add(model); row.Controls.Add(effort);
        row.Controls.Add(MacLabel("Takte")); measures.Width = 62; measures.PlaceholderText = "24"; row.Controls.Add(measures); row.Controls.Add(meter);
        row.Controls.Add(MacLabel("Tempo")); tempo.Width = 58; tempo.PlaceholderText = "96"; row.Controls.Add(tempo);
        row.Controls.Add(MacLabel("Tonart")); musicalKey.Width = 86; musicalKey.PlaceholderText = "C-Dur"; row.Controls.Add(musicalKey);
        row.Controls.Add(MacLabel("Instrumente")); ensemble.Width = 150; ensemble.PlaceholderText = "Piano"; row.Controls.Add(ensemble);
        controls.Controls.Add(row); controls.Margin = new Padding(0, 0, 0, 14); main.Controls.Add(controls, 0, 0);
        var work = Grid(2, 1); work.ColumnStyles.Clear(); work.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 66)); work.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 34)); work.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); work.Margin = new Padding(0, 0, 0, 14);
        var chatPanel = MacPanel(); chatPanel.Margin = new Padding(0, 0, 7, 0); var chatLayout = Grid(1, 3);
        chatLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 36)); chatLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); chatLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
        chatLayout.Controls.Add(MacLabel("MusicChat", 20, true), 0, 0); chat.BorderStyle = BorderStyle.FixedSingle; chat.Font = MacFont(13); chatLayout.Controls.Add(chat, 0, 1);
        var input = Grid(2, 1); input.ColumnStyles.Clear(); input.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100)); input.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 100)); input.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); input.Padding = new Padding(0, 10, 0, 0);
        chatInput.Dock = DockStyle.Fill; chatInput.Font = MacFont(13); chatInput.Multiline = true; input.Controls.Add(chatInput, 0, 0); send.Dock = DockStyle.Fill; send.AutoSize = false; input.Controls.Add(send, 1, 0);
        chatLayout.Controls.Add(input, 0, 2); chatPanel.Controls.Add(chatLayout); work.Controls.Add(chatPanel, 0, 0);
        var ideaPanel = MacPanel(); ideaPanel.Margin = new Padding(7, 0, 0, 0); var idea = Grid(1, 2); idea.RowStyles.Add(new RowStyle(SizeType.Absolute, 32)); idea.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        idea.Controls.Add(MacLabel("Aktuelle Kompositionsidee", 16, true), 0, 0); composition.BorderStyle = BorderStyle.FixedSingle; idea.Controls.Add(composition, 0, 1); ideaPanel.Controls.Add(idea); work.Controls.Add(ideaPanel, 1, 0); main.Controls.Add(work, 0, 1);
        var deck = MacPanel(); deck.Padding = new Padding(7, 5, 7, 5); deck.Margin = new Padding(0, 0, 0, 14);
        var dl = Grid(1, 2); dl.RowStyles.Add(new RowStyle(SizeType.Absolute, 25)); dl.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); dl.Controls.Add(MacLabel("Stücke (1–10)", 14, true), 0, 0);
        var cardScroll = new Panel { Dock = DockStyle.Fill, AutoScroll = true };
        var cards = new FlowLayoutPanel { Location = Point.Empty, Width = 1235, Height = 174, WrapContents = false, Margin = Padding.Empty, Padding = new Padding(1, 2, 1, 1) };
        for (int i = 0; i < 10; i++)
        {
            int index = i; var card = new PieceCard { Number = i + 1, Width = 116, Height = 164, AutoSize = false, Margin = new Padding(0, 0, 8, 0), Font = MacFont(12), AllowDrop = true };
            card.Click += (_, _) => { if (!busy) slots.SelectedIndex = index; };
            card.DragEnter += (_, e) => e.Effect = !busy && e.Data?.GetDataPresent(DataFormats.FileDrop) == true ? DragDropEffects.Copy : DragDropEffects.None;
            card.DragDrop += async (_, e) => { if (!busy && e.Data?.GetData(DataFormats.FileDrop) is string[] paths && paths.Length == 1) await GuardAsync(() => ImportIntoSlotAsync(paths[0], index)); };
            var menu = new ContextMenuStrip(); menu.Items.Add("MIDI-Datei laden …", null, async (_, _) => await GuardAsync(() => OpenAsync(index)));
            menu.Items.Add("CLAB-Datei laden …", null, async (_, _) => await GuardAsync(() => OpenAsync(index))); menu.Items.Add(new ToolStripSeparator()); menu.Items.Add("Stück löschen", null, async (_, _) => await DeleteSlotAsync(index)); card.ContextMenuStrip = menu;
            slotCards.Add(card); cards.Controls.Add(card);
        }
        cardScroll.Controls.Add(cards); dl.Controls.Add(cardScroll, 0, 1); deck.Controls.Add(dl); main.Controls.Add(deck, 0, 2);
        var bottom = MacPanel(); bottom.Padding = new Padding(8, 5, 8, 5); var bl = Grid(1, 2); bl.RowStyles.Add(new RowStyle(SizeType.Absolute, 34)); bl.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); bl.Controls.Add(BuildTransport(false), 0, 0);
        var actions = MacRow(); AddButton(actions, "MIDI sichern", () => ExportAsync("mid")); AddButton(actions, "CLAB sichern", SaveDocumentAsync); AddButton(actions, "CLAB laden …", () => OpenAsync());
        actions.Controls.Add(new Panel { Width = 22, Height = 1 }); AddButton(actions, "Import …", () => OpenAsync(slots.SelectedIndex)); AddButton(actions, "Motiv …", PrepareMotif);
        actions.Controls.Add(compose); bl.Controls.Add(actions, 0, 1); bottom.Controls.Add(bl); main.Controls.Add(bottom, 0, 3);
        return ScrollWorkspace(main, 1260, 850);
    }
    Control BuildTransport(bool notation)
    {
        var transport = new Transport(); transports.Add(transport); var row = MacRow();
        AddButton(row, "▶", PlayAsync); AddButton(row, "■", () => { player.Stop(); return Task.CompletedTask; }); row.Controls.Add(transport.Loop); row.Controls.Add(transport.Time); row.Controls.Add(transport.Position);
        row.Controls.Add(MacLabel("Tempo")); row.Controls.Add(transport.Tempo); row.Controls.Add(MacLabel("Lautstärke")); row.Controls.Add(transport.Volume);
        if (notation) transport.Position.Width = 220;
        transport.Loop.CheckedChanged += (_, _) => { loopPlaying = transport.Loop.Checked; foreach (var other in transports) if (other != transport) other.Loop.Checked = loopPlaying; };
        transport.Position.Scroll += (_, _) => { if (player.Loaded && !seekUpdating) { player.Seek(transport.Position.Value / 1000d); UpdateTransport(); } };
        transport.Tempo.KeyDown += (_, e) => { if (e.KeyCode == Keys.Enter && int.TryParse(transport.Tempo.Text, out int bpm) && bpm is >= 20 and <= 400) { playerBpm = bpm; if (player.Loaded) player.SetTempo(bpm); foreach (var other in transports) other.Tempo.Text = bpm.ToString(); e.SuppressKeyPress = true; } };
        transport.Volume.Scroll += (_, _) => { playerVolume = transport.Volume.Value; foreach (var other in transports) other.Volume.Value = playerVolume; if (player.Loaded && !player.SetVolume(playerVolume)) SetStatus("Dieser Windows-MIDI-Treiber unterstützt keine Lautstärkeregelung.", true); };
        return row;
    }
    async Task PlayAsync()
    {
        if (currentMidi == null) throw new InvalidOperationException("Kein Stück geladen.");
        if (!player.Loaded) player.Load(currentMidi); if (playerBpm > 0) player.SetTempo(playerBpm); player.SetVolume(playerVolume); player.Play(); await Task.CompletedTask;
    }
    void UpdateTransport()
    {
        if (!player.Loaded) return; seekUpdating = true;
        try { int position = player.Position, length = player.Length; foreach (var transport in transports) { transport.Time.Text = FormatTime(position) + " / " + FormatTime(length); transport.Position.Value = length == 0 ? 0 : Math.Clamp((int)(1000d * position / length), 0, 1000); } if (loopPlaying && length > 0 && position >= length && player.Mode == "stopped") { player.Seek(0); player.Play(); } }
        finally { seekUpdating = false; }
    }
    Task PrepareMotif()
    {
        using var dialog = new Form { Text = "Musikalisches Motiv", Size = new Size(440, 180), StartPosition = FormStartPosition.CenterParent, FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false };
        var layout = new FlowLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(14) };
        layout.Controls.Add(new Label { Text = "Wie lang soll das Motiv sein? Komponieren setzt den vorbereiteten Auftrag anschließend um.", Width = 390, Height = 45 });
        foreach (int bars in new[] { 2, 4, 8 }) { var button = new Button { Text = bars + " Takte", AutoSize = true }; button.Click += (_, _) => { measures.Text = bars.ToString(); composition.Text = $"Komponiere ein prägnantes musikalisches Motiv von {bars} Takten als Ausgangspunkt für eine spätere Komposition. Übernimm die aktuell gewählte Besetzung, Tonart, Taktart und das Tempo."; chatInput.Clear(); dialog.Close(); }; layout.Controls.Add(button); }
        dialog.Controls.Add(layout); dialog.ShowDialog(this); return Task.CompletedTask;
    }
    Control BuildMacNotation()
    {
        var page = Grid(2, 1); page.ColumnStyles.Clear(); page.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 301)); page.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100)); page.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        var settings = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true, Padding = new Padding(16), BackColor = StudioTheme.Canvas };
        settings.Controls.Add(MacLabel("Noten", 17, true)); settings.Controls.Add(new Label { Text = "Darstellungsquantisierung für MusicXML. Die MIDI-Daten und die Komposition bleiben unverändert.", Width = 264, Height = 48, ForeColor = StudioTheme.Muted, Font = MacFont(12) });
        settings.Controls.Add(MacLabel("Darstellungsquantisierung", 17, true));
        string[] titles = ["Preset", "Rhythmusmodus", "Kleinster gerader Notenwert", "Kleinster triolischer Notenwert", "Kurze Pausen", "Notenlängen glätten", "Mini-Pausen am Taktanfang", "Darstellung", "Splitpunkt"];
        string[][] choices = [["Klavier – lesbar", "MIDI-nah", "Benutzerdefiniert"], ["Auto", "Gerade", "Triolisch"], ["Aus", "Viertel", "Achtel", "16tel", "32tel", "64tel"], ["Aus", "Vierteltriolen", "Achteltriolen", "16teltriolen", "32teltriolen"], ["Alle Pausen zeigen", "bis 32tel glätten", "bis 16tel glätten", "bis Achtel glätten"], ["Aus", "Leicht", "Mittel", "Stark"], ["Aus", "bis 32tel", "bis 16tel", "bis Achtel"], ["Automatisch", "Ein System", "Zwei Systeme"], ["C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]];
        updatingNotation = true;
        int[] defaults = [0, 0, 3, 3, 2, 3, 2, 0, 7];
        for (int i = 0; i < 9; i++) { if (i == 7) settings.Controls.Add(MacLabel("Klaviersystem", 17, true)); settings.Controls.Add(MacLabel(titles[i], 12, true)); var control = notationSettings[i]; control.Width = 264; control.Items.AddRange(choices[i]); control.SelectedIndex = defaults[i]; int index = i; control.SelectedIndexChanged += async (_, _) => await NotationChangedAsync(index); settings.Controls.Add(control); }
        settings.Controls.Add(MacLabel("Notenwerte", 17, true)); settings.Controls.Add(splitBeats); splitBeats.CheckedChanged += async (_, _) => await NotationChangedAsync(-1); updatingNotation = false;
        page.Controls.Add(settings, 0, 0);
        var right = Grid(1, 6); right.Padding = new Padding(14, 12, 14, 12); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 70)); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 48)); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 66)); right.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 50)); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
        var deck = Grid(1, 2); deck.RowStyles.Add(new RowStyle(SizeType.Absolute, 28)); deck.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); deck.Controls.Add(MacLabel("Stücke / Varianten", 17, true), 0, 0);
        var numbers = Grid(10, 1); numbers.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        for (int i = 0; i < 10; i++) { int index = i; var button = new StudioButton { Text = (i + 1).ToString(), Dock = DockStyle.Fill, AutoSize = false, Padding = Padding.Empty }; button.Click += (_, _) => { if (!busy) slots.SelectedIndex = index; }; notationCards.Add(button); numbers.Controls.Add(button, i, 0); } deck.Controls.Add(numbers, 0, 1); right.Controls.Add(deck, 0, 0);
        var transport = MacPanel(); transport.Padding = new Padding(10, 6, 10, 6); transport.Controls.Add(BuildTransport(true)); right.Controls.Add(transport, 0, 1);
        var previewHeader = Grid(1, 2); previewHeader.RowStyles.Add(new RowStyle(SizeType.Absolute, 30)); previewHeader.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); previewHeader.Controls.Add(MacLabel("Notenbildvorschau", 17, true), 0, 0); previewHeader.Controls.Add(new Label { Text = "Schnelle Kontrolle der aktuellen MusicXML-Darstellung. Änderungen links werden automatisch in der Vorschau sichtbar; MIDI und interner Score bleiben unverändert.", Dock = DockStyle.Fill, ForeColor = StudioTheme.Muted, Font = MacFont(11.5f) }, 0, 1); right.Controls.Add(previewHeader, 0, 2);
        notationHost.Controls.Add(web); right.Controls.Add(notationHost, 0, 3); notationSummary.Text = "Darstellungsregeln · Klavier – lesbar"; right.Controls.Add(notationSummary, 0, 4);
        var exports = MacRow(); exports.Controls.Add(MacLabel("Export", 12, true)); var export = new StudioButton { Text = "MusicXML sichern / ziehen …", AutoSize = true }; export.Click += async (_, _) => await GuardAsync(() => ExportAsync("musicxml")); Point dragStart = Point.Empty; export.MouseDown += (_, e) => dragStart = e.Location; export.MouseMove += async (_, e) => { if (e.Button != MouseButtons.Left || Math.Abs(e.X - dragStart.X) + Math.Abs(e.Y - dragStart.Y) < 10 || Score == null) return; dragStart = e.Location; await GuardAsync(async () => { var result = await core.RunAsync(new JsonObject { ["operation"] = "musicxml", ["score"] = Score.DeepClone(), ["options"] = notationOptions?.DeepClone() }); string path = Path.Combine(Path.GetTempPath(), Guid.NewGuid() + ".musicxml"); await File.WriteAllBytesAsync(path, Convert.FromBase64String(result["data"]!.GetValue<string>())); export.DoDragDrop(new DataObject(DataFormats.FileDrop, new[] { path }), DragDropEffects.Copy); }); }; exports.Controls.Add(export); right.Controls.Add(exports, 0, 5); page.Controls.Add(right, 1, 0);
        return ScrollWorkspace(page, 1160, 720);
    }
    async Task NotationChangedAsync(int changed)
    {
        if (updatingNotation || loadingSettings) return;
        updatingNotation = true;
        if (changed == 0 && notationSettings[0].SelectedIndex < 2)
        {
            int[] readable = [0, 0, 3, 3, 2, 3, 2, 0, 7], near = [1, 0, 0, 0, 0, 0, 0, 0, 7];
            var selected = notationSettings[0].SelectedIndex == 0 ? readable : near;
            for (int i = 1; i < 9; i++) notationSettings[i].SelectedIndex = selected[i]; splitBeats.Checked = selected[0] == 0;
        }
        else notationSettings[0].SelectedIndex = 2;
        updatingNotation = false;
        notationOptions = BuildNotationOptions(); notationSummary.Text = "Darstellungsregeln · " + notationSettings[0].Text + " · " + notationSettings[1].Text + " · " + notationSettings[7].Text + " · Split " + notationSettings[8].Text;
        SaveLocalState(); if (Score != null) await GuardAsync(RefreshNotationAsync);
    }
    JsonObject BuildNotationOptions()
    {
        double?[] straight = [null, 1, .5, .25, .125, .0625], triplet = [null, 2d/3, 1d/3, 1d/6, 1d/12]; double[] rest = [0, .125, .25, .5], occupancy = [1, .75, .6, .45], tolerance = [0, .10, .18, .30]; int[] split = [48, 50, 52, 53, 55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72];
        return new JsonObject { ["startGrid"] = 0, ["shortRestThreshold"] = rest[notationSettings[4].SelectedIndex], ["occupancyThreshold"] = occupancy[notationSettings[5].SelectedIndex], ["durationTolerance"] = tolerance[notationSettings[5].SelectedIndex], ["minimumNoteValue"] = null, ["rhythmMode"] = new[] { "auto", "straight", "triplet" }[notationSettings[1].SelectedIndex], ["minimumStraightNoteValue"] = straight[notationSettings[2].SelectedIndex], ["minimumTripletNoteValue"] = triplet[notationSettings[3].SelectedIndex], ["barStartSnapThreshold"] = rest[notationSettings[6].SelectedIndex], ["splitAtBeatBoundaries"] = splitBeats.Checked, ["pianoStaffMode"] = new[] { "auto", "single", "two" }[notationSettings[7].SelectedIndex], ["pianoSplitPoint"] = split[notationSettings[8].SelectedIndex] };
    }
    async Task RefreshNotationAsync()
    {
        if (Score == null) return; int generation = displayGeneration;
        var result = await core.RunAsync(new JsonObject { ["operation"] = "musicxml", ["score"] = Score.DeepClone(), ["options"] = notationOptions?.DeepClone() });
        if (generation != displayGeneration) return; currentXML = Encoding.UTF8.GetString(Convert.FromBase64String(result["data"]!.GetValue<string>())); if (webReady) RenderNotation();
    }
    Control BuildMacTechnology()
    {
        var page = Grid(1, 4); page.Padding = new Padding(18, 16, 18, 16); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 32)); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 40)); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 40)); page.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        page.Controls.Add(MacLabel("Technik", 17, true), 0, 0); page.Controls.Add(new Label { Text = "API-Schlüssel, MIDI-Ausgabe, technische Prüfung, JSON, Diagnose und Verlauf. Diese Werkzeuge sind bewusst von der musikalischen Hauptseite getrennt.", Dock = DockStyle.Fill, Font = MacFont(12), ForeColor = StudioTheme.Muted }, 0, 1);
        var actions = MacRow(); AddButton(actions, "API-Schlüssel …", ShowKeys); AddButton(actions, "MIDI-Ausgabe …", ShowMidiOutput); AddButton(actions, "CLAB öffnen …", () => OpenAsync()); AddButton(actions, "CLAB sichern …", SaveDocumentAsync); AddButton(actions, "JSON sichern …", SaveScoreJSON); page.Controls.Add(actions, 0, 2);
        var pages = new TabControl { Dock = DockStyle.Fill }; foreach (var pair in new[] { ("Technische Prüfung", (Control)validation), ("JSON", (Control)scoreJSON), ("Verlauf", BuildHistory()), ("Diagnose", (Control)diagnostic) }) { var tab = new TabPage(pair.Item1); tab.Controls.Add(pair.Item2); pages.TabPages.Add(tab); } page.Controls.Add(pages, 0, 3);
        return ScrollWorkspace(page, 1000, 640);
    }
    Control BuildHistory()
    {
        var page = Grid(1, 2); page.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 40)); page.Controls.Add(historyList, 0, 0);
        var buttons = MacRow(); AddButton(buttons, "Ausgewählten Eintrag laden", LoadHistoryAsync); AddButton(buttons, "Verlauf löschen", () => { if (MessageBox.Show(this, "Verlauf löschen? Gespeicherte Stücke bleiben erhalten.", "Verlauf", MessageBoxButtons.YesNo) == DialogResult.Yes) { pieceHistory.Clear(); RefreshHistory(); SaveLocalState(); } return Task.CompletedTask; }); page.Controls.Add(buttons, 0, 1);
        historyList.DoubleClick += async (_, _) => await GuardAsync(LoadHistoryAsync); return page;
    }
    void RefreshHistory() { historyList.Items.Clear(); foreach (var document in pieceHistory) historyList.Items.Add(document["title"]?.GetValue<string>() ?? "Stück"); }
    void RememberPiece(JsonObject document) { pieceHistory.Insert(0, document.DeepClone().AsObject()); if (pieceHistory.Count > 100) pieceHistory.RemoveAt(100); RefreshHistory(); }
    async Task LoadHistoryAsync() { if (busy || historyList.SelectedIndex < 0) return; int index = Array.FindIndex(documents, d => d == null); if (index < 0) throw new InvalidOperationException("Alle Stück-Plätze belegt."); documents[index] = pieceHistory[historyList.SelectedIndex].DeepClone().AsObject(); RefreshSlots(); slots.SelectedIndex = index; await DisplayCurrentAsync(); SaveLocalState(); }
    Task ShowKeys()
    {
        using var dialog = new Form { Text = "API-Schlüssel", Size = new Size(650, 190), StartPosition = FormStartPosition.CenterParent, FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false };
        var row = MacRow(true); row.Padding = new Padding(16); row.Controls.Add(MacLabel("API-Schlüssel für " + provider.Text)); row.Controls.Add(apiKey); row.Controls.Add(remember); AddButton(row, "Schlüssel übernehmen", () => { StoreKey(); return Task.CompletedTask; }); AddButton(row, "Gespeicherten Schlüssel löschen", () => { keys.Remove(activeProvider); apiKey.Clear(); remember.Checked = false; secrets.Save(keys); return Task.CompletedTask; }); dialog.Controls.Add(row); dialog.ShowDialog(this); row.Controls.Remove(apiKey); row.Controls.Remove(remember); return Task.CompletedTask;
    }
    Task ShowMidiOutput() { MessageBox.Show(this, "Windows-General-MIDI über den System-Synthesizer.\n\nDie Mac-Auswahl von Soundfonts und direkten MIDI-Ausgängen ist noch nicht unter Windows portiert. Player, Tempo, Position und Loop stehen zur Verfügung; Lautstärke hängt vom Treiber ab.", "MIDI-Ausgabe", MessageBoxButtons.OK, MessageBoxIcon.Information); return Task.CompletedTask; }
    Task SaveScoreJSON() { if (Score == null) throw new InvalidOperationException("Kein Stück geladen."); using var dialog = new SaveFileDialog { Filter = "JSON|*.json", FileName = SafeName(Current?["title"]?.GetValue<string>() ?? "Partitur") + ".json" }; if (dialog.ShowDialog(this) == DialogResult.OK) AtomicFile.WriteText(dialog.FileName, Score.ToJsonString(new JsonSerializerOptions { WriteIndented = true })); return Task.CompletedTask; }
    MenuStrip BuildMacMenus()
    {
        var menu = new MenuStrip { BackColor = StudioTheme.Canvas }; MainMenuStrip = menu;
        void Action(ToolStripMenuItem parent, string label, Func<Task> callback) { var item = new ToolStripMenuItem(label); item.Click += async (_, _) => await GuardAsync(callback); parent.DropDownItems.Add(item); }
        var file = new ToolStripMenuItem("Datei"); menu.Items.Add(file);
        Action(file, "Projekt benennen …", () => { using var dialog = new Form { Text = "Projekt benennen", Size = new Size(420, 135), StartPosition = FormStartPosition.CenterParent }; var text = new TextBox { Text = projectName, Dock = DockStyle.Top }; var save = new Button { Text = "Übernehmen", Dock = DockStyle.Bottom, DialogResult = DialogResult.OK }; dialog.Controls.Add(text); dialog.Controls.Add(save); if (dialog.ShowDialog(this) == DialogResult.OK) projectName = text.Text; SaveLocalState(); return Task.CompletedTask; });
        Action(file, "Projekt laden …", LoadProjectAsync); Action(file, "Projekt speichern …", SaveProjectAsync); file.DropDownItems.Add(new ToolStripSeparator());
        Action(file, "MIDI als Vorlage laden …", () => { useSource.Checked = true; return OpenAsync(); }); Action(file, "MIDI-Vorlage löschen", () => { useSource.Checked = false; return Task.CompletedTask; });
        file.DropDownItems.Add(new ToolStripSeparator()); Action(file, "MIDI sichern …", () => ExportAsync("mid")); Action(file, "JSON sichern …", SaveScoreJSON); Action(file, "LilyPond sichern …", ExportLilyPondAsync); Action(file, "An Hacklily übergeben", () => { OpenHacklily(); return Task.CompletedTask; });
        var edit = new ToolStripMenuItem("Bearbeiten"); menu.Items.Add(edit);
        Action(edit, "Rückgängig", () => { if (ActiveControl is TextBoxBase text) text.Undo(); return Task.CompletedTask; }); Action(edit, "Ausschneiden", () => { if (ActiveControl is TextBoxBase text) text.Cut(); return Task.CompletedTask; }); Action(edit, "Kopieren", () => { if (ActiveControl is TextBoxBase text) text.Copy(); return Task.CompletedTask; }); Action(edit, "Einsetzen", () => { if (ActiveControl is TextBoxBase text) text.Paste(); return Task.CompletedTask; }); Action(edit, "Alles auswählen", () => { if (ActiveControl is TextBoxBase text) text.SelectAll(); return Task.CompletedTask; });
        var compositionMenu = new ToolStripMenuItem("Komposition"); menu.Items.Add(compositionMenu); Action(compositionMenu, "Mit gewählter KI komponieren", () => RequestAIAsync(true)); Action(compositionMenu, "Anfrage abbrechen", () => { pending?.Cancel(); return Task.CompletedTask; });
        var technical = new ToolStripMenuItem("Technisches"); menu.Items.Add(technical); Action(technical, "API-Schlüssel …", ShowKeys); Action(technical, "MIDI-Ausgabe …", ShowMidiOutput); Action(technical, "Backup laden …", () => { MessageBox.Show(this, "Das verschlüsselte Mac-Backup wird unter Windows noch nicht gelesen. Für den Austausch Projekt laden verwenden."); return Task.CompletedTask; }); Action(technical, "Backup sichern …", () => { MessageBox.Show(this, "Das verschlüsselte Mac-Backup ist noch nicht portiert. Projekt speichern sichert alle Stück-Plätze ohne API-Schlüssel."); return Task.CompletedTask; }); Action(technical, "Diagnosedatei sichern …", () => { SaveDiagnostic(); return Task.CompletedTask; });
        var diagnosis = new ToolStripMenuItem("Diagnose"); menu.Items.Add(diagnosis); Action(diagnosis, "Diagnosedatei sichern …", () => { SaveDiagnostic(); return Task.CompletedTask; });
        var display = new ToolStripMenuItem("Darstellung"); menu.Items.Add(display); foreach (int percent in new[] { 80, 90, 100, 110, 120, 130, 140, 150 }) Action(display, percent + " %", () => { Scale(new SizeF(percent / (float)guiZoom, percent / (float)guiZoom)); guiZoom = percent; return Task.CompletedTask; });
        var window = new ToolStripMenuItem("Fenster"); menu.Items.Add(window); Action(window, "Composition Lab zeigen", () => { WindowState = FormWindowState.Normal; Activate(); return Task.CompletedTask; }); return menu;
    }
    int guiZoom = 100;
    async Task SaveProjectAsync()
    {
        using var dialog = new SaveFileDialog { Filter = "Composition Lab Arbeitsplatz|*.clabproject", FileName = SafeName(projectName) + ".clabproject", OverwritePrompt = true }; if (dialog.ShowDialog(this) != DialogResult.OK) return;
        var settings = new JsonObject { ["provider"] = activeProvider, ["models"] = JsonSerializer.SerializeToNode(models), ["efforts"] = new JsonObject(), ["measures"] = measures.Text, ["meter"] = meter.Text, ["tempo"] = tempo.Text, ["key"] = musicalKey.Text, ["ensemble"] = ensemble.Text, ["prompt"] = assignment.Text, ["zoomPercent"] = 100 };
        var slotsJSON = new JsonArray(documents.Select(d => d == null ? null : ToHistory(d)).ToArray());
        var project = new JsonObject { ["format"] = "composition-lab-v6-project", ["version"] = 1, ["savedAt"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - 978307200, ["name"] = projectName, ["settings"] = settings, ["concept"] = composition.Text, ["slots"] = slotsJSON, ["activeSlot"] = slots.SelectedIndex, ["history"] = new JsonArray(pieceHistory.Select(ToHistory).ToArray()), ["chat"] = chat.Text };
        await core.RunAsync(new JsonObject { ["operation"] = "validate-workspace", ["document"] = project.DeepClone() }); AtomicFile.WriteText(dialog.FileName, project.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
    }
    JsonObject ToHistory(JsonObject document) => new() { ["id"] = Guid.NewGuid().ToString(), ["time"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - 978307200, ["title"] = document["title"]!.DeepClone(), ["provider"] = document["provider"]?.DeepClone() ?? JsonValue.Create(activeProvider), ["model"] = document["model"]?.DeepClone() ?? JsonValue.Create(SelectedModelId), ["concept"] = document["concept"]?.DeepClone() ?? JsonValue.Create(""), ["score"] = document["score"]!.DeepClone(), ["costUSD"] = document["costUSD"]?.DeepClone(), ["inputTokens"] = document["inputTokens"]?.DeepClone(), ["outputTokens"] = document["outputTokens"]?.DeepClone() };
    async Task LoadProjectAsync()
    {
        if (busy) return; using var dialog = new OpenFileDialog { Filter = "Composition Lab Arbeitsplatz|*.clabproject" }; if (dialog.ShowDialog(this) != DialogResult.OK) return;
        await LoadProjectPathAsync(dialog.FileName);
    }
    async Task LoadProjectPathAsync(string path)
    {
        var project = JsonNode.Parse(await File.ReadAllTextAsync(path))!.AsObject(); await core.RunAsync(new JsonObject { ["operation"] = "validate-workspace", ["document"] = project.DeepClone() }); if (project["slots"] is not JsonArray slotsJSON) throw new InvalidDataException("Diese Datei enthält keine Stück-Plätze.");
        var imported = new JsonObject?[10]; for (int i = 0; i < Math.Min(10, slotsJSON.Count); i++) if (slotsJSON[i] is JsonObject item) { imported[i] = CreateDocument(item["score"]!.DeepClone().AsObject(), item["concept"]?.GetValue<string>() ?? ""); foreach (var field in new[] { "title", "provider", "model", "costUSD", "inputTokens", "outputTokens" }) if (item[field] != null) imported[i]![field] = item[field]!.DeepClone(); await core.RunAsync(new JsonObject { ["operation"] = "validate-document", ["document"] = imported[i]!.DeepClone() }); }
        if (!testMode && MessageBox.Show(this, "Aktuellen Arbeitsplatz ersetzen?", "Projekt laden", MessageBoxButtons.YesNo) != DialogResult.Yes) return;
        var settings = project["settings"]!.AsObject();
        if (settings["models"] is JsonObject savedModels) foreach (var pair in savedModels) if (models.ContainsKey(pair.Key)) models[pair.Key] = pair.Value!.GetValue<string>();
        measures.Text = settings["measures"]?.GetValue<string>() ?? ""; meter.Text = settings["meter"]?.GetValue<string>() ?? ""; tempo.Text = settings["tempo"]?.GetValue<string>() ?? ""; musicalKey.Text = settings["key"]?.GetValue<string>() ?? ""; ensemble.Text = settings["ensemble"]?.GetValue<string>() ?? ""; assignment.Text = settings["prompt"]?.GetValue<string>() ?? "";
        Array.Copy(imported, documents, 10); projectName = project["name"]?.GetValue<string>() ?? "Unbenannt"; chat.Text = project["chat"]?.GetValue<string>() ?? ""; composition.Text = project["concept"]?.GetValue<string>() ?? settings["prompt"]?.GetValue<string>() ?? ""; RefreshSlots(); slots.SelectedIndex = Math.Clamp(project["activeSlot"]?.GetValue<int>() ?? 0, 0, 9); await DisplayCurrentAsync(); SaveLocalState();
    }
}

using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CompositionLab;

// Layout port of Sources/MainViewController.swift (main a2aefd7).
// Each builder mirrors the corresponding build* function instead of redesigning it.
internal sealed partial class MainForm
{
    static class NativeCue { [System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr handle, uint message, IntPtr value, string text); }
    sealed record ModelChoice(string Id, string Label) { public override string ToString() => Label; }
    string SelectedModelId => (model.SelectedItem as ModelChoice)?.Id ?? model.Text;
    void SelectModel()
    {
        var values = activeProvider switch { "gemini" => new[] { new ModelChoice("gemini-3.7-flash", "Gemini 3.7 Flash") }, "openai" => new[] { new ModelChoice("gpt-5.6-sol", "GPT-5.6 Sol"), new ModelChoice("gpt-5.6-terra", "GPT-5.6 Terra"), new ModelChoice("gpt-5.6-luna", "GPT-5.6 Luna") }, _ => new[] { new ModelChoice("claude-sonnet-5", "Claude Sonnet 5") } };
        string selected = models[activeProvider]; model.Items.Clear(); model.Items.AddRange(values);
        var choice = values.FirstOrDefault(v => v.Id == selected); if (choice == null) { choice = new ModelChoice(selected, selected); model.Items.Add(choice); } model.SelectedItem = choice; FitChoices(model);
    }
    void FitChoices(ComboBox control)
    {
        int textWidth = control.Items.Cast<object>().Select(item => TextRenderer.MeasureText(item.ToString(), control.Font).Width).DefaultIfEmpty(0).Max();
        control.Width = Math.Max(control.Width, textWidth + SystemInformation.VerticalScrollBarWidth + LayoutPixels(12));
        control.DropDownWidth = Math.Max(control.Width, control.DropDownWidth);
    }
    readonly TextBox chatInput = new() { PlaceholderText = "Auftrag eingeben · Strg+Enter zum Senden", Multiline = true, WordWrap = true, AcceptsReturn = true, ScrollBars = ScrollBars.Vertical };
    Action? toggleLargePreview;
    Control? notationTransport;
    bool largePreview;
    readonly TextBox meter = new() { Width = 54, PlaceholderText = "4/4" };
    readonly List<StudioButton> notationCards = [];
    readonly List<Control> guiChecks = [];
    readonly RichTextBox validation = new() { ReadOnly = true, Dock = DockStyle.Fill };
    readonly RichTextBox scoreJSON = new() { ReadOnly = true, Dock = DockStyle.Fill, Font = new Font("Consolas", 9) };
    readonly ListBox historyList = new() { Dock = DockStyle.Fill, IntegralHeight = false };
    readonly List<JsonObject> pieceHistory = [];
    readonly List<Transport> transports = [];
    readonly ComboBox[] notationSettings = Enumerable.Range(0, 9).Select(_ => new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList }).ToArray();
    readonly CheckBox splitBeats = new() { Text = "Zusammengesetzte Notenwerte an Zählzeiten teilen und binden", Checked = true, AutoSize = false, Width = 264, Height = 50, MaximumSize = new Size(264, 50) };
    readonly Label previewPage = new() { AutoSize = true, Text = "Seite – / –", Padding = new Padding(0, 5, 0, 0) };
    readonly Label previewZoom = new() { AutoSize = true, Text = "100 %", Padding = new Padding(0, 5, 0, 0) };
    readonly Label notationCurrent = new() { AutoEllipsis = true };
    readonly Label notationSummary = new() { Dock = DockStyle.Fill, AutoSize = true };
    JsonObject? notationOptions;
    bool updatingNotation;
    string projectName = "Unbenannt";
    string editableIdea = "";
    bool loadingIdea;
    bool loopPlaying;
    bool seekUpdating;
    int playerBpm;
    bool tempoOverride;
    int playerVolume = 90;
    sealed class Transport
    {
        public readonly Label Time = new() { AutoSize = true, Text = "0:00 / 0:00", Padding = new Padding(0, 6, 0, 0) };
        public readonly TrackBar Position = new() { AutoSize = false, Width = 260, Height = 26, Maximum = 1000, TickStyle = TickStyle.None };
        public readonly CheckBox Loop = new() { Text = "↻ Loop", Appearance = Appearance.Button, AutoSize = false, Width = 62, Height = 26 };
        public readonly TextBox Tempo = new() { Width = 50 };
        public readonly TrackBar Volume = new() { AutoSize = false, Width = 130, Height = 26, Maximum = 100, Value = 90, TickStyle = TickStyle.None };
    }
    SplitContainer? mainSplit;
    double mainSplitRatio = .5;
    bool arrangingSplit;
    bool mainSplitReady;
    bool mainSplitDragging;
    void ArrangeMainSplit()
    {
        if (arrangingSplit || mainSplit == null || mainSplit.Width <= mainSplit.SplitterWidth + 4) return;
        arrangingSplit = true;
        try
        {
            int available = mainSplit.Width - mainSplit.SplitterWidth;
            int minimum = Math.Min(LayoutPixels(220), available / 3);
            if (mainSplit.Panel1MinSize != minimum || mainSplit.Panel2MinSize != minimum)
            {
                mainSplit.Panel1MinSize = 0; mainSplit.Panel2MinSize = 0;
                mainSplit.Panel1MinSize = minimum; mainSplit.Panel2MinSize = minimum;
            }
            int distance = Math.Clamp((int)Math.Round(available * mainSplitRatio), minimum, available - minimum);
            if (mainSplit.SplitterDistance != distance) mainSplit.SplitterDistance = distance;
        }
        finally { arrangingSplit = false; }
    }
    float testLayoutScale = 1;
    int LayoutPixels(int logical) => (int)Math.Ceiling(logical * DeviceDpi / 96f * testLayoutScale);
    static Font MacFont(float points, FontStyle style = FontStyle.Regular) => new("Segoe UI", points * .75f, style);
    static Label MacLabel(string text, float size = 13, bool bold = false) => new() { Text = text, AutoSize = true, Font = MacFont(size, bold ? FontStyle.Bold : FontStyle.Regular), ForeColor = StudioTheme.Ink, Margin = new Padding(0, 5, 7, 0) };
    static StudioSurface MacPanel() => new() { Dock = DockStyle.Fill, Padding = new Padding(14, 12, 14, 12), BackColor = StudioTheme.Canvas, Margin = Padding.Empty };
    static FlowLayoutPanel MacRow(bool wrap = false) => new() { Dock = DockStyle.Fill, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, WrapContents = wrap, Margin = Padding.Empty, Padding = Padding.Empty };
    void BuildMacUI()
    {
        var root = Grid(1, 4); root.RowStyles.Add(new RowStyle(SizeType.AutoSize)); root.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); root.RowStyles.Add(new RowStyle(SizeType.Absolute, 28)); Controls.Add(root);
        root.Controls.Add(BuildMacMenus(), 0, 0);
        var header = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(233, 233, 233), Margin = Padding.Empty };
        var project = MacLabel("Composition Lab · Composition Engine 2.3.1 · Build 231", 15, true); project.AutoSize = false; project.AutoEllipsis = true; header.Controls.Add(project);
        var navigation = MacRow(); navigation.Dock = DockStyle.None; navigation.Size = new Size(408, 34); navigation.WrapContents = false;
        foreach (string label in new[] { "Main", "Noten", "Technik" })
        { int index = navButtons.Count; var button = new StudioButton { Text = label, Width = 126, Height = 28, AutoSize = false, Selected = index == 0 }; button.Click += (_, _) => tabs.SelectedIndex = index; navButtons.Add(button); navigation.Controls.Add(button); }
        header.Controls.Add(navigation);
        void ArrangeHeader()
        {
            int left = Math.Max(LayoutPixels(16), header.ClientSize.Width - navigation.Width - LayoutPixels(16));
            navigation.Location = new Point(left, Math.Max(0, (header.ClientSize.Height - navigation.Height) / 2));
            project.Bounds = new Rectangle(LayoutPixels(16), 0, Math.Max(0, left - LayoutPixels(32)), header.ClientSize.Height);
            project.TextAlign = ContentAlignment.MiddleLeft;
        }
        header.Layout += (_, _) => ArrangeHeader();
        // Keep navigation fixed; long application titles ellipsize without scrolling the header.
        header.AutoScroll = false;
        tabs.SelectedIndexChanged += (_, _) => { for (int i = 0; i < 3; i++) { navButtons[i].Selected = tabs.SelectedIndex == i; navButtons[i].Invalidate(); } if (IsHandleCreated) navButtons[tabs.SelectedIndex].Focus(); };
        root.Controls.Add(header, 0, 1);
        tabs.AddPage(BuildMacMain()); tabs.AddPage(BuildMacNotation()); tabs.AddPage(BuildMacTechnology()); root.Controls.Add(tabs, 0, 2);
        var strip = new StatusStrip { Dock = DockStyle.Fill, BackColor = Color.FromArgb(233, 233, 233), SizingGrip = true }; strip.Items.Add(status); strip.Items.Add(cost); root.Controls.Add(strip, 0, 3);
        slots.SelectedIndexChanged += async (_, _) => { if (!refreshingSlots) { RefreshCards(); await DisplayCurrentAsync(); } };
        send.Text = "Senden"; send.Click += async (_, _) => await RequestAIAsync(false);
        compose.Text = "Mit gewählter KI komponieren"; compose.Click += async (_, _) => await RequestAIAsync(true);
        cancel.Click += (_, _) => pending?.Cancel();
        composition.ReadOnly = false; composition.Font = MacFont(13);
        composition.TextChanged += (_, _) => { if (!loadingIdea) { editableIdea = composition.Text; assignment.Text = editableIdea; SaveLocalState(); } };
        chatInput.KeyDown += async (_, e) => { if (e.KeyCode == Keys.Enter && e.Control) { e.SuppressKeyPress = true; await RequestAIAsync(false); } };
        guiChecks.AddRange([chatInput, compose, provider, model, effort, measures, meter, tempo, musicalKey, ensemble]);
        assignment.Text = "Komponiere ein eigenständiges Klavierstück mit einer tragenden musikalischen Idee.";
    }
    Control ScrollWorkspace(Control content, int width, int height, bool fitWidth = false)
    {
        var scroll = new WorkspacePanel { Dock = DockStyle.Fill, AutoScroll = true, BackColor = StudioTheme.Canvas };
        content.Location = Point.Empty; content.Dock = DockStyle.None; scroll.Controls.Add(content);
        bool sizing = false;
        void SizeContent()
        {
            if (sizing || scroll.ClientSize.Width <= 0 || scroll.ClientSize.Height <= 0) return;
            sizing = true;
            try
            {
                // ClientSize already excludes visible scrollbars; subtracting them again
                // introduces an extra size change when a workspace becomes visible.
                var size = new Size(fitWidth ? scroll.ClientSize.Width : Math.Max(LayoutPixels(width), scroll.ClientSize.Width), Math.Max(LayoutPixels(height), scroll.ClientSize.Height));
                if (content.Size != size) content.Size = size;
            }
            finally { sizing = false; }
        }
        scroll.Resize += (_, _) => SizeContent(); scroll.DpiChangedAfterParent += (_, _) => SizeContent(); SizeContent(); return scroll;
    }
    Control BuildMacMain()
    {
        var main = Grid(1, 4); main.Padding = new Padding(0, 18, 0, 18);
        main.RowStyles.Add(new RowStyle(SizeType.AutoSize)); main.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        main.RowStyles.Add(new RowStyle(SizeType.Absolute, 172)); main.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        var controls = MacPanel(); var row = MacRow(true); row.Dock = DockStyle.None;
        provider.Items.AddRange(["Google / Gemini", "Anthropic / Claude", "OpenAI"]); effort.Items.AddRange(["Sparsam – Low", "Standard – Medium", "Maximum – High"]); effort.SelectedIndex = 1;
        provider.Width = 130; model.Width = 148; effort.Width = 140;
        foreach (var choice in new[] { provider, model, effort })
        {
            choice.FontChanged += (_, _) => FitChoices(choice);
            choice.DpiChangedAfterParent += (_, _) => FitChoices(choice);
            FitChoices(choice);
        }
        provider.SelectedIndexChanged += (_, _) => ProviderChanged();
        row.Controls.Add(MacLabel("KI", 12, true)); row.Controls.Add(provider); row.Controls.Add(model); row.Controls.Add(effort);
        var rightParameters = MacRow(true); rightParameters.Dock = DockStyle.None;
        rightParameters.Controls.Add(MacLabel("Takte")); measures.Width = 62; measures.Items.AddRange(new object[] { "2", "4", "8", "16", "24", "32", "48", "64" }); measures.HandleCreated += (_, _) => NativeCue.SendMessage(measures.Handle, 0x1703, new IntPtr(1), "24"); rightParameters.Controls.Add(measures); rightParameters.Controls.Add(meter);
        rightParameters.Controls.Add(MacLabel("Tempo")); tempo.Width = 58; tempo.PlaceholderText = "96"; rightParameters.Controls.Add(tempo);
        rightParameters.Controls.Add(MacLabel("Tonart")); musicalKey.Width = 86; musicalKey.PlaceholderText = "C-Dur"; rightParameters.Controls.Add(musicalKey);
        rightParameters.Controls.Add(MacLabel("Instrumente")); ensemble.Width = 150; ensemble.PlaceholderText = "Piano"; rightParameters.Controls.Add(ensemble);
        var parameterLayout = MacRow(true);
        foreach (var child in row.Controls.Cast<Control>().ToArray()) parameterLayout.Controls.Add(child);
        foreach (var child in rightParameters.Controls.Cast<Control>().ToArray()) parameterLayout.Controls.Add(child);
        controls.Controls.Add(parameterLayout); controls.Margin = new Padding(0, 0, 0, 14); main.Controls.Add(controls, 0, 0);
        var work = new SplitContainer { Dock = DockStyle.Fill, Size = new Size(1000, 400), Orientation = Orientation.Vertical,
            SplitterWidth = 10, BackColor = StudioTheme.Line, Margin = new Padding(0, 0, 0, 14) };
        mainSplit = work; work.Panel1.BackColor = work.Panel2.BackColor = StudioTheme.Canvas;
        work.Resize += (_, _) => ArrangeMainSplit();
        work.SplitterMoving += (_, _) => mainSplitDragging = true;
        work.SplitterMoved += (_, _) =>
        {
            if (!mainSplitDragging) return;
            mainSplitDragging = false;
            if (!mainSplitReady || arrangingSplit || loadingSettings || !work.IsHandleCreated) return;
            int available = work.Width - work.SplitterWidth;
            if (available > 0) { mainSplitRatio = (double)work.SplitterDistance / available; SaveLocalState(); }
        };
        slotTips.SetToolTip(work, "Trennlinie ziehen: MusicChat und Kompositionsidee in der Breite anpassen.");
        var chatPanel = MacPanel(); chatPanel.Margin = new Padding(0, 0, 7, 0); var chatLayout = Grid(1, 3);
        chatLayout.RowStyles.Add(new RowStyle(SizeType.AutoSize)); chatLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); chatLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 112));
        chatLayout.Controls.Add(MacLabel("MusicChat", 20, true), 0, 0); chat.BorderStyle = BorderStyle.FixedSingle; chat.Font = MacFont(13); chatLayout.Controls.Add(chat, 0, 1);
        var input = Grid(2, 1); input.ColumnStyles.Clear(); input.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100)); input.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 100)); input.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); input.Padding = new Padding(0, 10, 0, 0);
        chatInput.Dock = DockStyle.Fill; chatInput.Font = MacFont(13); chatInput.Multiline = true; input.Controls.Add(chatInput, 0, 0); send.Dock = DockStyle.Fill; send.AutoSize = false; input.Controls.Add(send, 1, 0);
        chatLayout.Controls.Add(input, 0, 2); chatPanel.Controls.Add(chatLayout); work.Panel1.Controls.Add(chatPanel);
        var ideaPanel = MacPanel(); ideaPanel.Margin = new Padding(7, 0, 0, 0); var idea = Grid(1, 2); idea.RowStyles.Add(new RowStyle(SizeType.AutoSize)); idea.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        idea.Controls.Add(MacLabel("Aktuelle Kompositionsidee", 16, true), 0, 0); composition.BorderStyle = BorderStyle.FixedSingle; idea.Controls.Add(composition, 0, 1); ideaPanel.Controls.Add(idea); work.Panel2.Controls.Add(ideaPanel); main.Controls.Add(work, 0, 1);
        var deck = MacPanel(); deck.Padding = new Padding(7, 5, 7, 5); deck.Margin = new Padding(0, 0, 0, 14);
        var dl = Grid(1, 2); dl.RowStyles.Add(new RowStyle(SizeType.AutoSize)); dl.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); dl.Controls.Add(MacLabel("Stücke (1–10)", 14, true), 0, 0);
        // Ten equal columns always fit the viewport; the buttons have no scroll host.
        var cards = Grid(10, 1); cards.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        for (int i = 0; i < 10; i++)
        {
            int index = i; var card = new PieceCard { Number = i + 1, Dock = DockStyle.Fill, MaximumSize = new Size(0, 100), AutoSize = false, Margin = new Padding(3), Font = MacFont(12), AllowDrop = true };
            card.Click += (_, _) => { if (!busy) slots.SelectedIndex = index; };
            card.DragEnter += (_, e) => e.Effect = !busy && e.Data?.GetDataPresent(DataFormats.FileDrop) == true ? DragDropEffects.Copy : DragDropEffects.None;
            card.DragDrop += async (_, e) => { if (!busy && e.Data?.GetData(DataFormats.FileDrop) is string[] paths && paths.Length == 1) await GuardAsync(() => ImportIntoSlotAsync(paths[0], index)); };
            var menu = new ContextMenuStrip(); menu.Items.Add("MIDI-Datei laden …", null, async (_, _) => await GuardAsync(() => OpenAsync(index)));
            menu.Items.Add("CLAB-Datei laden …", null, async (_, _) => await GuardAsync(() => OpenAsync(index))); menu.Items.Add(new ToolStripSeparator()); menu.Items.Add("Stück löschen", null, async (_, _) => await DeleteSlotAsync(index)); card.ContextMenuStrip = menu;
            slotCards.Add(card); cards.Controls.Add(card, i, 0);
        }
        dl.Controls.Add(cards, 0, 1); deck.Controls.Add(dl); main.Controls.Add(deck, 0, 2);
        var bottom = MacPanel(); bottom.Padding = new Padding(8, 5, 8, 5); var bl = Grid(1, 2); bl.RowStyles.Add(new RowStyle(SizeType.Absolute, 34)); bl.RowStyles.Add(new RowStyle(SizeType.Absolute, 34)); var playerRow = BuildTransport(false); bl.Controls.Add(playerRow, 0, 0);
        var actions = MacRow(true); AddButton(actions, "MIDI sichern", () => ExportAsync("mid")); AddButton(actions, "CLAB sichern", SaveDocumentAsync); AddButton(actions, "CLAB laden …", () => OpenAsync());
        actions.Controls.Add(new Panel { Width = 22, Height = 1 }); AddButton(actions, "Import …", () => OpenAsync(slots.SelectedIndex)); AddButton(actions, "Motiv …", PrepareMotif);
        actions.Controls.Add(compose); bl.Controls.Add(actions, 0, 1); bottom.Controls.Add(bl); main.Controls.Add(bottom, 0, 3);
        static void SetRow(RowStyle row, int height)
        {
            if (row.SizeType != SizeType.Absolute) row.SizeType = SizeType.Absolute;
            if (Math.Abs(row.Height - height) > .5f) row.Height = height;
        }
        bool sizingRows = false;
        main.Layout += (_, _) =>
        {
            if (sizingRows || main.Width <= 0) return;
            sizingRows = true; main.SuspendLayout(); bl.SuspendLayout();
            try
            {
                int parameterWidth = Math.Max(1, main.ClientSize.Width - main.Padding.Horizontal - controls.Padding.Horizontal);
                int parameterHeight = parameterLayout.GetPreferredSize(new Size(parameterWidth, 0)).Height;
                SetRow(main.RowStyles[0], parameterHeight + controls.Padding.Vertical + controls.Margin.Vertical);
                int actionWidth = Math.Max(1, main.ClientSize.Width - main.Padding.Horizontal - bottom.Padding.Horizontal);
                int playerHeight = playerRow.GetPreferredSize(new Size(actionWidth, 0)).Height;
                int actionHeight = actions.GetPreferredSize(new Size(actionWidth, 0)).Height;
                SetRow(bl.RowStyles[0], playerHeight); SetRow(bl.RowStyles[1], actionHeight);
                SetRow(main.RowStyles[3], playerHeight + actionHeight + bottom.Padding.Vertical + bottom.Margin.Vertical);
            }
            finally { bl.ResumeLayout(true); main.ResumeLayout(true); sizingRows = false; }
        };
        return ScrollWorkspace(main, 0, 850, fitWidth: true);
    }
    Control BuildTransport(bool notation)
    {
        var transport = new Transport(); transports.Add(transport); var row = MacRow(true);
        var play = AddButton(row, "▶", PlayAsync); play.AutoSize = false; play.Size = new Size(36, 26);
        var stop = AddButton(row, "■", () => { player.Stop(); return Task.CompletedTask; }); stop.AutoSize = false; stop.Size = new Size(36, 26); row.Controls.Add(transport.Loop); row.Controls.Add(transport.Time); row.Controls.Add(transport.Position);
        row.Controls.Add(MacLabel("Tempo")); row.Controls.Add(transport.Tempo); row.Controls.Add(MacLabel("Lautstärke")); row.Controls.Add(transport.Volume);
        transport.Loop.CheckedChanged += (_, _) => { loopPlaying = transport.Loop.Checked; foreach (var other in transports) if (other != transport) other.Loop.Checked = loopPlaying; };
        transport.Position.Scroll += (_, _) => { if (player.Loaded && !seekUpdating) { player.Seek(transport.Position.Value / 1000d); UpdateTransport(); } };
        transport.Tempo.KeyDown += (_, e) => { if (e.KeyCode == Keys.Enter && int.TryParse(transport.Tempo.Text, out int bpm) && bpm is >= 20 and <= 400) { playerBpm = bpm; tempoOverride = true; if (player.Loaded) player.SetTempo(bpm); foreach (var other in transports) other.Tempo.Text = bpm.ToString(); e.SuppressKeyPress = true; } };
        transport.Volume.Scroll += (_, _) => { playerVolume = transport.Volume.Value; foreach (var other in transports) other.Volume.Value = playerVolume; if (player.Loaded && !player.SetVolume(playerVolume)) SetStatus("Dieser Windows-MIDI-Treiber unterstützt keine Lautstärkeregelung.", true); };
        if (!notation) return row;
        // Native playback controls use three explicit rows. A wrapping FlowLayoutPanel
        // can report only its first row while its last slider is already on row two.
        var tempoLabel = row.Controls.Cast<Control>().OfType<Label>().First(c => c.Text == "Tempo");
        var volumeLabel = row.Controls.Cast<Control>().OfType<Label>().First(c => c.Text == "Lautstärke");
        row.Controls.Clear(); row.Dispose();
        var fixedPlayer = Grid(1, 3);
        for (int i = 0; i < 3; i++) fixedPlayer.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
        var buttons = Grid(4, 1); buttons.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        buttons.ColumnStyles.Clear(); foreach (int width in new[] { 42, 42, 68 }) buttons.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, width));
        buttons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        Control[] first = [play, stop, transport.Loop, transport.Time];
        for (int i = 0; i < first.Length; i++) { first[i].Dock = DockStyle.Fill; first[i].AutoSize = false; buttons.Controls.Add(first[i], i, 0); }
        transport.Time.TextAlign = ContentAlignment.MiddleLeft;
        var levels = Grid(4, 1); levels.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        levels.ColumnStyles.Clear(); foreach (int width in new[] { 60, 64, 94 }) levels.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, width));
        levels.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        Control[] last = [tempoLabel, transport.Tempo, volumeLabel, transport.Volume];
        for (int i = 0; i < last.Length; i++) { last[i].Dock = DockStyle.Fill; last[i].AutoSize = false; levels.Controls.Add(last[i], i, 0); }
        tempoLabel.TextAlign = volumeLabel.TextAlign = ContentAlignment.MiddleLeft;
        transport.Position.Dock = DockStyle.Fill;
        fixedPlayer.Controls.Add(buttons, 0, 0); fixedPlayer.Controls.Add(transport.Position, 0, 1); fixedPlayer.Controls.Add(levels, 0, 2);
        void SizeFixedPlayer()
        {
            int height = Math.Max(LayoutPixels(34), first.Concat(last).Append(transport.Position).Max(c => c.Font.Height + c.Margin.Vertical + LayoutPixels(8)));
            foreach (RowStyle style in fixedPlayer.RowStyles) style.Height = height;
            fixedPlayer.MinimumSize = new Size(0, 3 * height);
            int[] buttonWidths = [42, 42, 68], levelWidths = [60, 64, 94];
            for (int i = 0; i < 3; i++) { buttons.ColumnStyles[i].Width = LayoutPixels(buttonWidths[i]); levels.ColumnStyles[i].Width = LayoutPixels(levelWidths[i]); }
        }
        foreach (var control in first.Concat(last).Append(transport.Position)) control.FontChanged += (_, _) => SizeFixedPlayer();
        fixedPlayer.DpiChangedAfterParent += (_, _) => SizeFixedPlayer();
        SizeFixedPlayer(); return fixedPlayer;
    }
    async Task PlayAsync()
    {
        if (currentMidi == null) throw new InvalidOperationException("Kein Stück geladen.");
        if (!player.Loaded) player.Load(currentMidi); if (tempoOverride && playerBpm > 0) player.SetTempo(playerBpm); player.SetVolume(playerVolume); player.Play(); await Task.CompletedTask;
    }
    void UpdateTransport()
    {
        if (!player.Loaded) return; seekUpdating = true;
        try { int position = player.Position, length = player.Length; foreach (var transport in transports) { string time = FormatTime(position) + " / " + FormatTime(length); if (transport.Time.Text != time) transport.Time.Text = time; int value = length == 0 ? 0 : Math.Clamp((int)(1000d * position / length), 0, 1000); if (transport.Position.Value != value) transport.Position.Value = value; } if (loopPlaying && length > 0 && position >= length && player.Mode == "stopped") { player.Seek(0); player.Play(); } }
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
        var settings = new Panel { Dock = DockStyle.Fill, AutoScroll = true, BackColor = StudioTheme.Canvas };
        var settingsContent = Grid(1, 0); settingsContent.Dock = DockStyle.Top; settingsContent.AutoSize = true;
        settingsContent.AutoSizeMode = AutoSizeMode.GrowAndShrink; settingsContent.Padding = new Padding(16);
        void AddSetting(Control control)
        {
            int row = settingsContent.RowCount++;
            settingsContent.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            control.Dock = DockStyle.Fill;
            settingsContent.Controls.Add(control, 0, row);
        }
        settings.Controls.Add(settingsContent);
        AddSetting(MacLabel("Noten", 17, true)); AddSetting(new Label { Text = "Darstellungsquantisierung für MusicXML. Die MIDI-Daten und die Komposition bleiben unverändert.", AutoSize = true, MaximumSize = new Size(264, 0), ForeColor = StudioTheme.Muted, Font = MacFont(12) });
        var quantizationTitle = MacLabel("Quantisierung", 17, true); quantizationTitle.MaximumSize = new Size(264, 0); AddSetting(quantizationTitle);
        string[] titles = ["Preset", "Rhythmusmodus", "Kleinster gerader Notenwert", "Kleinster triolischer Notenwert", "Kurze Pausen", "Notenlängen glätten", "Mini-Pausen am Taktanfang", "Darstellung", "Splitpunkt"];
        string[][] choices = [["Klavier – lesbar", "MIDI-nah", "Benutzerdefiniert"], ["Auto", "Gerade", "Triolisch"], ["Aus", "Viertel", "Achtel", "16tel", "32tel", "64tel"], ["Aus", "Vierteltriolen", "Achteltriolen", "16teltriolen", "32teltriolen"], ["Alle Pausen zeigen", "bis 32tel glätten", "bis 16tel glätten", "bis Achtel glätten"], ["Aus", "Leicht", "Mittel", "Stark"], ["Aus", "bis 32tel", "bis 16tel", "bis Achtel"], ["Automatisch", "Ein System", "Zwei Systeme"], ["C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]];
        updatingNotation = true;
        int[] defaults = [0, 0, 3, 3, 2, 3, 2, 0, 7];
        for (int i = 0; i < 9; i++) { if (i == 7) AddSetting(MacLabel("Klaviersystem", 17, true)); AddSetting(MacLabel(titles[i], 12, true)); var control = notationSettings[i]; control.Width = 264; control.Items.AddRange(choices[i]); control.SelectedIndex = defaults[i]; int index = i; control.SelectedIndexChanged += async (_, _) => await NotationChangedAsync(index); AddSetting(control); }
        AddSetting(MacLabel("Notenwerte", 17, true)); AddSetting(splitBeats); splitBeats.CheckedChanged += async (_, _) => await NotationChangedAsync(-1); updatingNotation = false;
        page.Controls.Add(settings, 0, 0);
        var right = Grid(1, 6); right.Padding = new Padding(14, 12, 14, 12); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 62)); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 48)); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 30)); right.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 0)); right.RowStyles.Add(new RowStyle(SizeType.Absolute, 36));
        var deck = Grid(1, 2); deck.RowStyles.Add(new RowStyle(SizeType.AutoSize)); deck.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); deck.Controls.Add(MacLabel("Stücke / Varianten", 17, true), 0, 0);
        var numbers = Grid(10, 1); numbers.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        for (int i = 0; i < 10; i++) { int index = i; var button = new StudioButton { Text = (i + 1).ToString(), Dock = DockStyle.Fill, AutoSize = false, Padding = Padding.Empty }; button.Click += (_, _) => { if (!busy) slots.SelectedIndex = index; }; notationCards.Add(button); numbers.Controls.Add(button, i, 0); } deck.Controls.Add(numbers, 0, 1); right.Controls.Add(deck, 0, 0);
        var transport = MacPanel(); transport.Padding = new Padding(10, 6, 10, 6); var notationPlayer = BuildTransport(true); notationPlayer.AutoSize = false; notationTransport = transport; transport.Controls.Add(notationPlayer); right.Controls.Add(transport, 0, 1);
        var previewHeader = Grid(2, 1); previewHeader.ColumnStyles.Clear(); previewHeader.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 55)); previewHeader.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 45)); previewHeader.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        var title = new Label { Text = "Notenbildvorschau", Dock = DockStyle.Fill, AutoEllipsis = true, Font = MacFont(17, FontStyle.Bold) }; notationCurrent.Dock = DockStyle.Fill; notationCurrent.TextAlign = ContentAlignment.MiddleRight; previewHeader.Controls.Add(title, 0, 0); previewHeader.Controls.Add(notationCurrent, 1, 0); right.Controls.Add(previewHeader, 0, 2);
        var preview = Grid(1, 2); preview.RowStyles.Add(new RowStyle(SizeType.Absolute, 36)); preview.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        var previewTools = MacRow(true);
        var enlarge = new StudioButton { Text = "Große Ansicht", AutoSize = true };
        enlarge.Click += (_, _) => toggleLargePreview?.Invoke(); previewTools.Controls.Add(enlarge);
        AddButton(previewTools, "◀", () => PreviewCommand("page(-1)")); previewTools.Controls.Add(previewPage); AddButton(previewTools, "▶", () => PreviewCommand("page(1)")); AddButton(previewTools, "−", () => PreviewCommand("zoom(-10)")); previewTools.Controls.Add(previewZoom); AddButton(previewTools, "+", () => PreviewCommand("zoom(10)")); AddButton(previewTools, "Aktualisieren", RefreshNotationAsync); AddButton(previewTools, "Drucken …", () => { if (webReady) web.CoreWebView2.ShowPrintUI(Microsoft.Web.WebView2.Core.CoreWebView2PrintDialogKind.Browser); return Task.CompletedTask; });
        preview.Controls.Add(previewTools, 0, 0); notationHost.Controls.Add(web); preview.Controls.Add(notationHost, 0, 1); right.Controls.Add(preview, 0, 3); notationSummary.Text = "Darstellungsregeln · Klavier – lesbar"; notationSummary.Visible = false; right.Controls.Add(notationSummary, 0, 4);
        var exports = MacRow(); exports.Controls.Add(MacLabel("Export", 12, true)); var export = new StudioButton { Text = "MusicXML sichern / ziehen …", AutoSize = true }; export.Click += async (_, _) => await GuardAsync(() => ExportAsync("musicxml")); Point dragStart = Point.Empty; export.MouseDown += (_, e) => dragStart = e.Location; export.MouseMove += async (_, e) => { if (e.Button != MouseButtons.Left || Math.Abs(e.X - dragStart.X) + Math.Abs(e.Y - dragStart.Y) < 10 || Score == null) return; dragStart = e.Location; await GuardAsync(async () => { var result = await core.RunAsync(new JsonObject { ["operation"] = "musicxml", ["score"] = Score.DeepClone(), ["options"] = notationOptions?.DeepClone() }); string path = Path.Combine(Path.GetTempPath(), Guid.NewGuid() + ".musicxml"); await File.WriteAllBytesAsync(path, Convert.FromBase64String(result["data"]!.GetValue<string>())); export.DoDragDrop(new DataObject(DataFormats.FileDrop, new[] { path }), DragDropEffects.Copy); }); }; exports.Controls.Add(export); right.Controls.Add(exports, 0, 5); page.Controls.Add(right, 1, 0);
        // The browser remains in a fixed viewport: only the score itself scrolls.
        bool arranging = false, flowRowsPending = false;
        void ArrangeNotation()
        {
            if (arranging || right.ClientSize.Width <= 0) return;
            bool compact = largePreview;
            bool shortWindow = page.ClientSize.Height < LayoutPixels(550);
            arranging = true; page.SuspendLayout(); right.SuspendLayout(); preview.SuspendLayout();
            try
            {
                int sidebar = compact ? 0 : Math.Min(LayoutPixels(280), Math.Max(0, page.ClientSize.Width * 2 / 5));
                page.ColumnStyles[0].Width = sidebar;
                settings.Visible = !compact;
                deck.Visible = !compact && !shortWindow;
                transport.Visible = true;
                previewHeader.Visible = exports.Visible = !compact && !shortWindow;
                right.RowStyles[0].Height = compact || shortWindow ? 0 : LayoutPixels(62);
                right.RowStyles[1].Height = notationPlayer.GetPreferredSize(new Size(Math.Max(1, right.ClientSize.Width - right.Padding.Horizontal - transport.Padding.Horizontal), 0)).Height + transport.Padding.Vertical;
                right.RowStyles[2].Height = compact || shortWindow ? 0 : LayoutPixels(30);
                right.RowStyles[5].Height = compact || shortWindow ? 0 : exports.GetPreferredSize(new Size(Math.Max(1, right.ClientSize.Width - right.Padding.Horizontal), 0)).Height;
                preview.RowStyles[0].Height = previewTools.GetPreferredSize(new Size(Math.Max(1, right.ClientSize.Width - right.Padding.Horizontal), 0)).Height;
                int settingWidth = Math.Max(1, settingsContent.ClientSize.Width - settingsContent.Padding.Horizontal);
                splitBeats.Height = Math.Max(LayoutPixels(50), TextRenderer.MeasureText(splitBeats.Text, splitBeats.Font,
                    new Size(Math.Max(1, settingWidth - splitBeats.Margin.Horizontal - LayoutPixels(24)), 0), TextFormatFlags.WordBreak).Height + LayoutPixels(12));
                foreach (Control control in settingsContent.Controls)
                {
                    int available = Math.Max(1, settingWidth - control.Margin.Horizontal);
                    control.MaximumSize = new Size(available, 0);
                    if (control is Label label) { label.AutoSize = true; label.AutoEllipsis = false; }
                    if (!control.AutoSize) control.Width = available;
                    if (control is ComboBox sizedCombo)
                    {
                        sizedCombo.MinimumSize = new Size(0, sizedCombo.PreferredHeight);
                        sizedCombo.Height = sizedCombo.PreferredHeight;
                    }
                    // A native ComboBox enforces PreferredHeight even when the table's
                    // AutoSize calculation uses its old DPI height. Reserve the actual
                    // text/control height explicitly so adjacent rows cannot overlap.
                    int height = control is ComboBox combo ? combo.PreferredHeight : control is Label
                        ? control.GetPreferredSize(new Size(available, 0)).Height : control.Height;
                    var style = settingsContent.RowStyles[settingsContent.GetRow(control)];
                    style.SizeType = SizeType.Absolute; style.Height = height + control.Margin.Vertical;
                }
            }
            finally { preview.ResumeLayout(true); right.ResumeLayout(true); page.ResumeLayout(true); arranging = false; FitFlowRow(previewTools, preview.RowStyles[0]); FitFlowRow(notationPlayer, right.RowStyles[1], transport.Padding.Vertical); if (!compact) FitFlowRow(exports, right.RowStyles[5]); ScheduleFlowRows(); }
        }
        void FitFlowRow(Control flow, RowStyle style, int padding = 0)
        {
            if (flow.ClientSize.Width <= 0 || !flow.Visible) return;
            int needed = flow.Controls.Cast<Control>().Where(c => c.Visible).Select(c => c.Top + Math.Max(c.Height, c.ClientSize.Height) + c.Margin.Bottom).DefaultIfEmpty(0).Max() + padding;
            if (Math.Abs(style.Height - needed) > .5f) style.Height = needed;
        }
        void ScheduleFlowRows()
        {
            if (flowRowsPending || !page.IsHandleCreated || page.IsDisposed) return;
            flowRowsPending = true;
            page.BeginInvoke((Action)(() =>
            {
                flowRowsPending = false;
                if (page.IsDisposed || !page.Visible) return;
                // Layout events precede the flow engine's final child positions.
                // Measure those positions on the next message-loop turn.
                FitFlowRow(notationPlayer, right.RowStyles[1], transport.Padding.Vertical);
                FitFlowRow(previewTools, preview.RowStyles[0]);
                if (exports.Visible) FitFlowRow(exports, right.RowStyles[5]);
            }));
        }
        notationPlayer.Layout += (_, _) => ScheduleFlowRows();
        previewTools.Layout += (_, _) => ScheduleFlowRows();
        exports.Layout += (_, _) => ScheduleFlowRows();
        previewTools.Layout += (_, _) => FitFlowRow(previewTools, preview.RowStyles[0]);
        notationPlayer.Layout += (_, _) => FitFlowRow(notationPlayer, right.RowStyles[1], transport.Padding.Vertical);
        exports.Layout += (_, _) => { if (!largePreview) FitFlowRow(exports, right.RowStyles[5]); };
        toggleLargePreview = () => { largePreview = !largePreview; enlarge.Text = largePreview ? "Normale Ansicht" : "Große Ansicht"; ArrangeNotation(); };
        page.SizeChanged += (_, _) => ArrangeNotation();
        page.VisibleChanged += (_, _) => { if (page.Visible) ArrangeNotation(); };
        bool notationLayoutPending = false;
        void ScheduleNotationLayout()
        {
            if (notationLayoutPending || !page.IsHandleCreated || page.IsDisposed) return;
            notationLayoutPending = true;
            page.BeginInvoke((Action)(() => { notationLayoutPending = false; if (!page.IsDisposed && page.Visible) ArrangeNotation(); }));
        }
        page.VisibleChanged += (_, _) => ScheduleNotationLayout();
        settingsContent.SizeChanged += (_, _) => ScheduleNotationLayout();
        foreach (Control control in settingsContent.Controls) control.FontChanged += (_, _) => ScheduleNotationLayout();
        page.DpiChangedAfterParent += (_, _) => ScheduleNotationLayout();
        right.SizeChanged += (_, _) => ArrangeNotation();
        var viewport = new WorkspacePanel { Dock = DockStyle.Fill, AutoScroll = false, BackColor = StudioTheme.Canvas };
        viewport.Controls.Add(page); return viewport;
    }
    async Task PreviewCommand(string javascript) { if (webReady) await web.ExecuteScriptAsync(javascript); }
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
        var options = new JsonObject { ["startGrid"] = 0, ["shortRestThreshold"] = rest[notationSettings[4].SelectedIndex], ["occupancyThreshold"] = occupancy[notationSettings[5].SelectedIndex], ["durationTolerance"] = tolerance[notationSettings[5].SelectedIndex], ["minimumNoteValue"] = null, ["rhythmMode"] = new[] { "auto", "straight", "triplet" }[notationSettings[1].SelectedIndex], ["minimumStraightNoteValue"] = straight[notationSettings[2].SelectedIndex], ["minimumTripletNoteValue"] = triplet[notationSettings[3].SelectedIndex], ["barStartSnapThreshold"] = rest[notationSettings[6].SelectedIndex], ["splitAtBeatBoundaries"] = splitBeats.Checked, ["pianoStaffMode"] = new[] { "auto", "single", "two" }[notationSettings[7].SelectedIndex], ["pianoSplitPoint"] = split[notationSettings[8].SelectedIndex] };
        if (notationSettings[0].SelectedIndex == 0) { options["startGrid"] = .25; options["durationTolerance"] = .21; }
        else if (notationSettings[0].SelectedIndex == 1) options["durationTolerance"] = .02;
        return options;
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
        var pages = new TabControl { Dock = DockStyle.Fill }; foreach (var pair in new[] { ("Technische Prüfung", (Control)validation), ("JSON", (Control)scoreJSON), ("Verlauf", BuildHistory()) }) { var tab = new TabPage(pair.Item1); tab.Controls.Add(pair.Item2); pages.TabPages.Add(tab); } page.Controls.Add(pages, 0, 3);
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
        Action(edit, "Rückgängig", () => { if (ActiveControl is TextBoxBase text) text.Undo(); return Task.CompletedTask; }); Action(edit, "Wiederholen", () => { if (ActiveControl is RichTextBox text && text.CanRedo) text.Redo(); return Task.CompletedTask; }); Action(edit, "Ausschneiden", () => { if (ActiveControl is TextBoxBase text) text.Cut(); return Task.CompletedTask; }); Action(edit, "Kopieren", () => { if (ActiveControl is TextBoxBase text) text.Copy(); return Task.CompletedTask; }); Action(edit, "Einsetzen", () => { if (ActiveControl is TextBoxBase text) text.Paste(); return Task.CompletedTask; }); Action(edit, "Alles auswählen", () => { if (ActiveControl is TextBoxBase text) text.SelectAll(); return Task.CompletedTask; });
        var compositionMenu = new ToolStripMenuItem("Komposition"); menu.Items.Add(compositionMenu); Action(compositionMenu, "Mit gewählter KI komponieren", () => RequestAIAsync(true)); Action(compositionMenu, "Fertige Komposition übernehmen", RecoverDisplayedMusicAsync); Action(compositionMenu, "Anfrage abbrechen", () => { pending?.Cancel(); return Task.CompletedTask; });
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
        loadingSettings = true; activeProvider = settings["provider"]?.GetValue<string>() ?? activeProvider; if (!models.ContainsKey(activeProvider)) activeProvider = "anthropic"; provider.SelectedIndex = activeProvider switch { "openai" => 2, "gemini" => 0, _ => 1 }; SelectModel(); apiKey.Text = keys.GetValueOrDefault(activeProvider, ""); remember.Checked = keys.ContainsKey(activeProvider); loadingSettings = false;
        pieceHistory.Clear(); if (project["history"] is JsonArray history) foreach (var item in history.OfType<JsonObject>()) { var doc = CreateDocument(item["score"]!.DeepClone().AsObject(), item["concept"]?.GetValue<string>() ?? ""); foreach (var field in new[] { "title", "provider", "model", "costUSD", "inputTokens", "outputTokens" }) if (item[field] != null) doc[field] = item[field]!.DeepClone(); pieceHistory.Add(doc); } RefreshHistory();
        Array.Copy(imported, documents, 10); projectName = project["name"]?.GetValue<string>() ?? "Unbenannt"; chat.Text = project["chat"]?.GetValue<string>() ?? ""; composition.Text = project["concept"]?.GetValue<string>() ?? settings["prompt"]?.GetValue<string>() ?? ""; RefreshSlots(); slots.SelectedIndex = Math.Clamp(project["activeSlot"]?.GetValue<int>() ?? 0, 0, 9); await DisplayCurrentAsync(); SaveLocalState();
    }
}

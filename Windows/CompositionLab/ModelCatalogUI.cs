using System.Net.Http;
using System.Text.Json;

namespace CompositionLab;

internal sealed partial class MainForm
{
    HttpClient modelsHttp = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromSeconds(30) };
    readonly Dictionary<string, ModelSnapshot> modelCatalogs = [];
    readonly Dictionary<string, int> modelLoads = [];
    bool bindingModel;
    string CatalogPath => Path.Combine(dataDirectory, "model-catalogs.json");

    void LoadModelCatalogs()
    {
        try
        {
            if (File.Exists(CatalogPath))
                foreach (var entry in JsonSerializer.Deserialize<Dictionary<string, ModelSnapshot>>(File.ReadAllText(CatalogPath)) ?? [])
                    if (models.ContainsKey(entry.Key) && entry.Value?.Models is { Count: > 0 }) modelCatalogs[entry.Key] = entry.Value;
        }
        catch (Exception e) when (e is IOException or JsonException) { SetStatus("Gespeicherte Modellliste konnte nicht gelesen werden. Bitte Modelle aktualisieren.", true); }
    }
    async Task<bool> RefreshModelsAsync(bool report = true, Action<string, bool>? feedback = null, CancellationToken cancellation = default)
    {
        string selectedProvider = activeProvider, key = apiKey.Text.Trim();
        void Report(string message, bool error = false)
        {
            feedback?.Invoke(message, error);
            if (report && !IsDisposed && activeProvider == selectedProvider) SetStatus(message, error);
        }
        if (key.Length == 0) { Report("Kein API-Schlüssel vorhanden. Über „API-Schlüssel …“ eintragen.", true); return false; }
        int generation = modelLoads.GetValueOrDefault(selectedProvider) + 1; modelLoads[selectedProvider] = generation;
        Report("Vollständige Modellliste wird geladen …");
        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellation);
            timeout.CancelAfter(TimeSpan.FromSeconds(45));
            var items = await new ModelCatalogClient(modelsHttp).ListAsync(selectedProvider, key, timeout.Token);
            if (IsDisposed || cancellation.IsCancellationRequested || modelLoads.GetValueOrDefault(selectedProvider) != generation || ProviderKey(selectedProvider) != key) return false;
            modelCatalogs[selectedProvider] = new ModelSnapshot(DateTimeOffset.UtcNow, items);
            AtomicFile.WriteText(CatalogPath, JsonSerializer.Serialize(modelCatalogs));
            if (activeProvider == selectedProvider && apiKey.Text.Trim() == key && !busy) SelectModel();
            Report(items.Count + " Modelle vollständig vom Provider geladen.");
            return true;
        }
        catch (Exception e) when (e is HttpRequestException or OperationCanceledException or InvalidOperationException or System.Text.Json.JsonException or IOException)
        {
            if (!IsDisposed && !cancellation.IsCancellationRequested && modelLoads.GetValueOrDefault(selectedProvider) == generation)
                Report(e is OperationCanceledException ? "Zeitlimit erreicht. Verbindung prüfen und erneut aktualisieren. Die bisherige Liste bleibt erhalten." :
                    e is HttpRequestException ? "Keine Verbindung zum Provider. Internetverbindung prüfen und erneut aktualisieren." : e.Message, true);
            return false;
        }
    }
    bool ShowKeyDialog(IWin32Window owner)
    {
        using var dialog = new Form { Name = "ProviderKeyDialog", Text = "API-Schlüssel · " + provider.Text,
            ClientSize = new Size(640, 245), MinimumSize = new Size(540, 280), StartPosition = FormStartPosition.CenterParent,
            MaximizeBox = false, MinimizeBox = false };
        var page = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5, Padding = new Padding(16), AutoScroll = true };
        page.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        foreach (var height in new[] { 38, 36, 32, 40 }) page.RowStyles.Add(new RowStyle(SizeType.Absolute, height));
        page.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        var input = new TextBox { Name = "ProviderKeyInput", UseSystemPasswordChar = true, Dock = DockStyle.Fill, Text = ProviderKey(activeProvider) };
        var persist = new CheckBox { Name = "RememberKey", Text = "Schlüssel verschlüsselt auf diesem PC speichern", AutoSize = true, Checked = keys.ContainsKey(activeProvider) };
        var message = new Label { Name = "KeyMessage", Dock = DockStyle.Fill, Text = "Ohne Speichern bleibt der Schlüssel für diese Sitzung verfügbar." };
        var actions = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, WrapContents = true };
        var accept = new Button { Name = "AcceptKey", Text = "Übernehmen", AutoSize = true };
        var remove = new Button { Name = "DeleteKey", Text = "Schlüssel löschen", AutoSize = true };
        var cancelKey = new Button { Text = "Abbrechen", AutoSize = true, DialogResult = DialogResult.Cancel };
        actions.Controls.AddRange([accept, remove, cancelKey]);
        page.Controls.Add(new Label { Text = "API-Schlüssel für " + provider.Text, Dock = DockStyle.Fill }, 0, 0);
        page.Controls.Add(input, 0, 1); page.Controls.Add(persist, 0, 2); page.Controls.Add(message, 0, 3); page.Controls.Add(actions, 0, 4);
        dialog.Controls.Add(page); dialog.AcceptButton = accept; dialog.CancelButton = cancelKey;
        accept.Click += (_, _) =>
        {
            if (string.IsNullOrWhiteSpace(input.Text)) { message.Text = "Bitte einen API-Schlüssel eingeben."; message.ForeColor = Color.Firebrick; input.Focus(); return; }
            try
            {
                apiKey.Text = input.Text.Trim(); remember.Checked = persist.Checked; StoreKey();
                dialog.DialogResult = DialogResult.OK;
            }
            catch (Exception e) when (e is IOException or System.Security.Cryptography.CryptographicException or UnauthorizedAccessException)
            { message.Text = "Schlüssel konnte nicht gespeichert werden: " + e.Message; }
        };
        remove.Click += (_, _) =>
        {
            try
            {
                keys.Remove(activeProvider); secrets.Save(keys); sessionKeys.Remove(activeProvider); apiKey.Clear(); remember.Checked = false;
                dialog.DialogResult = DialogResult.OK;
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { message.Text = e.Message; }
        };
        return dialog.ShowDialog(owner) == DialogResult.OK;
    }

    Task ShowModelsAsync()
    {
        using var dialog = new Form { Name = "ModelPickerDialog", Text = "Modelle · " + provider.Text, Size = new Size(850, 620), MinimumSize = new Size(640, 430), StartPosition = FormStartPosition.CenterParent };
        using var closed = new CancellationTokenSource();
        var page = Grid(1, 5); page.Padding = new Padding(12);
        page.RowStyles.Add(new RowStyle(SizeType.Absolute, 60)); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
        page.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 108)); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 76));
        var info = new Label { Name = "ModelMessage", Dock = DockStyle.Fill };
        var search = new TextBox { Name = "ModelSearch", PlaceholderText = "Modellname oder Kennung suchen …", Dock = DockStyle.Fill };
        var list = new ListBox { Name = "ModelList", Dock = DockStyle.Fill, IntegralHeight = false, HorizontalScrollbar = true };
        var details = new TextBox { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical };
        var actions = MacRow(true); var choose = new Button { Name = "ChooseModel", Text = "Modell auswählen", AutoSize = true, Enabled = false };
        var refresh = new Button { Name = "RefreshModels", Text = "Liste aktualisieren", AutoSize = true };
        var credentials = new Button { Name = "ModelCredentials", Text = "API-Schlüssel …", AutoSize = true };
        var close = new Button { Text = "Schließen", AutoSize = true, DialogResult = DialogResult.Cancel };
        actions.Controls.AddRange([choose, refresh, credentials, close]);
        page.Controls.Add(info, 0, 0); page.Controls.Add(search, 0, 1); page.Controls.Add(list, 0, 2); page.Controls.Add(details, 0, 3); page.Controls.Add(actions, 0, 4); dialog.Controls.Add(page);
        dialog.CancelButton = close;
        bool loading = false;
        void Feedback(string message, bool error)
        {
            if (dialog.IsDisposed || closed.IsCancellationRequested) return;
            info.Text = message; info.ForeColor = error ? Color.Firebrick : SystemColors.ControlText;
        }
        void Fill()
        {
            string selected = (list.SelectedItem as ModelChoice)?.Id ?? SelectedModelId;
            list.BeginUpdate(); list.Items.Clear(); details.Clear();
            if (modelCatalogs.TryGetValue(activeProvider, out var snapshot))
            {
                foreach (var item in snapshot.Models.Where(m => (m.Name + " " + m.Id).Contains(search.Text, StringComparison.OrdinalIgnoreCase)))
                    list.Items.Add(new ModelChoice(item.Id, item.Name == item.Id ? item.Id : item.Name + " · " + item.Id));
                Feedback($"{list.Items.Count} von {snapshot.Models.Count} Modellen · geladen {snapshot.LoadedAt.ToLocalTime():g}", false);
            }
            else Feedback("Noch keine Modellliste geladen. API-Schlüssel eintragen und die Liste aktualisieren.", false);
            list.EndUpdate();
            for (int i = 0; i < list.Items.Count; i++) if (((ModelChoice)list.Items[i]).Id == selected) { list.SelectedIndex = i; break; }
            if (list.SelectedIndex < 0 && list.Items.Count > 0) list.SelectedIndex = 0;
            choose.Enabled = list.SelectedIndex >= 0;
        }
        async Task Load()
        {
            if (loading || closed.IsCancellationRequested) return;
            if (apiKey.Text.Trim().Length == 0 && !ShowKeyDialog(dialog)) return;
            if (apiKey.Text.Trim().Length == 0) { Feedback("Kein API-Schlüssel vorhanden. Die gespeicherte Liste bleibt auswählbar.", true); return; }
            loading = true; refresh.Enabled = credentials.Enabled = false;
            try
            {
                bool ok = await RefreshModelsAsync(false, Feedback, closed.Token);
                if (!closed.IsCancellationRequested && ok) Fill();
            }
            finally
            {
                loading = false;
                if (!dialog.IsDisposed) refresh.Enabled = credentials.Enabled = true;
            }
        }
        void Choose()
        {
            if (list.SelectedItem is not ModelChoice choice) return;
            models[activeProvider] = choice.Id; SelectModel(); SaveLocalState(); dialog.Close();
        }
        search.TextChanged += (_, _) => { string message = info.Text; Color color = info.ForeColor; Fill(); if (loading || color == Color.Firebrick) { info.Text = message; info.ForeColor = color; } };
        list.SelectedIndexChanged += (_, _) =>
        {
            choose.Enabled = list.SelectedIndex >= 0;
            if (list.SelectedItem is ModelChoice choice && modelCatalogs.TryGetValue(activeProvider, out var snapshot))
            {
                var item = snapshot.Models.First(m => m.Id == choice.Id);
                details.Text = item.Name + "\r\n" + item.Id + "\r\n" + item.Details;
            }
        };
        choose.Click += (_, _) => Choose(); list.DoubleClick += (_, _) => Choose();
        refresh.Click += async (_, _) => await Load();
        credentials.Click += async (_, _) => { if (ShowKeyDialog(dialog)) { if (apiKey.Text.Trim().Length > 0) await Load(); else Feedback("Schlüssel gelöscht. Die gespeicherte Modellliste bleibt auswählbar.", false); } };
        dialog.Shown += async (_, _) => { if (!modelCatalogs.ContainsKey(activeProvider) && apiKey.Text.Trim().Length > 0) await Load(); };
        dialog.FormClosing += (_, _) => closed.Cancel();
        Fill(); dialog.ShowDialog(this);
        return Task.CompletedTask;
    }
}

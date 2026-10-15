using System.Net.Http;
using System.Text.Json;

namespace CompositionLab;

internal sealed partial class MainForm
{
    readonly HttpClient modelsHttp = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromSeconds(30) };
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
    async Task<bool> RefreshModelsAsync(bool report = true)
    {
        string selectedProvider = activeProvider, key = apiKey.Text.Trim();
        if (key.Length == 0) { if (report) SetStatus("Bitte zuerst den API-Schlüssel des gewählten Providers eintragen.", true); return false; }
        int generation = modelLoads.GetValueOrDefault(selectedProvider) + 1; modelLoads[selectedProvider] = generation;
        if (report) SetStatus("Vollständige Modellliste wird geladen …");
        try
        {
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(90));
            var items = await new ModelCatalogClient(modelsHttp).ListAsync(selectedProvider, key, timeout.Token);
            if (IsDisposed || modelLoads.GetValueOrDefault(selectedProvider) != generation) return false;
            modelCatalogs[selectedProvider] = new ModelSnapshot(DateTimeOffset.UtcNow, items);
            AtomicFile.WriteText(CatalogPath, JsonSerializer.Serialize(modelCatalogs));
            if (activeProvider == selectedProvider && apiKey.Text.Trim() == key && !busy) SelectModel();
            if (report && activeProvider == selectedProvider) SetStatus(items.Count + " Modelle vollständig vom Provider geladen.");
            return true;
        }
        catch (Exception e) when (e is HttpRequestException or OperationCanceledException or InvalidOperationException or System.Text.Json.JsonException or IOException)
        {
            if (!IsDisposed && report && activeProvider == selectedProvider)
                SetStatus(e is OperationCanceledException ? "Modellabfrage hat das Zeitlimit erreicht. Die bisherige Liste bleibt erhalten." : e.Message, true);
            return false;
        }
    }
    async Task ShowModelsAsync()
    {
        if (!modelCatalogs.ContainsKey(activeProvider)) await RefreshModelsAsync();
        using var dialog = new Form { Text = "Modelle · " + provider.Text, Size = new Size(850, 620), MinimumSize = new Size(580, 400), StartPosition = FormStartPosition.CenterParent };
        var page = Grid(1, 5); page.Padding = new Padding(12);
        page.RowStyles.Add(new RowStyle(SizeType.AutoSize)); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
        page.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 108)); page.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));
        var info = new Label { AutoSize = true, Dock = DockStyle.Fill };
        var search = new TextBox { PlaceholderText = "Modellname oder Kennung suchen …", Dock = DockStyle.Fill };
        var list = new ListBox { Dock = DockStyle.Fill, IntegralHeight = false, HorizontalScrollbar = true };
        var details = new TextBox { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical };
        var actions = MacRow(true); var choose = new Button { Text = "Modell auswählen", AutoSize = true }; var refresh = new Button { Text = "Liste aktualisieren", AutoSize = true };
        actions.Controls.Add(choose); actions.Controls.Add(refresh);
        page.Controls.Add(info, 0, 0); page.Controls.Add(search, 0, 1); page.Controls.Add(list, 0, 2); page.Controls.Add(details, 0, 3); page.Controls.Add(actions, 0, 4); dialog.Controls.Add(page);
        void Fill()
        {
            list.BeginUpdate(); list.Items.Clear();
            if (modelCatalogs.TryGetValue(activeProvider, out var snapshot))
            {
                foreach (var item in snapshot.Models.Where(m => (m.Name + " " + m.Id).Contains(search.Text, StringComparison.OrdinalIgnoreCase)))
                    list.Items.Add(new ModelChoice(item.Id, item.Name == item.Id ? item.Id : item.Name + " · " + item.Id));
                info.Text = $"{list.Items.Count} von {snapshot.Models.Count} Modellen · geladen {snapshot.LoadedAt.ToLocalTime():g}";
            }
            else info.Text = "Keine Provider-Liste vorhanden. API-Schlüssel prüfen und Liste aktualisieren.";
            list.EndUpdate(); choose.Enabled = list.Items.Count > 0;
        }
        void Choose()
        {
            if (list.SelectedItem is not ModelChoice choice) return;
            models[activeProvider] = choice.Id; SelectModel(); SaveLocalState(); dialog.Close();
        }
        search.TextChanged += (_, _) => Fill();
        list.SelectedIndexChanged += (_, _) =>
        {
            if (list.SelectedItem is ModelChoice choice && modelCatalogs.TryGetValue(activeProvider, out var snapshot))
            {
                var item = snapshot.Models.First(m => m.Id == choice.Id);
                details.Text = item.Name + "\r\n" + item.Id + "\r\n" + item.Details;
            }
        };
        choose.Click += (_, _) => Choose(); list.DoubleClick += (_, _) => Choose();
        refresh.Click += async (_, _) => { refresh.Enabled = false; info.Text = "Alle Modellseiten werden geladen …"; bool ok = await RefreshModelsAsync(); Fill(); if (!ok) info.Text = status.Text; refresh.Enabled = true; };
        Fill(); dialog.ShowDialog(this);
    }
}

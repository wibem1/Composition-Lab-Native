using System.Net;
using System.Net.Http;

namespace CompositionLab;

internal sealed partial class MainForm
{
    sealed class PickerStub(Func<HttpRequestMessage, Task<HttpResponseMessage>> response) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) => response(request);
    }

    async Task RunModelDialogTestsAsync(string output)
    {
        var originalHttp = modelsHttp;
        var originalKeys = new Dictionary<string, string>(keys);
        string originalModel = models["anthropic"];
        int requests = 0;
        bool reject = false;
        const string testKey = "picker-session-key-not-real";
        modelsHttp = new HttpClient(new PickerStub(async request =>
        {
            requests++;
            if (request.Headers.GetValues("x-api-key").Single() != testKey) throw new Exception("Modellauswahl verwendet falschen Schlüssel.");
            await Task.Delay(180);
            return new HttpResponseMessage(reject ? HttpStatusCode.Unauthorized : HttpStatusCode.OK)
            { Content = new StringContent(reject ? "{}" : """{"data":[{"id":"picker-model-a","display_name":"Modell A"},{"id":"picker-model-b","display_name":"Modell B"}],"has_more":false}""") };
        }));
        async Task Drive(Action<Form, int> action)
        {
            Exception? failure = null;
            int ticks = 0;
            using var timer = new System.Windows.Forms.Timer { Interval = 50 };
            timer.Tick += (_, _) =>
            {
                try
                {
                    if (++ticks > 160) throw new Exception("Modellauswahl reagiert nicht innerhalb des Testzeitlimits.");
                    var top = Application.OpenForms.Cast<Form>().LastOrDefault(f => f.Name is "ProviderKeyDialog" or "ModelPickerDialog");
                    if (top != null) action(top, ticks);
                }
                catch (Exception e)
                {
                    failure = e; timer.Stop();
                    foreach (var form in Application.OpenForms.Cast<Form>().Where(f => f.Name is "ProviderKeyDialog" or "ModelPickerDialog").Reverse().ToArray()) form.Close();
                }
            };
            timer.Start(); await ShowModelsAsync(); timer.Stop();
            if (failure != null) throw new Exception("Modell-Dialogtest: " + failure.Message, failure);
        }
        static T Find<T>(Form dialog, string name) where T : Control => WorkspaceViewState.ControlsIn(dialog).OfType<T>().Single(c => c.Name == name);
        try
        {
            keys.Clear(); sessionKeys.Clear(); apiKey.Clear(); remember.Checked = false; modelCatalogs.Clear();
            int stage = 0;
            await Drive((dialog, _) =>
            {
                if (stage == 0 && dialog.Name == "ModelPickerDialog")
                {
                    if (requests != 0 || Find<ListBox>(dialog, "ModelList").Items.Count != 0) throw new Exception("Leere Modellauswahl startet eine Abfrage ohne Schlüssel.");
                    stage = 1; Find<Button>(dialog, "ModelCredentials").PerformClick();
                }
                else if (stage == 1 && dialog.Name == "ProviderKeyDialog")
                {
                    Find<TextBox>(dialog, "ProviderKeyInput").Text = testKey;
                    stage = 2; Find<Button>(dialog, "AcceptKey").PerformClick();
                }
                else if (stage == 2 && dialog.Name == "ModelPickerDialog" && Find<ListBox>(dialog, "ModelList").Items.Count == 2)
                {
                    Find<TextBox>(dialog, "ModelSearch").Text = "model-b";
                    if (Find<ListBox>(dialog, "ModelList").Items.Count != 1) throw new Exception("Modellsuche funktioniert nicht.");
                    using var bitmap = new Bitmap(dialog.Width, dialog.Height); dialog.DrawToBitmap(bitmap, new Rectangle(Point.Empty, dialog.Size));
                    bitmap.Save(Path.Combine(output, "ModelPicker-Loaded.png"));
                    stage = 3; Find<Button>(dialog, "ChooseModel").PerformClick();
                }
            });
            if (stage != 3 || requests != 1 || SelectedModelId != "picker-model-b" || apiKey.Text != testKey || keys.Count != 0) throw new Exception("Schlüsselübernahme lädt oder wählt kein Modell.");
            provider.SelectedIndex = 2; provider.SelectedIndex = 1;
            if (apiKey.Text != testKey) throw new Exception("Sitzungsschlüssel geht beim Providerwechsel verloren.");

            // Cached models remain selectable without opening a credential dialog or making a request.
            apiKey.Clear(); sessionKeys.Clear();
            await Drive((dialog, _) =>
            {
                if (dialog.Name != "ModelPickerDialog" || requests != 1) throw new Exception("Gespeicherte Modelle verlangen unnötig einen Schlüssel.");
                Find<TextBox>(dialog, "ModelSearch").Text = "model-a";
                Find<Button>(dialog, "ChooseModel").PerformClick();
            });
            if (SelectedModelId != "picker-model-a") throw new Exception("Auswahl aus gespeichertem Katalog fehlt.");

            // A saved key is reused automatically on the first load.
            keys["anthropic"] = testKey; apiKey.Text = ProviderKey("anthropic"); remember.Checked = true; modelCatalogs.Clear();
            await Drive((dialog, _) =>
            {
                if (dialog.Name != "ModelPickerDialog") throw new Exception("Gespeicherter Schlüssel wird erneut abgefragt.");
                if (Find<ListBox>(dialog, "ModelList").Items.Count == 2) dialog.Close();
            });
            if (requests != 2) throw new Exception("Gespeicherter Schlüssel lädt die Modellliste nicht.");

            // Cancelled edits do not change the key. Provider errors stay visible inside the picker.
            stage = 0; reject = true;
            await Drive((dialog, _) =>
            {
                if (stage == 0 && dialog.Name == "ModelPickerDialog") { stage = 1; Find<Button>(dialog, "ModelCredentials").PerformClick(); }
                else if (stage == 1 && dialog.Name == "ProviderKeyDialog")
                {
                    Find<TextBox>(dialog, "ProviderKeyInput").Text = "discard-this-edit"; stage = 2; dialog.Close();
                }
                else if (stage == 2 && dialog.Name == "ModelPickerDialog")
                {
                    if (apiKey.Text != testKey) throw new Exception("Abbrechen verändert den Schlüssel.");
                    stage = 3; Find<Button>(dialog, "RefreshModels").PerformClick();
                }
                else if (stage == 3 && dialog.Name == "ModelPickerDialog" && Find<Label>(dialog, "ModelMessage").Text.Contains("HTTP 401"))
                {
                    if (Find<ListBox>(dialog, "ModelList").Items.Count != 2 || !Find<Button>(dialog, "RefreshModels").Enabled) throw new Exception("Fehler entfernt Modelle oder blockiert Wiederholung.");
                    using var bitmap = new Bitmap(dialog.Width, dialog.Height); dialog.DrawToBitmap(bitmap, new Rectangle(Point.Empty, dialog.Size));
                    bitmap.Save(Path.Combine(output, "ModelPicker-Error.png"));
                    stage = 4; dialog.Close();
                }
            });
            if (stage != 4 || requests != 3) throw new Exception("Modellfehler bleibt unsichtbar.");
        }
        finally
        {
            modelsHttp.Dispose(); modelsHttp = originalHttp;
            keys = originalKeys; secrets.Save(keys); sessionKeys.Clear(); apiKey.Text = ProviderKey(activeProvider); remember.Checked = keys.ContainsKey(activeProvider);
            modelCatalogs.Clear(); models["anthropic"] = originalModel; SelectModel();
        }
    }
}

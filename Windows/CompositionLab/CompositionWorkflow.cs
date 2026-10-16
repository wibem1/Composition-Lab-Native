using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace CompositionLab;

// Creative model request, conversion, acceptance, and busy state.
internal sealed partial class MainForm
{
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
        instruction += "\n\nNotationskorrektheit: " + PitchEncodingHint;
        var request = new JsonObject { ["assignment"] = instruction, ["provider"] = activeProvider,
            ["model"] = SelectedModelId, ["effort"] = effort.SelectedIndex switch { 0 => "low", 2 => "high", _ => "medium" } };
        string selectedProvider = activeProvider, selectedModel = SelectedModelId;
        try
        {
            StoreKey(); pending = new CancellationTokenSource(); SetBusy(true);
            chat.AppendText("Du: " + userText + "\n\n");
            SetStatus(makeMusic ? "KI komponiert …" : "KI antwortet …");
            var response = await core.RunAsync(new JsonObject { ["operation"] = makeMusic ? "compose-source" : "chat",
                ["apiKey"] = apiKey.Text.Trim(), ["request"] = request }, pending.Token,
                stage => SetStatus(stage == "technical-translation-request" ? "Technische Übertragung der fertigen Komposition …" : "KI komponiert …"));
            var result = response["result"]!.AsObject();
            lastDiagnostic = result.DeepClone().AsObject();
            lastDiagnostic["interface"] = "Windows WinForms"; lastDiagnostic["interfaceVersion"] = Version;
            UpdateDiagnostic();
            if (makeMusic)
            {
                PreservePendingComposition(result["composition"]!.GetValue<string>(), result, userText, selectedProvider, selectedModel);
                result = await TranslateExistingAsync(result["composition"]!.GetValue<string>(), request, result, pending.Token);
                var document = await AcceptCompositionAsync(result, destination, userText, selectedProvider, selectedModel);
                chat.AppendText("KI: Stück fertig: " + document["title"]?.GetValue<string>() + "\n\n");
            }
            else
            {
                string answer = result["text"]!.GetValue<string>(); chat.AppendText("KI: " + answer + "\n\n"); chatInput.Clear();
                SaveLocalState(); // Keep the full answer before any translation or slot validation can fail.
                if (ContainsFinishedMusic(answer))
                {
                    destination = Array.FindIndex(documents, d => d == null);
                    if (destination < 0) throw new InvalidOperationException("Komposition erhalten, aber alle Slots sind belegt. Einen Slot leeren und unter Komposition → Fertige Komposition übernehmen fortsetzen.");
                    PreservePendingComposition(answer, result, userText, selectedProvider, selectedModel);
                    var translated = await TranslateExistingAsync(answer, request, result, pending.Token);
                    result = translated;
                    var document = await AcceptCompositionAsync(result, destination, userText, selectedProvider, selectedModel);
                    chat.AppendText("KI: Stück übernommen in Slot " + (destination + 1) + ": " + document["title"] + "\n\n");
                    makeMusic = true;
                }
                else if (string.IsNullOrWhiteSpace(composition.Text)) composition.Text = answer;
            }
            cost.Text = "Anfrage ca. $" + result["estimatedCostUSD"]!.GetValue<double>().ToString("0.0000");
            SetMusicStatus(result, makeMusic ? "Komposition abgeschlossen." : "Antwort erhalten."); SaveLocalState();
        }
        catch (OperationCanceledException) { SetStatus("Anfrage lokal abgebrochen."); }
        catch (CoreRequestException e)
        {
            var failure = e.Diagnostic?.DeepClone().AsObject() ?? new JsonObject();
            if (pendingComposition != null) failure["sourceDiagnostic"] = pendingComposition.DeepClone();
            failure["stage"] = "post-chat-processing-failed";
            failure["processingError"] = e.Message;
            lastDiagnostic = failure; UpdateDiagnostic();
            SetStatus("KI-Antwort gespeichert, Ausgabe fehlgeschlagen: " + e.Message, true);
            SaveLocalState();
        }
        catch (Exception e)
        {
            lastDiagnostic ??= new JsonObject();
            if (pendingComposition != null) lastDiagnostic["sourceDiagnostic"] = pendingComposition.DeepClone();
            lastDiagnostic["stage"] = "post-chat-processing-failed";
            lastDiagnostic["processingError"] = e.ToString();
            UpdateDiagnostic(); SaveLocalState();
            SetStatus("KI-Antwort gespeichert, Ausgabe fehlgeschlagen: " + e.Message, true);
        }
        finally { pending?.Dispose(); pending = null; SetBusy(false); }
    }

    static bool ContainsFinishedMusic(string text)
    {
        try { return ExtractLilyPond(text).Contains(@"\score"); }
        catch (InvalidOperationException) { return false; }
    }
    async Task<JsonObject> TranslateExistingAsync(string music, JsonObject request, JsonObject source, CancellationToken token)
    {
        if (ContainsFinishedMusic(music)) return await CompileCheckedCompositionAsync(music, source, token);
        // Preserve the established translation route for other complete notation
        // formats. LilyPond itself never goes through another AI request.
        var dto = request.DeepClone().AsObject(); dto["composition"] = music;
        dto["priorInputTokens"] = source["inputTokens"]?.DeepClone() ?? JsonValue.Create(0);
        dto["priorOutputTokens"] = source["outputTokens"]?.DeepClone() ?? JsonValue.Create(0);
        dto["priorCostUSD"] = source["estimatedCostUSD"]?.DeepClone() ?? JsonValue.Create(0d);
        SetStatus("Fertige Komposition wird technisch in MIDI übertragen …");
        var response = await core.RunAsync(new JsonObject { ["operation"] = "translate-existing", ["apiKey"] = apiKey.Text.Trim(), ["request"] = dto }, token);
        var result = response["result"]!.AsObject(); lastDiagnostic = result.DeepClone().AsObject();
        lastDiagnostic["sourceDiagnostic"] = source.DeepClone(); lastDiagnostic["interfaceVersion"] = Version; UpdateDiagnostic();
        return result;
    }
    async Task<JsonObject> AcceptCompositionAsync(JsonObject result, int destination, string userText, string selectedProvider, string selectedModel)
    {
        if (destination < 0 || destination >= documents.Length || documents[destination] != null) throw new InvalidOperationException("Der Ziel-Slot ist nicht mehr frei; die fertige Komposition bleibt in der Diagnose erhalten.");
        var document = CreateDocument(result["score"]!.DeepClone().AsObject(), result["composition"]!.GetValue<string>(), userText);
        foreach (string field in new[] { "directLilyPond", "sourceMidiData", "octaveReview", "originalLilyPond" }) if (result[field] != null) document[field] = result[field]!.DeepClone();
        // Validate playback before replacing state; an invalid translation never occupies a slot.
        await core.RunAsync(new JsonObject { ["operation"] = "midi", ["score"] = document["score"]!.DeepClone() });
        document["provider"] = selectedProvider; document["model"] = selectedModel;
        document["costUSD"] = result["estimatedCostUSD"]?.DeepClone();
        document["inputTokens"] = result["inputTokens"]?.DeepClone(); document["outputTokens"] = result["outputTokens"]?.DeepClone();
        documents[destination] = document; RememberPiece(document); RefreshSlots();
        refreshingSlots = true; try { slots.SelectedIndex = destination; } finally { refreshingSlots = false; }
        // Commit the accepted slot and clear the recovery draft atomically in the saved workspace.
        pendingComposition = null;
        SaveLocalState();
        await DisplayCurrentAsync();
        return document;
    }
    void PreservePendingComposition(string music, JsonObject source, string assignmentText, string selectedProvider, string selectedModel)
    {
        pendingComposition = source.DeepClone().AsObject();
        pendingComposition["composition"] = music;
        pendingComposition["assignment"] = assignmentText;
        pendingComposition["provider"] = selectedProvider;
        pendingComposition["model"] = selectedModel;
        SaveLocalState(); // Commit the raw LilyPond before potentially failing compilation.
    }

    void SetBusy(bool value)
    {
        busy = value; compose.Enabled = !value; send.Enabled = !value; cancel.Enabled = value;
        if (modelsButton != null) modelsButton.Enabled = !value;
        provider.Enabled = !value; model.Enabled = !value; effort.Enabled = !value; apiKey.Enabled = !value;
        if (value) SetStatus("Bitte warten …");
        else { status.ForeColor = Color.Black; SelectModel(); }
    }

}

using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace CompositionLab;

// Creative model request, conversion, acceptance, and busy state.
internal sealed partial class MainForm
{
    async Task RequestAIAsync(bool makeMusic)
    {
        if (busy) return;
        if (makeMusic) assignment.Text = !string.IsNullOrWhiteSpace(chatInput.Text) ? chatInput.Text : composition.Text.Length > 0 ? composition.Text : assignment.Text;
        string inputText = makeMusic ? assignment.Text : chatInput.Text;
        if (string.IsNullOrWhiteSpace(inputText)) { SetStatus("Bitte einen Auftrag eingeben.", true); return; }
        if (!makeMusic && string.IsNullOrWhiteSpace(apiKey.Text)) { SetStatus("Bitte API-Schlüssel eingeben.", true); return; }
        int destination = -1;
        if (makeMusic)
        {
            destination = Current == null ? slots.SelectedIndex : documents.FirstFreeIndex();
            if (destination < 0) { SetStatus("Alle zehn Slots sind belegt. Bitte zuerst ein Stück speichern und einen Slot leeren.", true); return; }
        }
        string userText = inputText.Trim();
        // Preserve the musical assignment. The shared native request adds only
        // the LilyPond output contract; the exact sent prompt is diagnostic data.
        string instruction = userText;
        var request = new JsonObject { ["assignment"] = instruction, ["provider"] = activeProvider,
            ["model"] = SelectedModelId, ["effort"] = effort.SelectedIndex switch { 0 => "low", 2 => "high", _ => "medium" } };
        if (!makeMusic) { request["mode"] = "dialogue"; request["workspace"] = DialogueWorkspace(); }
        string selectedProvider = activeProvider, selectedModel = SelectedModelId;
        try
        {
            pending = new CancellationTokenSource(); SetBusy(true);
            if (makeMusic)
            {
                var built = await core.RunAsync(new JsonObject { ["operation"] = "build-assignment", ["assignment"] = instruction, ["chatInput"] = chatInput.Text, ["idea"] = composition.Text, ["source"] = compositionReference?.DeepClone(),
                    ["parameters"] = new JsonObject { ["ensemble"] = ensemble.Text, ["measures"] = measures.Text,
                        ["meter"] = meter.Text, ["tempo"] = tempo.Text, ["key"] = musicalKey.Text } }, pending.Token);
                if (built["localSource"] is JsonValue localValue && localValue.TryGetValue<string>(out var original))
                {
                    var diagnostic = new JsonObject { ["stage"] = "local-source-import", ["composition"] = original,
                        ["assignment"] = original, ["interface"] = "Windows WinForms", ["interfaceVersion"] = Version,
                        ["estimatedCostUSD"] = 0d, ["inputTokens"] = 0, ["outputTokens"] = 0,
                        ["compositionAICalls"] = 0, ["conversionAICalls"] = 0 };
                    lastDiagnostic = diagnostic.DeepClone().AsObject(); UpdateDiagnostic();
                    PreservePendingComposition(original, diagnostic, original, "", "");
                    SetStatus("Vorhandener Notentext wird lokal übernommen …");
                    var imported = await ImportAIResponseLocallyAsync(original, diagnostic, pending.Token)
                        ?? throw new InvalidOperationException("Notentext lokal nicht lesbar. Original bleibt gesichert.");
                    await AcceptCompositionAsync(imported, destination, original, "", "");
                    lastDiagnostic = imported.DeepClone().AsObject(); UpdateDiagnostic();
                    SetStatus("Notentext lokal übernommen. Keine KI-Anfrage."); SaveLocalState();
                    return;
                }
                if (string.IsNullOrWhiteSpace(apiKey.Text)) { SetStatus("Bitte API-Schlüssel eingeben.", true); return; }
                request["assignment"] = built["assignment"]!.GetValue<string>() + DialogueSourceMaterial();
            }
            StoreKey();
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
                var locallyImported = await ImportAIResponseLocallyAsync(
                    result["composition"]!.GetValue<string>(), result, pending.Token);
                if (locallyImported == null)
                {
                    chat.AppendText("KI: Vollständige Originalantwort gesichert. Das Format ist nicht lokal lesbar; keine automatische zweite KI-Anfrage.\n\n");
                    if (Current == null) composition.Text = result["composition"]!.GetValue<string>();
                    else chat.AppendText("Originalantwort: " + result["composition"]!.GetValue<string>() + "\n\n");
                    cost.Text = "Anfrage ca. $" + result["estimatedCostUSD"]!.GetValue<double>().ToString("0.0000");
                    SetStatus("Original gesichert; zur Notendarstellung ist eine ausdrücklich beauftragte Übertragung erforderlich.");
                    SaveLocalState();
                    return;
                }
                result = locallyImported;
                var document = await AcceptCompositionAsync(result, destination, userText, selectedProvider, selectedModel);
                chat.AppendText("KI: Stück fertig: " + document["title"]?.GetValue<string>() + "\n\n");
            }
            else
            {
                AcceptDialogue(result);
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

    // Only deterministic, local interpretation is allowed after the creative call.
    // Unrecognized formats remain available as exact original responses.
    async Task<JsonObject?> ImportAIResponseLocallyAsync(
        string original, JsonObject source, CancellationToken token)
    {
        var response = await core.RunAsync(new JsonObject { ["operation"] = "interpret-composition", ["source"] = original }, token);
        var interpretation = response["interpretation"]!;
        if (interpretation["kind"]?.GetValue<string>() == "lilypond")
            return await CompileCheckedCompositionAsync(original, source, token);
        if (interpretation["kind"]?.GetValue<string>() != "score") return null;
        var score = interpretation["score"]!.DeepClone().AsObject();
        var result = source.DeepClone().AsObject();
        result["score"] = score;
        result["composition"] = original;
        result["stage"] = "locally-imported";
        result["conversionAICalls"] = 0;
        return result;
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
        foreach (string field in new[] { "directLilyPond", "sourceMidiData", "octaveReview", "originalLilyPond", "reasoning" }) if (result[field] != null) document[field] = result[field]!.DeepClone();
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

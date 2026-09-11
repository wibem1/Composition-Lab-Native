from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Track how a composition request entered the pipeline so diagnostics can distinguish
# direct compose, motif, and MusicChat new-composition requests.
prop_anchor = '    private var lastDiagnostic: [String: Any]?\n'
prop_new = '    private var lastDiagnostic: [String: Any]?\n    private var nextCompositionEntryPoint: String = "compose-button"\n'
if 'nextCompositionEntryPoint' not in s:
    if prop_anchor not in s:
        raise SystemExit('V6.6.11: diagnostic property anchor not found')
    s = s.replace(prop_anchor, prop_new, 1)

# Persist the entry point in every normal composition diagnostic.
old = '            "reasoning": e.rawValue,\n            "stage": "concept-request",\n'
new = '            "reasoning": e.rawValue,\n            "entryPoint": nextCompositionEntryPoint,\n            "stage": "concept-request",\n'
if old not in s:
    raise SystemExit('V6.6.11: diagnostic entry-point anchor not found')
s = s.replace(old, new, 1)

# New-composition requests typed into MusicChat should use the exact same composition
# pipeline as the blue Compose button. Existing-score edit requests continue through
# chatPressed's score-editing JSON route.
chat_anchor = '''    @objc private func chatPressed() {\n        let msg = chatInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)\n        guard !msg.isEmpty, let score = lastScore else { return }\n'''
chat_new = '''    private func musicChatStartsNewComposition(_ text: String) -> Bool {\n        let q = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)\n        guard !q.isEmpty else { return false }\n\n        // Deliberately conservative: only explicit creation language starts a new work.\n        // Requests such as "mach den Mittelteil ruhiger" remain edits of the current score.\n        let explicitNewPhrases = [\n            "komponiere ", "komponier ", "erstelle ", "schreibe ein ", "schreib ein ",\n            "erzeuge ein ", "mach ein neues ", "mache ein neues ", "neues stück",\n            "neue komposition", "neues klavierstück", "neues motiv"\n        ]\n        if explicitNewPhrases.contains(where: { q.hasPrefix($0) || q.contains($0) }) { return true }\n\n        // English wording is useful when users or imported prompts switch language.\n        let english = ["compose a ", "compose an ", "create a new ", "write a new ", "new composition"]\n        return english.contains(where: { q.hasPrefix($0) || q.contains($0) })\n    }\n\n    @objc private func chatPressed() {\n        let msg = chatInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)\n        guard !msg.isEmpty else { return }\n\n        if musicChatStartsNewComposition(msg) || lastScore == nil {\n            appendChat("Du", msg)\n            nextCompositionEntryPoint = "musicchat-new-composition"\n            // Keep the text visible while composePressed snapshots basePrompt/diagnostics.\n            composePressed()\n            nextCompositionEntryPoint = "compose-button"\n            return\n        }\n\n        guard let score = lastScore else { return }\n'''
if chat_anchor not in s:
    raise SystemExit('V6.6.11: chatPressed start not found')
s = s.replace(chat_anchor, chat_new, 1)

# Existing chat-edit diagnostics: mark path at the beginning of a score-edit request.
edit_anchor = '''        let conceptSnapshot = lastConcept\n        appendChat("Du", msg)\n'''
edit_new = '''        let conceptSnapshot = lastConcept\n        lastDiagnostic = [\n            "format": "composition-lab-native-diagnostic",\n            "engineBuild": ComposerPrompts.engineBuild,\n            "interface": "macOS AppKit",\n            "interfaceVersion": "6.6.11",\n            "provider": p.rawValue,\n            "model": m,\n            "reasoning": e.rawValue,\n            "entryPoint": "musicchat-edit",\n            "stage": "chat-edit-request",\n            "uiMeasures": measuresField.stringValue,\n            "uiMeter": meterField.stringValue,\n            "uiTempo": tempoField.stringValue,\n            "uiKey": musicalKeyField.stringValue,\n            "uiEnsemble": ensembleField.stringValue,\n            "visibleTask": msg\n        ]\n        appendChat("Du", msg)\n'''
if edit_anchor not in s:
    raise SystemExit('V6.6.11: chat edit diagnostic anchor not found')
s = s.replace(edit_anchor, edit_new, 1)

# Store the exact edit prompt before sending it.
prompt_anchor = '''            APIClient.shared.call(provider: p, model: m, key: key, effort: e,\n                                  system: ComposerPrompts.system, user: prompt, wantJSON: true) { [weak self] result in\n'''
prompt_new = '''            if var d = lastDiagnostic {\n                d["chatEditPrompt"] = prompt\n                lastDiagnostic = d\n            }\n\n            APIClient.shared.call(provider: p, model: m, key: key, effort: e,\n                                  system: ComposerPrompts.system, user: prompt, wantJSON: true) { [weak self] result in\n'''
if prompt_anchor not in s:
    raise SystemExit('V6.6.11: chat API anchor not found')
s = s.replace(prompt_anchor, prompt_new, 1)

# Persist chat-edit failure/success response in diagnostics.
fail_anchor = '''                case .failure(let error):\n                    DispatchQueue.main.async {\n                        self?.appendChat("Fehler", error.localizedDescription)\n                        self?.status("Fehler: \\(error.localizedDescription)", good: false)\n                    }\n                case .success(let response):\n'''
fail_new = '''                case .failure(let error):\n                    DispatchQueue.main.async {\n                        if var d = self?.lastDiagnostic {\n                            d["stage"] = "chat-edit-failed"\n                            d["chatEditError"] = error.localizedDescription\n                            self?.lastDiagnostic = d\n                        }\n                        self?.appendChat("Fehler", error.localizedDescription)\n                        self?.status("Fehler: \\(error.localizedDescription)", good: false)\n                    }\n                case .success(let response):\n'''
if fail_anchor not in s:
    raise SystemExit('V6.6.11: chat result failure anchor not found')
s = s.replace(fail_anchor, fail_new, 1)

success_anchor = '''                        DispatchQueue.main.async {\n                            guard let self = self else { return }\n                            self.lastCostUSD += chatCostUSD\n'''
success_new = '''                        DispatchQueue.main.async {\n                            guard let self = self else { return }\n                            if var d = self.lastDiagnostic {\n                                d["stage"] = "chat-edit-completed"\n                                d["chatEditResponse"] = response.text\n                                d["chatEditInputTokens"] = response.inputTokens\n                                d["chatEditOutputTokens"] = response.outputTokens\n                                self.lastDiagnostic = d\n                            }\n                            self.lastCostUSD += chatCostUSD\n'''
if success_anchor not in s:
    raise SystemExit('V6.6.11: chat success UI anchor not found')
s = s.replace(success_anchor, success_new, 1)

# Motif is also a genuine new-composition entry point. Mark it before composePressed.
motif_anchor = '''        promptView.string = "Komponiere ein prägnantes musikalisches Motiv als Ausgangspunkt für eine spätere Komposition."\n        composePressed()\n'''
motif_new = '''        promptView.string = "Komponiere ein prägnantes musikalisches Motiv als Ausgangspunkt für eine spätere Komposition."\n        nextCompositionEntryPoint = "motif"\n        composePressed()\n        nextCompositionEntryPoint = "compose-button"\n'''
if motif_anchor in s:
    s = s.replace(motif_anchor, motif_new, 1)

# Fallback diagnostic should identify itself as such but use the new interface version.
s = s.replace('"interfaceVersion": "6.6.10",\n                "stage": "fallback-current-state",',
              '"interfaceVersion": "6.6.11",\n                "entryPoint": "fallback-current-state",\n                "stage": "fallback-current-state",', 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.6.11 unified MusicChat composition/edit routing and diagnostics.')

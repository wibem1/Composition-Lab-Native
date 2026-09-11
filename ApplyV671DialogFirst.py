from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# V6.7.1: MusicChat is a dialogue layer only. Sending a message must NEVER
# create or revise a score by itself. The selected model may clarify, discuss,
# compare and formulate the current composition brief. Actual score generation
# remains an explicit action of the blue Compose button.

start = s.find('    @objc private func chatPressed() {\n')
end = s.find('    private func appendChat(_ who:String,_ text:String) {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.7.1: chatPressed block not found')

new_block = r'''    @objc private func chatPressed() {
        let msg = chatInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }

        var key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            key = SessionSecrets.shared.key(for: provider)
            if !key.isEmpty { keyField.stringValue = key }
        }
        if !key.isEmpty { SessionSecrets.shared.set(key, for: provider) }
        guard !key.isEmpty else {
            status("Bitte API-Key für \(provider.displayName) eingeben.", good: false)
            return
        }

        let p = provider
        let m = model
        let e = effort
        appendChat("Du", msg)
        chatInput.stringValue = ""

        let workspace = musicChatWorkspaceContext()
        let dialoguePrompt = """
        Du bist der musikalische Gesprächspartner im MusicChat von Composition Lab.
        Dies ist AUSSCHLIESSLICH ein Dialogschritt. Erzeuge, verändere oder liefere in diesem Schritt KEINE Partitur, KEIN MIDI und KEIN MusicXML.

        Beziehe den aktuellen Nutzerbeitrag auf den gesamten Gesprächsverlauf, die oberen musikalischen Einstellungen und alle belegten Stück-Slots.

        REGELN:
        - Verwende keine Triggerwörter oder Schlüsselwortlisten. Verstehe die Bedeutung aus dem gesamten Kontext.
        - Ein ausgewählter oder belegter Slot ist nicht automatisch Ziel einer Bearbeitung.
        - Mehrere Slots können gleichzeitig verglichen, analysiert oder als musikalisches Material herangezogen werden.
        - Wenn etwas musikalisch relevant mehrdeutig ist, frage kurz und konkret nach, statt zu raten.
        - Wenn der Nutzer nur analysieren, vergleichen oder diskutieren möchte, antworte inhaltlich und formuliere keinen neuen Kompositionsauftrag.
        - Wenn sich aus dem Dialog ein hinreichend klarer Kompositionsauftrag ergibt, formuliere ihn knapp als compositionBrief. Führe ihn noch NICHT aus.
        - sourceSlots enthält nur Stücke, die der Nutzer nach dem Gesprächskontext tatsächlich als Material für die spätere Komposition verwenden will. Sonst bleibt die Liste leer.
        - Die oberen Einstellungen sind aktuelle Rahmenbedingungen, sofern der Nutzer sie im Dialog nicht ausdrücklich relativiert.

        Antworte ausschließlich als JSON:
        {
          "reply":"natürliche kurze Dialogantwort oder Rückfrage",
          "compositionBrief": null ODER "knapper, geklärter Kompositionsauftrag für den späteren Komponieren-Button",
          "sourceSlots":[1,2]
        }

        WORKSPACE-KONTEXT:
        \(workspace)

        AKTUELLER NUTZERBEITRAG:
        \(msg)
        """

        lastDiagnostic = [
            "format": "composition-lab-native-diagnostic",
            "engineBuild": ComposerPrompts.engineBuild,
            "interface": "macOS AppKit",
            "interfaceVersion": "6.7.1",
            "entryPoint": "musicchat-dialogue",
            "stage": "dialogue-request",
            "userMessage": msg,
            "workspaceContext": workspace,
            "dialoguePrompt": dialoguePrompt
        ]
        status("KI denkt im MusicChat mit …", good: true)

        APIClient.shared.call(provider: p, model: m, key: key, effort: e,
                              system: ComposerPrompts.system,
                              user: dialoguePrompt,
                              wantJSON: true) { [weak self] result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    if var d = self?.lastDiagnostic {
                        d["stage"] = "dialogue-failed"
                        d["error"] = error.localizedDescription
                        self?.lastDiagnostic = d
                    }
                    self?.appendChat("Fehler", error.localizedDescription)
                    self?.status("Fehler: \(error.localizedDescription)", good: false)
                }

            case .success(let response):
                do {
                    let data = try APIClient.shared.extractJSON(response.text)
                    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                    let reply = (object["reply"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let brief = (object["compositionBrief"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let sourceSlots = (object["sourceSlots"] as? [Any] ?? []).compactMap { value -> Int? in
                        if let n = value as? Int { return n }
                        if let n = value as? NSNumber { return n.intValue }
                        return nil
                    }.filter { $0 >= 1 && $0 <= 10 }

                    DispatchQueue.main.async {
                        guard let self else { return }

                        let answer = (reply?.isEmpty == false) ? reply! : "Ich habe den musikalischen Zusammenhang aufgenommen."
                        self.appendChat(p.displayName, answer)

                        // A clear brief becomes the assignment used later by the explicit
                        // Compose button. A mere question/discussion leaves the previous
                        // brief untouched.
                        if let brief, !brief.isEmpty {
                            self.promptView.string = brief
                            self.musicChatCompositionContextOverride = self.musicChatSourceMaterial(sourceSlots)
                            self.saveSettingsFromUI()
                        }

                        if var d = self.lastDiagnostic {
                            d["stage"] = "dialogue-completed"
                            d["dialogueResponse"] = response.text
                            d["reply"] = answer
                            d["sourceSlots"] = sourceSlots
                            if let brief, !brief.isEmpty { d["compositionBrief"] = brief }
                            d["inputTokens"] = response.inputTokens
                            d["outputTokens"] = response.outputTokens
                            self.lastDiagnostic = d
                        }
                        self.status("MusicChat-Antwort erhalten. Komponiert wird erst mit dem blauen Button.", good: true)
                    }
                } catch {
                    DispatchQueue.main.async {
                        if var d = self?.lastDiagnostic {
                            d["stage"] = "dialogue-decode-failed"
                            d["rawResponse"] = response.text
                            d["error"] = error.localizedDescription
                            self?.lastDiagnostic = d
                        }
                        self?.appendChat("Fehler", error.localizedDescription)
                        self?.status("Fehler: \(error.localizedDescription)", good: false)
                    }
                }
            }
        }
    }

'''

s = s[:start] + new_block + s[end:]

# Diagnostics exported after a dialogue should carry the current V6.7.1 version.
s = s.replace('"interfaceVersion": "6.7.0",\n                "entryPoint": "fallback-current-state",',
              '"interfaceVersion": "6.7.1",\n                "entryPoint": "fallback-current-state",', 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.7.1 dialogue-first MusicChat; no score generation on Send.')

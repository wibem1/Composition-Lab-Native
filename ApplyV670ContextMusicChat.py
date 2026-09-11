from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# V6.7.0: no trigger words. MusicChat receives the complete workspace context and
# asks the selected model to decide whether to clarify, discuss, compose, or revise.
# Ambiguity is handled by a natural-language follow-up question from the model.

# Temporary extra source material for the existing two-stage composition pipeline.
prop_anchor = '    private var nextCompositionEntryPoint: String = "compose-button"\n'
prop_new = '''    private var nextCompositionEntryPoint: String = "compose-button"\n    private var musicChatCompositionContextOverride: String = ""\n'''
if 'musicChatCompositionContextOverride' not in s:
    if prop_anchor not in s:
        raise SystemExit('V6.7.0: entry-point property anchor not found')
    s = s.replace(prop_anchor, prop_new, 1)

# Let the normal composition pipeline receive material chosen by the contextual
# MusicChat orchestrator. The visible upper settings remain authoritative.
base_anchor = '''        if let imported=importedReferenceScore,\n           let data=try? JSONEncoder().encode(imported),\n           let json=String(data:data,encoding:.utf8) {\n            result += "\\n\\nVORHANDENES MATERIAL (\\(imported.ti)):\\n\\(json)"\n        }\n        return result\n'''
base_new = '''        if let imported=importedReferenceScore,\n           let data=try? JSONEncoder().encode(imported),\n           let json=String(data:data,encoding:.utf8) {\n            result += "\\n\\nVORHANDENES MATERIAL (\\(imported.ti)):\\n\\(json)"\n        }\n        if !musicChatCompositionContextOverride.isEmpty {\n            result += "\\n\\nMUSICCHAT-ARBEITSMATERIAL:\\n" + musicChatCompositionContextOverride\n        }\n        return result\n'''
if base_anchor not in s:
    raise SystemExit('V6.7.0: basePrompt material anchor not found')
s = s.replace(base_anchor, base_new, 1)

start = s.find('    private func musicChatStartsNewComposition(_ text: String) -> Bool {\n')
end = s.find('    private func appendChat(_ who:String,_ text:String) {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.7.0: V6.6.11 MusicChat block not found')

new_block = r'''    private func musicChatWorkspaceContext() -> String {
        var slotObjects: [[String: Any]] = []
        for (index, item) in pieceSlots.enumerated() {
            guard let item else { continue }
            var obj: [String: Any] = [
                "slot": index + 1,
                "title": item.title,
                "concept": item.concept,
                "provider": item.provider.rawValue,
                "model": item.model
            ]
            if let data = try? JSONEncoder().encode(item.score),
               let scoreObject = try? JSONSerialization.jsonObject(with: data) {
                obj["score"] = scoreObject
            }
            slotObjects.append(obj)
        }

        let settingsObject: [String: Any] = [
            "measures": measuresField.stringValue,
            "meter": meterField.stringValue,
            "tempo": tempoField.stringValue,
            "key": musicalKeyField.stringValue,
            "ensemble": ensembleField.stringValue
        ]
        let object: [String: Any] = [
            "settings": settingsObject,
            "activeSlot": activePieceSlot + 1,
            "slots": slotObjects,
            "conversation": chatView.string
        ]
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private func musicChatSourceMaterial(_ slots: [Int]) -> String {
        var selected: [[String: Any]] = []
        let unique = Array(NSOrderedSet(array: slots).compactMap { $0 as? Int })
        for oneBased in unique {
            let index = oneBased - 1
            guard index >= 0, index < pieceSlots.count, let item = pieceSlots[index] else { continue }
            var obj: [String: Any] = [
                "slot": oneBased,
                "title": item.title,
                "concept": item.concept
            ]
            if let data = try? JSONEncoder().encode(item.score),
               let scoreObject = try? JSONSerialization.jsonObject(with: data) {
                obj["score"] = scoreObject
            }
            selected.append(obj)
        }
        guard !selected.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: selected, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    private func executeMusicChatRevision(targetSlot oneBased: Int,
                                          sourceSlots: [Int],
                                          task: String,
                                          replyLead: String?,
                                          provider p: Provider,
                                          model m: String,
                                          effort e: Effort,
                                          key: String) {
        let targetIndex = oneBased - 1
        guard targetIndex >= 0, targetIndex < pieceSlots.count, let targetItem = pieceSlots[targetIndex] else {
            appendChat(p.displayName, "Welches vorhandene Stück soll ich bearbeiten?")
            status("MusicChat braucht einen eindeutigen Ziel-Slot.", good: false)
            return
        }
        if let lead = replyLead?.trimmingCharacters(in: .whitespacesAndNewlines), !lead.isEmpty {
            appendChat(p.displayName, lead)
        }

        var materialSlots = sourceSlots
        if !materialSlots.contains(oneBased) { materialSlots.append(oneBased) }
        let sourceText = musicChatSourceMaterial(materialSlots)
        let revisionPrompt = """
        \(ComposerPrompts.technical)

        Du arbeitest im Composition Lab mit mehreren gleichzeitig verfügbaren Stücken.
        Bearbeite ausschließlich das als ZIEL bezeichnete Stück. Andere angegebene Slots sind Vergleichs- oder Quellenmaterial.
        Wenn der Nutzer nur eine Teiländerung verlangt, bewahre alle nicht verlangten musikalischen Eigenschaften möglichst unverändert.

        AKTUELLE RAHMENBEDINGUNGEN:
        Takte: \(measuresField.stringValue)
        Taktart: \(meterField.stringValue)
        Tempo: \(tempoField.stringValue)
        Tonart: \(musicalKeyField.stringValue)
        Besetzung: \(ensembleField.stringValue)

        ZIEL: Stück \(oneBased) – \(targetItem.title)

        ARBEITSMATERIAL:
        \(sourceText)

        NUTZER-AUFTRAG:
        \(task)

        Antworte ausschließlich mit einem JSON-Objekt im Format:
        {"reply":"kurze Antwort an den Nutzer", "concept": null ODER "vollständige neue Kompositionsidee", "score": vollständige bearbeitete Partitur}
        """

        lastDiagnostic = [
            "format": "composition-lab-native-diagnostic",
            "engineBuild": ComposerPrompts.engineBuild,
            "interface": "macOS AppKit",
            "interfaceVersion": "6.7.0",
            "entryPoint": "musicchat-context-revise",
            "stage": "revision-request",
            "targetSlot": oneBased,
            "sourceSlots": materialSlots,
            "resolvedTask": task,
            "revisionPrompt": revisionPrompt
        ]
        status("KI bearbeitet Stück \(oneBased) …", good: true)

        APIClient.shared.call(provider: p, model: m, key: key, effort: e,
                              system: ComposerPrompts.system, user: revisionPrompt, wantJSON: true) { [weak self] result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    if var d = self?.lastDiagnostic {
                        d["stage"] = "revision-failed"
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
                    let reply = object["reply"] as? String ?? "Bearbeitung abgeschlossen."
                    let concept = (object["concept"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let scoreObject = object["score"], !(scoreObject is NSNull) else {
                        throw NSError(domain: "CompositionLab.MusicChat", code: 2,
                                      userInfo: [NSLocalizedDescriptionKey: "Die KI hat keine bearbeitete Partitur zurückgegeben."])
                    }
                    let scoreData = try JSONSerialization.data(withJSONObject: scoreObject)
                    let score = try JSONDecoder().decode(Score.self, from: scoreData)
                    let cost = APICost.estimate(provider: p, model: m,
                                                inputTokens: response.inputTokens,
                                                outputTokens: response.outputTokens)
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.activePieceSlot = targetIndex
                        self.pendingCompositionSlot = targetIndex
                        self.install(score: score,
                                     concept: (concept?.isEmpty == false ? concept! : targetItem.concept),
                                     provider: p,
                                     model: m,
                                     costUSD: cost,
                                     inputTokens: response.inputTokens,
                                     outputTokens: response.outputTokens)
                        self.appendChat(p.displayName, reply)
                        if var d = self.lastDiagnostic {
                            d["stage"] = "revision-completed"
                            d["response"] = response.text
                            self.lastDiagnostic = d
                        }
                        self.status("Stück \(oneBased) wurde bearbeitet. · API-Kosten ca. \(APICost.display(cost))", good: true)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.appendChat("Fehler", error.localizedDescription)
                        self?.status("Fehler: \(error.localizedDescription)", good: false)
                    }
                }
            }
        }
    }

    @objc private func chatPressed() {
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
        let orchestrationPrompt = """
        Du bist die musikalische Dialog- und Entscheidungsinstanz von Composition Lab.
        Interpretiere den aktuellen Nutzerbeitrag aus dem GESAMTEN Gesprächskontext, den oberen musikalischen Einstellungen und allen belegten Stück-Slots.

        WICHTIGE REGELN:
        - Verwende KEINE Triggerwort- oder Schlüsselwortlogik. Entscheide semantisch aus dem vollständigen Kontext.
        - Ein belegter oder ausgewählter Slot bedeutet NICHT automatisch, dass er bearbeitet werden soll.
        - Mehrere Slots dürfen gleichzeitig verglichen, analysiert oder als Material verwendet werden.
        - Wenn eine musikalisch relevante Mehrdeutigkeit besteht, frage den Nutzer kurz und konkret nach, statt zu raten.
        - Frage nicht wegen unwichtiger Details nach.
        - Wenn der Nutzer nur analysieren, vergleichen, diskutieren oder beraten möchte, ändere keine Partitur.
        - Bei einer Bearbeitung muss targetSlot eindeutig genau einen belegten Slot bezeichnen; ist das nicht eindeutig, frage nach.
        - Bei einer neuen Komposition können sourceSlots leer sein oder mehrere vorhandene Stücke als Material enthalten.
        - Die oberen Einstellungen sind aktuelle Rahmenbedingungen, sofern der Nutzer sie im Dialog nicht ausdrücklich relativiert.

        Mögliche Modi:
        clarify = Rückfrage nötig.
        discuss = analysieren/vergleichen/beraten, ohne Musikdatei zu ändern.
        compose = eine neue Komposition erzeugen.
        revise = genau ein vorhandenes Stück bearbeiten.

        Gib ausschließlich JSON zurück:
        {
          "mode":"clarify|discuss|compose|revise",
          "question": null ODER "kurze Rückfrage",
          "reply": null ODER "kurze direkte Antwort",
          "resolvedTask": null ODER "präzise, aber nicht unnötig ausgeschmückte Interpretation des Nutzerauftrags",
          "sourceSlots": [1,2],
          "targetSlot": null ODER 1
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
            "interfaceVersion": "6.7.0",
            "entryPoint": "musicchat-context",
            "stage": "orchestration-request",
            "userMessage": msg,
            "workspaceContext": workspace,
            "orchestrationPrompt": orchestrationPrompt
        ]
        status("KI ordnet den musikalischen Auftrag ein …", good: true)

        APIClient.shared.call(provider: p, model: m, key: key, effort: e,
                              system: ComposerPrompts.system,
                              user: orchestrationPrompt,
                              wantJSON: true) { [weak self] result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    if var d = self?.lastDiagnostic {
                        d["stage"] = "orchestration-failed"
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
                    let mode = (object["mode"] as? String ?? "clarify").lowercased()
                    let question = object["question"] as? String
                    let reply = object["reply"] as? String
                    let resolvedTask = (object["resolvedTask"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let sourceSlots = (object["sourceSlots"] as? [Any] ?? []).compactMap { value -> Int? in
                        if let n = value as? Int { return n }
                        if let n = value as? NSNumber { return n.intValue }
                        return nil
                    }.filter { $0 >= 1 && $0 <= 10 }
                    let targetSlot: Int? = {
                        if let n = object["targetSlot"] as? Int { return n }
                        if let n = object["targetSlot"] as? NSNumber { return n.intValue }
                        return nil
                    }()

                    DispatchQueue.main.async {
                        guard let self else { return }
                        if var d = self.lastDiagnostic {
                            d["stage"] = "orchestration-response"
                            d["orchestrationResponse"] = response.text
                            d["mode"] = mode
                            d["sourceSlots"] = sourceSlots
                            if let targetSlot { d["targetSlot"] = targetSlot }
                            if let resolvedTask { d["resolvedTask"] = resolvedTask }
                            self.lastDiagnostic = d
                        }

                        switch mode {
                        case "clarify":
                            let text = question?.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.appendChat(p.displayName, (text?.isEmpty == false ? text! : "Was genau soll ich mit den vorhandenen Stücken tun?"))
                            self.status("MusicChat wartet auf deine Präzisierung.", good: true)

                        case "discuss":
                            let text = reply?.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.appendChat(p.displayName, (text?.isEmpty == false ? text! : "Ich habe den musikalischen Kontext ausgewertet."))
                            self.status("MusicChat-Antwort erhalten.", good: true)

                        case "compose":
                            let task = (resolvedTask?.isEmpty == false ? resolvedTask! : msg)
                            if let lead = reply?.trimmingCharacters(in: .whitespacesAndNewlines), !lead.isEmpty {
                                self.appendChat(p.displayName, lead)
                            }
                            self.musicChatCompositionContextOverride = self.musicChatSourceMaterial(sourceSlots)
                            let oldInput = self.chatInput.stringValue
                            self.chatInput.stringValue = task
                            self.nextCompositionEntryPoint = "musicchat-context-compose"
                            self.composePressed()
                            self.nextCompositionEntryPoint = "compose-button"
                            self.chatInput.stringValue = oldInput
                            self.musicChatCompositionContextOverride = ""

                        case "revise":
                            guard let target = targetSlot, target >= 1, target <= 10 else {
                                self.appendChat(p.displayName, question ?? "Welches Stück soll ich bearbeiten?")
                                self.status("MusicChat braucht einen eindeutigen Ziel-Slot.", good: true)
                                return
                            }
                            let task = (resolvedTask?.isEmpty == false ? resolvedTask! : msg)
                            self.executeMusicChatRevision(targetSlot: target,
                                                          sourceSlots: sourceSlots,
                                                          task: task,
                                                          replyLead: reply,
                                                          provider: p,
                                                          model: m,
                                                          effort: e,
                                                          key: key)

                        default:
                            self.appendChat(p.displayName, question ?? "Der Auftrag ist noch nicht eindeutig. Was genau soll ich tun?")
                            self.status("MusicChat wartet auf deine Präzisierung.", good: true)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.appendChat("Fehler", error.localizedDescription)
                        self?.status("Fehler: \(error.localizedDescription)", good: false)
                    }
                }
            }
        }
    }

'''

s = s[:start] + new_block + s[end:]

# Update diagnostic fallback version if the older value still exists.
s = s.replace('"interfaceVersion": "6.6.11",\n                "entryPoint": "fallback-current-state",',
              '"interfaceVersion": "6.7.0",\n                "entryPoint": "fallback-current-state",', 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.7.0 contextual MusicChat orchestration without trigger words.')

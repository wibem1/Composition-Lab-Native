from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Composition Lab Native 3.0
# MusicChat is the musical core. The composition idea is an editable state.
# Sending chat never creates a score. The blue button creates a score from the
# CURRENT visible idea; when no idea exists yet, it creates the idea only.

# ---------------------------------------------------------------------------
# 1) The idea is a real editor, not a status display.
# ---------------------------------------------------------------------------
s = s.replace('conceptView.isEditable = false', 'conceptView.isEditable = true')
s = s.replace('title("Aktuelle Kompositionsidee")', 'title("Kompositionsidee")')
s = s.replace('title("Musikalischer Impuls")', 'title("Kompositionsidee")')

# V6 install() decorated the concept with provider/model metadata. In 3.0 the
# text field itself is the authoritative user-editable idea, so keep it pure.
old_install = '''        conceptView.string = concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty\n            ? ""\n            : conceptDisplay(concept, provider: provider, model: model)\n'''
new_install = '''        conceptView.string = concept.trimmingCharacters(in: .whitespacesAndNewlines)\n'''
if old_install in s:
    s = s.replace(old_install, new_install, 1)

# ---------------------------------------------------------------------------
# 2) Workspace context: include the CURRENT editable idea and assignment.
# ---------------------------------------------------------------------------
start = s.find('    private func musicChatWorkspaceContext() -> String {\n')
end = s.find('    private func musicChatSourceMaterial(_ slots: [Int]) -> String {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V3.0: musicChatWorkspaceContext block not found')

workspace = r'''    private func musicChatWorkspaceContext() -> String {
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
            "conversation": chatView.string,
            "currentAssignment": promptView.string,
            "currentCompositionIdea": conceptView.string
        ]
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

'''
s = s[:start] + workspace + s[end:]

# ---------------------------------------------------------------------------
# 3) MusicChat: think, discuss, select sources, and create/update the IDEA.
#    Never create/revise a score from Send.
# ---------------------------------------------------------------------------
start = s.find('    @objc private func chatPressed() {\n')
end = s.find('    private func appendChat(_ who:String,_ text:String) {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V3.0: chatPressed block not found')

chat = r'''    @objc private func chatPressed() {
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
        Du bist der musikalische Gesprächspartner im MusicChat von Composition Lab 3.0.
        MusicChat ist die zentrale musikalische Arbeitsebene. Dieser Schritt ist AUSSCHLIESSLICH Dialog und Ideenarbeit.
        Erzeuge oder verändere hier NIEMALS eine Partitur, MIDI-Datei oder MusicXML-Datei.

        Verstehe den aktuellen Nutzerbeitrag semantisch aus dem gesamten Gespräch, den oberen musikalischen Einstellungen,
        der aktuell sichtbaren editierbaren Kompositionsidee und allen belegten Stück-Slots.

        REGELN:
        - Keine Triggerwort- oder Regex-Logik. Entscheide aus dem vollständigen musikalischen Zusammenhang.
        - Ein aktiver oder belegter Slot ist nur Teil des Arbeitstisches und nicht automatisch Ziel oder Quelle.
        - Mehrere Slots dürfen gleichzeitig analysiert, verglichen oder als musikalisches Material verstanden werden.
        - Wenn musikalisch relevante Mehrdeutigkeit besteht, frage kurz und konkret nach. Frage nicht wegen Nebensächlichkeiten nach.
        - Takte, Taktart, Tempo, Tonart und Besetzung gelten als vorhandene Rahmenbedingungen, wenn sie oben eingetragen sind.
        - Wenn der Nutzer diskutiert, analysiert oder vergleicht, antworte normal und ändere die Kompositionsidee nur dann, wenn das inhaltlich wirklich gemeint ist.
        - Wenn aus dem Gespräch ein Kompositionsvorhaben klar wird, formuliere einen knappen compositionAssignment und entwickle dazu eine kurze eigenständige compositionIdea.
        - compositionIdea ist ein musikalischer Gedanke/Impuls, kein technischer Bauplan: höchstens drei kurze Sätze, charakteristisch und offen genug für kompositorische Freiheit.
        - Wenn bereits eine editierbare Kompositionsidee vorhanden ist und der Nutzer sie ändern möchte, gib als compositionIdea die VOLLSTÄNDIGE neue Fassung zurück.
        - sourceSlots enthält nur die Stücke, die nach dem Gesprächskontext tatsächlich Material für eine spätere Komposition sein sollen. Sonst [].
        - Behaupte niemals, dass bereits eine Partitur oder ein Entwurf als Musikdatei erzeugt wurde. Das geschieht ausschließlich über den blauen Komponieren-Button.

        Antworte ausschließlich als JSON:
        {
          "reply":"natürliche, knappe Dialogantwort",
          "compositionAssignment": null ODER "knapper geklärter Kompositionsauftrag",
          "compositionIdea": null ODER "vollständige aktuelle Kompositionsidee",
          "sourceSlots":[1,2]
        }

        ARBEITSRAUM:
        \(workspace)

        AKTUELLER NUTZERBEITRAG:
        \(msg)
        """

        lastDiagnostic = [
            "format": "composition-lab-native-diagnostic",
            "engineBuild": ComposerPrompts.engineBuild,
            "interface": "macOS AppKit",
            "interfaceVersion": "3.0.0",
            "entryPoint": "musicchat",
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
                    let assignment = (object["compositionAssignment"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let idea = (object["compositionIdea"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let sourceSlots = (object["sourceSlots"] as? [Any] ?? []).compactMap { value -> Int? in
                        if let n = value as? Int { return n }
                        if let n = value as? NSNumber { return n.intValue }
                        return nil
                    }.filter { $0 >= 1 && $0 <= 10 }

                    DispatchQueue.main.async {
                        guard let self else { return }
                        let answer = (reply?.isEmpty == false) ? reply! : "Ich habe den musikalischen Zusammenhang aufgenommen."
                        self.appendChat(p.displayName, answer)

                        if let assignment, !assignment.isEmpty {
                            self.promptView.string = assignment
                        }
                        if let idea, !idea.isEmpty {
                            self.conceptView.string = idea
                            self.lastConcept = idea
                        }
                        if assignment?.isEmpty == false || idea?.isEmpty == false {
                            self.musicChatCompositionContextOverride = self.musicChatSourceMaterial(sourceSlots)
                            self.saveSettingsFromUI()
                        }

                        if var d = self.lastDiagnostic {
                            d["stage"] = "dialogue-completed"
                            d["dialogueResponse"] = response.text
                            d["reply"] = answer
                            d["sourceSlots"] = sourceSlots
                            if let assignment, !assignment.isEmpty { d["compositionAssignment"] = assignment }
                            if let idea, !idea.isEmpty { d["compositionIdea"] = idea }
                            d["inputTokens"] = response.inputTokens
                            d["outputTokens"] = response.outputTokens
                            self.lastDiagnostic = d
                        }
                        self.status(idea?.isEmpty == false ? "Kompositionsidee bereit und direkt editierbar." : "MusicChat-Antwort erhalten.", good: true)
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
s = s[:start] + chat + s[end:]

# ---------------------------------------------------------------------------
# 4) Compose button: the visible idea is authoritative.
#    If there is no idea, develop ONLY the idea and stop, so it can be edited.
# ---------------------------------------------------------------------------
start = s.find('    @objc private func composePressed() {\n')
end = s.find('    private func install(score:Score, concept:String, provider:Provider, model:String, addHistory:Bool = true,\n', start)
if start < 0 or end < 0:
    raise SystemExit('V3.0: composePressed block not found')

compose = r'''    @objc private func composePressed() {
        let tempoText = tempoField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tempoText.isEmpty && Double(tempoText.replacingOccurrences(of: ",", with: ".")) == nil {
            status("Tempo bitte als Zahl eingeben oder das Feld leer lassen.", good: false)
            return
        }

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
        saveSettingsFromUI()

        let p = provider
        let m = model
        let e = effort
        let assignment = basePrompt()
        let visibleIdea = conceptView.string.trimmingCharacters(in: .whitespacesAndNewlines)

        // No idea yet: create the musical idea only. This deliberate stop is what
        // makes the concept a true editable intermediate state.
        if visibleIdea.isEmpty {
            let ideaPrompt = """
            \(ComposerPrompts.conceptPrompt(assignment))

            WICHTIG FÜR COMPOSITION LAB 3.0:
            Formuliere nur einen kurzen musikalischen Gedanken/Impuls in höchstens drei kurzen Sätzen.
            Kein detaillierter Ablauf und kein technischer Bauplan. Noch keine Partitur erzeugen.
            """
            lastDiagnostic = [
                "format": "composition-lab-native-diagnostic",
                "engineBuild": ComposerPrompts.engineBuild,
                "interface": "macOS AppKit",
                "interfaceVersion": "3.0.0",
                "entryPoint": "compose-button",
                "stage": "idea-request",
                "assignment": assignment,
                "ideaPrompt": ideaPrompt
            ]
            status("KI entwickelt die Kompositionsidee …", good: true)
            APIClient.shared.call(provider: p, model: m, key: key, effort: e,
                                  system: ComposerPrompts.system,
                                  user: ideaPrompt,
                                  wantJSON: false) { [weak self] result in
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.status("Fehler: \(error.localizedDescription)", good: false)
                    }
                case .success(let response):
                    let idea = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.lastConcept = idea
                        self.conceptView.string = idea
                        if var d = self.lastDiagnostic {
                            d["stage"] = "idea-ready"
                            d["generatedIdea"] = idea
                            d["inputTokens"] = response.inputTokens
                            d["outputTokens"] = response.outputTokens
                            self.lastDiagnostic = d
                        }
                        self.status("Kompositionsidee bereit. Du kannst sie direkt bearbeiten und danach erneut komponieren.", good: true)
                    }
                }
            }
            return
        }

        // An idea exists: use EXACTLY the currently visible editable text.
        let finalIdea = visibleIdea
        lastConcept = finalIdea
        let compPrompt = """
        \(ComposerPrompts.technical)

        AUFTRAG:
        \(assignment)

        VERBINDLICHE AKTUELLE KOMPOSITIONSIDEE:
        \(finalIdea)

        Die obige Kompositionsidee kann vom Nutzer manuell bearbeitet worden sein. Verwende genau diese aktuelle Fassung als musikalische Grundlage und ersetze sie nicht durch eine frühere KI-Fassung.

        \(titleAvoidanceInstruction())

        Gib jetzt die fertige JSON-Partitur aus.
        """

        lastDiagnostic = [
            "format": "composition-lab-native-diagnostic",
            "engineBuild": ComposerPrompts.engineBuild,
            "interface": "macOS AppKit",
            "interfaceVersion": "3.0.0",
            "entryPoint": "compose-button",
            "stage": "score-request",
            "assignment": assignment,
            "finalEditedCompositionIdea": finalIdea,
            "compositionPrompt": compPrompt,
            "provider": p.rawValue,
            "model": m,
            "reasoning": e.rawValue
        ]
        status("KI komponiert aus der aktuellen Kompositionsidee …", good: true)

        APIClient.shared.call(provider: p, model: m, key: key, effort: e,
                              system: ComposerPrompts.system,
                              user: compPrompt,
                              wantJSON: true) { [weak self] result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    if var d = self?.lastDiagnostic {
                        d["stage"] = "score-failed"
                        d["error"] = error.localizedDescription
                        self?.lastDiagnostic = d
                    }
                    self?.status("Fehler: \(error.localizedDescription)", good: false)
                }
            case .success(let response):
                do {
                    let data = try APIClient.shared.extractJSON(response.text)
                    let score = try JSONDecoder().decode(Score.self, from: data)
                    let costUSD = APICost.estimate(provider: p, model: m,
                                                   inputTokens: response.inputTokens,
                                                   outputTokens: response.outputTokens)
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if var d = self.lastDiagnostic {
                            d["stage"] = "completed"
                            d["scoreResponse"] = response.text
                            d["inputTokens"] = response.inputTokens
                            d["outputTokens"] = response.outputTokens
                            self.lastDiagnostic = d
                        }
                        self.install(score: score,
                                     concept: finalIdea,
                                     provider: p,
                                     model: m,
                                     costUSD: costUSD,
                                     inputTokens: response.inputTokens,
                                     outputTokens: response.outputTokens)
                        self.status("Komposition erfolgreich abgeschlossen! · API-Kosten ca. \(APICost.display(costUSD))", good: true)
                    }
                } catch {
                    DispatchQueue.main.async {
                        if var d = self?.lastDiagnostic {
                            d["stage"] = "decode-failed"
                            d["rawResponse"] = response.text
                            d["error"] = error.localizedDescription
                            self?.lastDiagnostic = d
                        }
                        self?.status("Fehler: \(error.localizedDescription)", good: false)
                    }
                }
            }
        }
    }

'''
s = s[:start] + compose + s[end:]

# ---------------------------------------------------------------------------
# 5) Remove V6.7 prepared-brief residue if still present after previous patches.
# ---------------------------------------------------------------------------
s = s.replace('self.conceptView.string = "Vorbereiteter Kompositionsauftrag:\\n\\n" + brief + "\\n\\nDie Partitur entsteht erst mit ‚Mit gewählter KI komponieren‘."\n', '')
s = s.replace('self.resultLabel.stringValue = "Für diesen vorbereiteten Auftrag existiert noch keine Partitur."\n', '')

p.write_text(s, encoding='utf-8')
print('Applied Composition Lab Native 3.0 MusicChat core and editable composition idea workflow.')

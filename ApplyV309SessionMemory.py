from pathlib import Path

# Composition Lab Native 3.0.9
# Persistent automatic working-session memory. The last workspace survives app
# restarts and replacement installations because it lives in UserDefaults under
# the stable bundle identifier, not inside the .app bundle.

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# ---------------------------------------------------------------------------
# 1) Session state and autosave timer.
# ---------------------------------------------------------------------------
marker = '    private var lastDiagnostic: [String: Any]?\n'
if 'private var v309SessionAutosaveTimer' not in s:
    block = r'''    private var lastDiagnostic: [String: Any]?
    private var v309SessionAutosaveTimer: Timer?

    private struct V309SessionMemory: Codable {
        var format: String
        var version: Int
        var activeSlot: Int
        var slots: [HistoryItem?]
        var settings: AppSettings
        var history: [HistoryItem]
        var compositionAssignment: String
        var compositionIdea: String
        var chat: String
        var sourceContext: String
        var projectName: String
        var savedAt: Date
    }
'''
    if marker not in s:
        raise SystemExit('V3.0.9: session property marker not found')
    s = s.replace(marker, block, 1)

# ---------------------------------------------------------------------------
# 2) Restore session after UI/settings/current-player initialization.
# ---------------------------------------------------------------------------
old = '''        restoreSettings()\n        restoreCurrentPlayerState()\n        if let z = settings.zoomPercent, z != 100 { setZoom(percent: CGFloat(z), resizeWindow: false, persist: false) }\n'''
new = '''        restoreSettings()\n        restoreCurrentPlayerState()\n        v309RestoreSessionMemory()\n        NotificationCenter.default.addObserver(self, selector: #selector(v309ApplicationWillTerminate(_:)), name: NSApplication.willTerminateNotification, object: nil)\n        if let z = settings.zoomPercent, z != 100 { setZoom(percent: CGFloat(z), resizeWindow: false, persist: false) }\n'''
if old not in s:
    raise SystemExit('V3.0.9: loadView restore anchor not found')
s = s.replace(old, new, 1)

# Start a light autosave timer after the window exists.
old = '''        startReaperBridgeWatcher()\n    }\n'''
new = '''        startReaperBridgeWatcher()\n        v309StartSessionAutosave()\n    }\n'''
if old not in s:
    raise SystemExit('V3.0.9: viewDidAppear anchor not found')
s = s.replace(old, new, 1)

# ---------------------------------------------------------------------------
# 3) Session save/restore methods. UserDefaults persists across normal app
#    replacement/update installations as long as the bundle id stays unchanged.
# ---------------------------------------------------------------------------
insert_marker = '    private func startReaperBridgeWatcher() {\n'
if 'private func v309SaveSessionMemory()' not in s:
    methods = r'''    private let v309SessionMemoryKey = "compositionLab.v3.sessionMemory"

    private func v309StartSessionAutosave() {
        guard v309SessionAutosaveTimer == nil else { return }
        let timer = Timer(timeInterval: 2.0,
                          target: self,
                          selector: #selector(v309SessionAutosaveFired(_:)),
                          userInfo: nil,
                          repeats: true)
        timer.tolerance = 0.75
        RunLoop.main.add(timer, forMode: .common)
        v309SessionAutosaveTimer = timer
    }

    @objc private func v309SessionAutosaveFired(_ timer: Timer) {
        v309SaveSessionMemory()
    }

    @objc private func v309ApplicationWillTerminate(_ notification: Notification) {
        v309SaveSessionMemory()
    }

    private func v309SaveSessionMemory() {
        // Do not call captureCurrentInActiveSlot() here. In Composition Lab 3.x
        // the editable working idea is intentionally independent of the selected
        // piece slot; capturing would incorrectly overwrite slot metadata.
        saveSettingsFromUI()
        let memory = V309SessionMemory(
            format: "composition-lab-v3-session-memory",
            version: 1,
            activeSlot: max(0, min(activePieceSlot, 9)),
            slots: Array(pieceSlots.prefix(10)),
            settings: settings,
            history: history,
            compositionAssignment: promptView.string,
            compositionIdea: conceptView.string,
            chat: chatView.string,
            sourceContext: musicChatCompositionContextOverride,
            projectName: projectName,
            savedAt: Date()
        )
        do {
            let data = try JSONEncoder().encode(memory)
            UserDefaults.standard.set(data, forKey: v309SessionMemoryKey)
        } catch {
            // Autosave must never interrupt musical work. A later timer run can
            // retry; explicit CLAB/CLABPROJECT saves remain independent.
        }
    }

    private func v309RestoreSessionMemory() {
        guard let data = UserDefaults.standard.data(forKey: v309SessionMemoryKey),
              let memory = try? JSONDecoder().decode(V309SessionMemory.self, from: data),
              memory.format == "composition-lab-v3-session-memory" else { return }

        settings = memory.settings
        restoreSettings()
        history = memory.history
        Storage.shared.saveHistory(history)
        refreshVisibleHistories()

        pieceSlots = Array(memory.slots.prefix(10))
        if pieceSlots.count < 10 {
            pieceSlots.append(contentsOf: [HistoryItem?](repeating: nil, count: 10 - pieceSlots.count))
        }
        activePieceSlot = max(0, min(memory.activeSlot, 9))
        projectName = memory.projectName.isEmpty ? "Unbenannt" : memory.projectName

        // The MusicChat working state is global and independent of slot browsing.
        promptView.string = memory.compositionAssignment
        conceptView.string = memory.compositionIdea
        lastConcept = memory.compositionIdea
        chatView.string = memory.chat
        musicChatCompositionContextOverride = memory.sourceContext

        updatePieceSlotButtons()

        if let item = pieceSlots[activePieceSlot] {
            let preservedAssignment = memory.compositionAssignment
            let preservedIdea = memory.compositionIdea
            let preservedChat = memory.chat
            let preservedSourceContext = memory.sourceContext

            slotSelectionLoad = true
            install(score: item.score,
                    concept: item.concept,
                    provider: item.provider,
                    model: item.model,
                    addHistory: false,
                    costUSD: item.costUSD,
                    inputTokens: item.inputTokens,
                    outputTokens: item.outputTokens)
            slotSelectionLoad = false

            promptView.string = preservedAssignment
            conceptView.string = preservedIdea
            lastConcept = preservedIdea
            chatView.string = preservedChat
            musicChatCompositionContextOverride = preservedSourceContext
        }

        updatePieceSlotButtons()
        scheduleMusicXMLPreviewRefresh()
        status("Letzte Arbeitssitzung mit \(pieceSlots.compactMap { $0 }.count) Stück(en) wiederhergestellt.", good: true)
    }

'''
    if insert_marker not in s:
        raise SystemExit('V3.0.9: method insertion marker not found')
    s = s.replace(insert_marker, methods + insert_marker, 1)

# Current diagnostic version.
s = s.replace('"interfaceVersion": "3.0.8"', '"interfaceVersion": "3.0.9"')

p.write_text(s, encoding='utf-8')
print('Applied V3.0.9: automatic persistent session memory for 10 slots, working idea, assignment, chat, settings and active slot.')

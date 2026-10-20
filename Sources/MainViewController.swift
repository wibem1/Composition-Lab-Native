import Cocoa
import Foundation

final class TopAlignedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let providerPop = NSPopUpButton()
    private let modelPop = NSPopUpButton()
    private let modelCatalog = NativeModelCatalogStore()
    private var modelCatalogGeneration = 0

    private func modelsForProvider(_ provider: Provider) -> [(String, String)] {
        let catalog = modelCatalog.models(for: provider)
        return catalog.isEmpty ? provider.models : catalog.map { ($0.id, $0.name) }
    }
    private let effortPop = NSPopUpButton()
    private let keyField = NSSecureTextField()
        private let keyLabel = NSTextField(labelWithString: "API-Key")

    private let measuresField = NSComboBox()
    private let meterField = NSTextField(string: "")
    private let tempoField = NSTextField(string: "")
    private let musicalKeyField = NSTextField(string: "")
    private let ensembleField = NSTextField(string: "")
    private let promptView = NSTextView()

    private let conceptView = NSTextView()
    private let resultLabel = NSTextField(wrappingLabelWithString: "Noch keine Komposition.")
    private let chatView = NSTextView()
    private let chatInput = NSTextField()
    private let validationView = NSTextView()
    private let jsonView = NSTextView()
    private let historyTable = NSTableView()
    private let compositionHistoryFooter = HistoryFooterView(buttonTitles: ["Laden"])
    private let statusLabel = NSTextField(labelWithString: "Bereit.")

    private var settings = Storage.shared.loadSettings()
    private var history = Storage.shared.loadHistory()
    private var lastConcept = ""
    private var lastPortableMetadata: [String: JSONValue] = [:]
    private let localCompiler = NativeLilyPondCompiler(root: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("CompositionLab-v4/LilyPond"))
    private var lastLilyPondOutput: NativeLilyPondOutput?
    private var nativeWorkspaceGeneration = 0
    private var nativeRequestGeneration = 0
    private var nativeRequestInFlight = false
    private var lastScore: Score?
    private var lastMidi: Data?
    private var lastProvider: Provider?
    private var lastModel: String?
    private var lastCostUSD: Double = 0
    private var lastInputTokens: Int = 0
    private var lastOutputTokens: Int = 0
    private var importedReferenceScore: Score?
    private var importedReferenceName: String?
    /// Unveränderte Originaldaten einer importierten MusicXML-Datei.
    /// Bei MIDI-Import bleibt dieser Wert nil.
    private var importedReferenceMusicXMLData: Data?
    private var helpWindows: [NSWindow] = []
    private var zoomFactor: CGFloat = 1.0
    private var apiWindow: NSWindow?
    private var draftsWindow: NSWindow?
    private let workTabs = NSTabView()
    private let workspaceHost = NSView()
    private let compositionWorkspaceHost = CompositionFileDropHostView()
    private let experimentWorkspaceHost = NSView()
    private let compareWorkspaceHost = NSView()
    private let notationWorkspaceHost = NSView()
    private var workspaceViews: [NSView] {
        [compositionWorkspaceHost, notationWorkspaceHost, experimentWorkspaceHost]
    }
    private let workspaceSegment = NSSegmentedControl(labels: ["Main", "Noten", "Technik"], trackingMode: .selectOne, target: nil, action: nil)
    // V6: zehn gleichberechtigte Stück-/Varianten-Slots.
    private var pieceSlots: [HistoryItem?] = [HistoryItem?](repeating: nil, count: 10)
    private var activePieceSlot: Int = 0
    private var scoreRevisionState: [String: Any]?
    private var nativeRequestHandle: CoreRequestHandle?
    private var nativeDialogueClient: APIClient?
    private var pendingCompositionSlot: Int?
    private var slotSelectionLoad = false
    private var mainPieceSlotButtons: [NSButton] = []
    private var notationPieceSlotButtons: [NSButton] = []
    private let notationPlayerTimeLabel = NSTextField(labelWithString: "0:00 / 0:00")
    private let notationPlayerProgress = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let musicXMLPresetPop = NSPopUpButton()
    private let musicXMLRhythmModePop = NSPopUpButton()
    private let musicXMLStraightNotePop = NSPopUpButton()
    private let musicXMLTripletNotePop = NSPopUpButton()
    private let musicXMLRestPop = NSPopUpButton()
    private let musicXMLSmoothingPop = NSPopUpButton()
    private let musicXMLBarStartPop = NSPopUpButton()
    private let musicXMLSplitBeatsCheck = NSButton(checkboxWithTitle: "Zusammengesetzte Notenwerte an Zählzeiten teilen und binden", target: nil, action: nil)
    private let musicXMLPianoStaffPop = NSPopUpButton()
    private let musicXMLPianoSplitPop = NSPopUpButton()
    private let musicXMLCurrentLabel = NSTextField(labelWithString: "Aktuelles Stück: –")
    private let musicXMLSummaryLabel = NSTextField(wrappingLabelWithString: "")
    private let musicXMLPreview = MusicXMLPreviewView()
    private var musicXMLPreviewTimer: Timer?
    private var notationProfile = Storage.shared.loadNotationProfile() ?? .readablePiano
    private var workTabsHeight: NSLayoutConstraint?
    private var workTabsOpen = false
    private let midiPlayer = MIDIPlaybackController()
    private var midiOutputWindowController: NSWindowController?
    private let playerTimeLabel = NSTextField(labelWithString: "0:00 / 0:00")
    private let playerProgress = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let playerVolume = NSSlider(value: 0.80, minValue: 0, maxValue: 1.0, target: nil, action: nil)
    private let playerTempoField = NSTextField(string: "120")
    private let playerTempoStepper = NSStepper()
    private let playerLoopButton = NSButton(title: "↻ Loop", target: nil, action: nil)
    private var playerTimer: Timer?
    private var experimentWindow: ExperimentLabWindowController?
    private var compareWindow: CompareLabWindowController?
    private var lastExperimentConcept = ""
    private var lastExperimentScore: Score?
    private var lastDiagnostic: [String: Any]?
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
        var workspaceExtraFields: [String: JSONValue]? = nil
    }
    private var nextCompositionEntryPoint: String = "compose-button"
    private var musicChatCompositionContextOverride: String = ""
    private var projectName = "Unbenannt"
    private var projectURL: URL?
    private let v65ProjectLabel = NSTextField(labelWithString: "Projekt: Unbenannt")
    private let notationPlayerVolume = NSSlider(value: 0.80, minValue: 0, maxValue: 1.0, target: nil, action: nil)
    private let notationPlayerTempoField = NSTextField(string: "120")
    private let notationPlayerLoopButton = NSButton(title: "↻ Loop", target: nil, action: nil)

    private typealias V65ProjectDocument = CompositionWorkspace
    private var workspaceExtraFields: [String: JSONValue] = [:]

    override func loadView() {
        NotificationCenter.default.addObserver(self, selector: #selector(midiOutputModeChanged), name: MIDIOutputManager.changedNotification, object: nil)
        view = NSView(frame: NSRect(x:0,y:0,width:1260,height:800))
        buildUI()
        restoreSettings()
        restoreCurrentPlayerState()
        v309RestoreSessionMemory()
        NotificationCenter.default.addObserver(self, selector: #selector(v309ApplicationWillTerminate(_:)), name: NSApplication.willTerminateNotification, object: nil)
        if let z = settings.zoomPercent, z != 100 { setZoom(percent: CGFloat(z), resizeWindow: false, persist: false) }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateWindowTitle()
        view.window?.minSize = NSSize(width:900,height:680)
        view.window?.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        v309StartSessionAutosave()
    }


    private let v309SessionMemoryKey = "compositionLab.v3.sessionMemory"

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
            savedAt: Date(),
            workspaceExtraFields: workspaceExtraFields
        )
        do {
            let data = try JSONEncoder().encode(memory)
            AppPreferences.standard.set(data, forKey: v309SessionMemoryKey)
        } catch {
            // Autosave must never interrupt musical work. A later timer run can
            // retry; explicit CLAB/CLABPROJECT saves remain independent.
        }
    }

    private func v309RestoreSessionMemory() {
        guard let data = AppPreferences.standard.data(forKey: v309SessionMemoryKey),
              let memory = try? JSONDecoder().decode(V309SessionMemory.self, from: data),
              memory.format == "composition-lab-v3-session-memory" else { return }

        settings = memory.settings
        workspaceExtraFields = memory.workspaceExtraFields ?? [:]
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
                    outputTokens: item.outputTokens, metadata: item.extraFields)
            slotSelectionLoad = false

            promptView.string = preservedAssignment
            conceptView.string = preservedIdea
            chatView.string = preservedChat
            musicChatCompositionContextOverride = preservedSourceContext
        }

        updatePieceSlotButtons()
        scheduleMusicXMLPreviewRefresh()
        status("Letzte Arbeitssitzung mit \(pieceSlots.compactMap { $0 }.count) Stück(en) wiederhergestellt.", good: true)
    }

    private func buildUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        workspaceHost.wantsLayer = true
        workspaceHost.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let header = NSVisualEffectView()
        header.material = .headerView
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        workspaceSegment.selectedSegment = 0
        workspaceSegment.segmentStyle = .rounded
        workspaceSegment.target = self
        workspaceSegment.action = #selector(workspaceChanged)
        workspaceSegment.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(workspaceSegment)

        let project = NSTextField(labelWithString: "Composition Lab \(CoreServices.version) · Build 4200 · 20.10.2026")
        project.font = .systemFont(ofSize: 15, weight: .semibold)
        project.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(project)

        workspaceHost.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(workspaceHost)

        let compositionHost = compositionWorkspaceHost
        compositionHost.wantsLayer = true
        compositionHost.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        compositionHost.onDropFile = { [weak self] url in
            self?.loadCompositionReference(url: url)
        }
        compositionHost.toolTip = "MIDI, MusicXML oder Composition-Lab-Datei hierher ziehen"
        compositionHistoryFooter.onAction = { [weak self] _, item in
            self?.loadHistoryItemToComposition(item)
        }
        compositionHistoryFooter.onDelete = { [weak self] item in
            self?.deleteHistoryItem(item)
        }
        buildCompositionWorkspace(compositionHost)

        let experiment = ExperimentLabWindowController()
        experiment.onGenerate = { [weak self, weak experiment] request in self?.generateExperiment(request, window: experiment) }
        experiment.onChat = { [weak self, weak experiment] question in self?.chatExperiment(question, window: experiment) }
        experiment.onTransferToComposition = { [weak self, weak experiment] in self?.transferExperimentToComposition(window: experiment) }
        experiment.onLoadHistory = { [weak self, weak experiment] item in
            self?.loadHistoryItemToExperiment(item, window: experiment)
        }
        experiment.onDeleteHistory = { [weak self] item in
            self?.deleteHistoryItem(item)
        }
        experiment.onImportFile = { [weak self, weak experiment] url in
            self?.loadFileToExperiment(url: url, window: experiment)
        }
        experimentWindow = experiment
        if let labView = experiment.window?.contentView {
            experiment.window?.contentView = NSView()
            let host = experimentWorkspaceHost
            host.wantsLayer = true
            host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            labView.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(labView)
            NSLayoutConstraint.activate([
                labView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                labView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                labView.topAnchor.constraint(equalTo: host.topAnchor),
                labView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
            ])
        }

        history = Storage.shared.loadHistory()
        let compare = CompareLabWindowController(items: history)
        compare.onCompare = { [weak self, weak compare] a, b in self?.compare(a: a, b: b, window: compare) }
        compare.onSend = { [weak self, weak compare] a, b, text, _ in
            guard let self, let compare else { return }
            self.routeCompareDialog(a: a, b: b, text: text, window: compare)
        }
        compare.onTransferResult = { [weak self] item in self?.transferCompareResultToComposition(item) }
        compare.onDeleteHistory = { [weak self] item in self?.deleteHistoryItem(item) }
        compare.onGeneratedResult = { [weak self] item in
            var marked = item
            marked.area = .comparison
            self?.addHistoryItem(marked)
        }
        compareWindow = compare
        if let labView = compare.window?.contentView {
            compare.window?.contentView = NSView()
            labView.translatesAutoresizingMaskIntoConstraints = false
            let host = compareWorkspaceHost
            host.wantsLayer = true
            host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            host.addSubview(labView)
            NSLayoutConstraint.activate([
                labView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                labView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                labView.topAnchor.constraint(equalTo: host.topAnchor),
                labView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
            ])
        }

        let notationHost = notationWorkspaceHost
        notationHost.wantsLayer = true
        notationHost.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        buildMusicXMLWorkspace(notationHost)

        experimentWorkspaceHost.subviews.forEach { $0.removeFromSuperview() }
        buildTechnicalWorkspace(experimentWorkspaceHost)

        // V6 workspaces live in one neutral container. Switching only
        // toggles visibility and never changes NSWindow geometry.
        for (index, host) in workspaceViews.enumerated() {
            host.translatesAutoresizingMaskIntoConstraints = false
            if host.superview !== workspaceHost { workspaceHost.addSubview(host) }
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: workspaceHost.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: workspaceHost.trailingAnchor),
                host.topAnchor.constraint(equalTo: workspaceHost.topAnchor),
                host.bottomAnchor.constraint(equalTo: workspaceHost.bottomAnchor)
            ])
            host.isHidden = index != 0
        }

        refreshVisibleHistories()

        let statusBar = NSVisualEffectView()
        statusBar.material = .headerView
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusBar)
        statusLabel.textColor = .systemGreen
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusBar.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 52),
            project.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            project.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            workspaceSegment.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            workspaceSegment.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            workspaceSegment.widthAnchor.constraint(equalToConstant: 390),

            workspaceHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            workspaceHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            workspaceHost.topAnchor.constraint(equalTo: header.bottomAnchor),
            workspaceHost.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 28),
            statusLabel.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor)
        ])
    }

    private func buildMusicXMLWorkspace(_ parent: NSView) {
        // Feste, schmale Parameterleiste links. Die Notenbildfläche rechts
        // wird direkt an den rechten Fensterrand geheftet und füllt den Rest.
        let leftScroll = FastScrollView()
        leftScroll.hasVerticalScroller = true
        leftScroll.drawsBackground = false
        leftScroll.translatesAutoresizingMaskIntoConstraints = false

        let leftDoc = TopAlignedDocumentView()
        leftDoc.translatesAutoresizingMaskIntoConstraints = false
        leftScroll.documentView = leftDoc
        leftDoc.widthAnchor.constraint(equalTo: leftScroll.contentView.widthAnchor).isActive = true

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let right = NSView()
        right.translatesAutoresizingMaskIntoConstraints = false

        parent.addSubview(leftScroll)
        parent.addSubview(divider)
        parent.addSubview(right)

        NSLayoutConstraint.activate([
            leftScroll.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            leftScroll.topAnchor.constraint(equalTo: parent.topAnchor),
            leftScroll.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            leftScroll.widthAnchor.constraint(equalToConstant: 300),

            divider.leadingAnchor.constraint(equalTo: leftScroll.trailingAnchor),
            divider.topAnchor.constraint(equalTo: parent.topAnchor),
            divider.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            right.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            right.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            right.topAnchor.constraint(equalTo: parent.topAnchor),
            right.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        // Linke Spalte: Einstellungen – optisch wie die Parameterseite der Komposition.
        let left = NSStackView()
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 8
        left.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        left.edgeInsets = NSEdgeInsets(top:16,left:16,bottom:20,right:16)
        left.translatesAutoresizingMaskIntoConstraints = false
        leftDoc.addSubview(left)

        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo:leftDoc.leadingAnchor),
            left.trailingAnchor.constraint(equalTo:leftDoc.trailingAnchor),
            left.topAnchor.constraint(equalTo:leftDoc.topAnchor),
            left.bottomAnchor.constraint(lessThanOrEqualTo:leftDoc.bottomAnchor)
        ])

        left.addArrangedSubview(title("Noten"))
        let intro = NSTextField(wrappingLabelWithString:
            "Darstellungsquantisierung für MusicXML. Die MIDI-Daten und die Komposition bleiben unverändert.")
        intro.textColor = .secondaryLabelColor
        intro.widthAnchor.constraint(lessThanOrEqualToConstant:318).isActive = true
        left.addArrangedSubview(intro)
        left.addArrangedSubview(separatorBox())

        musicXMLPresetPop.removeAllItems()
        musicXMLRhythmModePop.removeAllItems()
        musicXMLStraightNotePop.removeAllItems()
        musicXMLTripletNotePop.removeAllItems()
        musicXMLRestPop.removeAllItems()
        musicXMLSmoothingPop.removeAllItems()
        musicXMLBarStartPop.removeAllItems()
        musicXMLPianoStaffPop.removeAllItems()
        musicXMLPianoSplitPop.removeAllItems()

        musicXMLPresetPop.addItems(withTitles: ["Klavier – lesbar", "MIDI-nah", "Benutzerdefiniert"])
        musicXMLRhythmModePop.addItems(withTitles: ["Auto", "Gerade", "Triolisch"])
        musicXMLStraightNotePop.addItems(withTitles: ["Aus", "Viertel", "Achtel", "16tel", "32tel", "64tel"])
        musicXMLTripletNotePop.addItems(withTitles: ["Aus", "Vierteltriolen", "Achteltriolen", "16teltriolen", "32teltriolen"])
        musicXMLRestPop.addItems(withTitles: ["Alle Pausen zeigen", "bis 32tel glätten", "bis 16tel glätten", "bis Achtel glätten"])
        musicXMLSmoothingPop.addItems(withTitles: ["Aus", "Leicht", "Mittel", "Stark"])
        musicXMLBarStartPop.addItems(withTitles: ["Aus", "bis 32tel", "bis 16tel", "bis Achtel"])
        musicXMLPianoStaffPop.addItems(withTitles: ["Automatisch", "Ein System", "Zwei Systeme"])
        let splitNotes = ["C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]
        musicXMLPianoSplitPop.addItems(withTitles: splitNotes)

        musicXMLPresetPop.target = self
        musicXMLPresetPop.action = #selector(musicXMLPresetChanged)
        for pop in [musicXMLRhythmModePop, musicXMLStraightNotePop, musicXMLTripletNotePop, musicXMLRestPop, musicXMLSmoothingPop, musicXMLBarStartPop, musicXMLPianoStaffPop, musicXMLPianoSplitPop] {
            pop.target = self
            pop.action = #selector(musicXMLSettingChanged)
        }
        musicXMLSplitBeatsCheck.target = self
        musicXMLSplitBeatsCheck.action = #selector(musicXMLSettingChanged)

        left.addArrangedSubview(title("Darstellungsquantisierung"))
        left.addArrangedSubview(label("Preset"))
        left.addArrangedSubview(musicXMLPresetPop)
        left.addArrangedSubview(label("Rhythmusmodus"))
        left.addArrangedSubview(musicXMLRhythmModePop)
        left.addArrangedSubview(label("Kleinster gerader Notenwert"))
        left.addArrangedSubview(musicXMLStraightNotePop)
        left.addArrangedSubview(label("Kleinster triolischer Notenwert"))
        left.addArrangedSubview(musicXMLTripletNotePop)
        left.addArrangedSubview(label("Kurze Pausen"))
        left.addArrangedSubview(musicXMLRestPop)
        left.addArrangedSubview(label("Notenlängen glätten"))
        left.addArrangedSubview(musicXMLSmoothingPop)
        left.addArrangedSubview(label("Mini-Pausen am Taktanfang"))
        left.addArrangedSubview(musicXMLBarStartPop)

        left.addArrangedSubview(separatorBox())
        left.addArrangedSubview(title("Klaviersystem"))
        left.addArrangedSubview(label("Darstellung"))
        left.addArrangedSubview(musicXMLPianoStaffPop)
        left.addArrangedSubview(label("Splitpunkt"))
        left.addArrangedSubview(musicXMLPianoSplitPop)

        left.addArrangedSubview(separatorBox())
        left.addArrangedSubview(title("Notenwerte"))
        musicXMLSplitBeatsCheck.widthAnchor.constraint(lessThanOrEqualToConstant:318).isActive = true
        left.addArrangedSubview(musicXMLSplitBeatsCheck)

        for v in left.arrangedSubviews {
            if !(v is NSBox) {
                v.widthAnchor.constraint(lessThanOrEqualToConstant:318).isActive = true
                v.setContentCompressionResistancePriority(.init(1), for: .horizontal)
                v.setContentHuggingPriority(.init(1), for: .horizontal)
            }
        }

        // Rechte Spalte: aktuelles Stück, schnelle Notenbildvorschau und Export.
        let rightStack = NSStackView()
        rightStack.orientation = .vertical
        rightStack.alignment = .leading
        rightStack.spacing = 8
        rightStack.edgeInsets = NSEdgeInsets(top:12,left:14,bottom:12,right:14)
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        right.addSubview(rightStack)

        NSLayoutConstraint.activate([
            rightStack.leadingAnchor.constraint(equalTo:right.leadingAnchor),
            rightStack.trailingAnchor.constraint(equalTo:right.trailingAnchor),
            rightStack.topAnchor.constraint(equalTo:right.topAnchor),
            rightStack.bottomAnchor.constraint(equalTo:right.bottomAnchor)
        ])

        let notationSlotBar = buildNotationPieceSlotBar()
        rightStack.addArrangedSubview(notationSlotBar)
        notationSlotBar.widthAnchor.constraint(equalTo: rightStack.widthAnchor).isActive = true

        let notationTransport = buildNotationTransport()
        rightStack.addArrangedSubview(notationTransport)
        notationTransport.widthAnchor.constraint(equalTo: rightStack.widthAnchor).isActive = true

        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 12
        let previewTitle = title("Notenbildvorschau")
        topRow.addArrangedSubview(previewTitle)
        topRow.addArrangedSubview(NSView())
        musicXMLCurrentLabel.font = .systemFont(ofSize:13, weight:.semibold)
        musicXMLCurrentLabel.textColor = .secondaryLabelColor
        topRow.addArrangedSubview(musicXMLCurrentLabel)
        rightStack.addArrangedSubview(topRow)
        topRow.widthAnchor.constraint(equalTo:rightStack.widthAnchor).isActive = true

        let explanation = NSTextField(wrappingLabelWithString:
            "Schnelle Kontrolle der aktuellen MusicXML-Darstellung. Änderungen links werden automatisch in der Vorschau sichtbar; MIDI und interner Score bleiben unverändert.")
        explanation.textColor = .secondaryLabelColor
        explanation.font = .systemFont(ofSize:11.5)
        rightStack.addArrangedSubview(explanation)
        explanation.widthAnchor.constraint(equalTo:rightStack.widthAnchor).isActive = true

        musicXMLPreview.translatesAutoresizingMaskIntoConstraints = false
        musicXMLPreview.onRefreshRequested = { [weak self] in self?.refreshCurrentNotation() }
        musicXMLPreview.onSourceSelection = { [weak self] message in self?.selectOriginalSource(message) }
        rightStack.addArrangedSubview(musicXMLPreview)
        musicXMLPreview.widthAnchor.constraint(equalTo:rightStack.widthAnchor).isActive = true
        musicXMLPreview.heightAnchor.constraint(greaterThanOrEqualToConstant:360).isActive = true
        musicXMLPreview.setContentHuggingPriority(.defaultLow, for:.vertical)
        musicXMLPreview.setContentCompressionResistancePriority(.defaultLow, for:.vertical)

        let lowerRow = NSStackView()
        lowerRow.orientation = .vertical
        lowerRow.alignment = .leading
        lowerRow.spacing = 10

        let rulesStack = NSStackView()
        rulesStack.orientation = .vertical
        rulesStack.alignment = .leading
        rulesStack.spacing = 4
        let rulesTitle = label("Darstellungsregeln")
        rulesStack.addArrangedSubview(rulesTitle)
        musicXMLSummaryLabel.textColor = .secondaryLabelColor
        musicXMLSummaryLabel.font = .systemFont(ofSize:11)
        rulesStack.addArrangedSubview(musicXMLSummaryLabel)
        musicXMLSummaryLabel.widthAnchor.constraint(greaterThanOrEqualToConstant:360).isActive = true

        let exportStack = NSStackView()
        exportStack.orientation = .vertical
        exportStack.alignment = .leading
        exportStack.spacing = 5
        exportStack.addArrangedSubview(label("Export"))
        let export = ExportDragButton(title:"MusicXML sichern / ziehen …",
                                      target:self,
                                      action:#selector(saveConfiguredMusicXMLPressed))
        export.toolTip = "Klicken zum Speichern oder die aktuell dargestellte MusicXML-Datei herausziehen"
        export.exportFileProvider = { [weak self] in
            self?.saveNotationProfile()
            return self?.temporaryMusicXMLExportURL()
        }
        exportStack.addArrangedSubview(export)

        lowerRow.addArrangedSubview(rulesStack)
        lowerRow.addArrangedSubview(exportStack)
        rightStack.addArrangedSubview(lowerRow)
        lowerRow.widthAnchor.constraint(equalTo:rightStack.widthAnchor).isActive = true
        export.widthAnchor.constraint(greaterThanOrEqualToConstant:220).isActive = true

        restoreMusicXMLDisplaySettings()
        updateMusicXMLWorkspaceSummary()
        scheduleMusicXMLPreviewRefresh()
    }

    private func separatorView() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 760).isActive = true
        return box
    }

    @objc private func musicXMLPresetChanged() {
        switch musicXMLPresetPop.indexOfSelectedItem {
        case 0:
            notationProfile = .readablePiano
        case 1:
            notationProfile = .midiNear
        default:
            notationProfile.preset = .custom
            notationProfile.options = optionsFromMusicXMLControls()
        }
        applyNotationProfileToControls()
        saveNotationProfile()
        updateMusicXMLWorkspaceSummary()
        scheduleMusicXMLPreviewRefresh()
    }

    @objc private func musicXMLSettingChanged() {
        notationProfile = NotationProfile(
            version: 1,
            preset: .custom,
            options: optionsFromMusicXMLControls()
        )
        musicXMLPresetPop.selectItem(at: 2)
        saveNotationProfile()
        updateMusicXMLWorkspaceSummary()
        scheduleMusicXMLPreviewRefresh()
    }

    private func optionsFromMusicXMLControls() -> MusicXMLDisplayOptions {
        let modeValues = ["auto", "straight", "triplet"]
        let straightValues: [Double?] = [nil, 1.0, 0.5, 0.25, 0.125, 0.0625]
        let tripletValues: [Double?] = [nil, 2.0/3.0, 1.0/3.0, 1.0/6.0, 1.0/12.0]
        let restValues: [Double] = [0, 0.125, 0.25, 0.5]
        let barValues: [Double] = [0, 0.125, 0.25, 0.5]
        let smoothing: [(occupancy: Double, tolerance: Double)] = [
            (1.0, 0.0),
            (0.75, 0.10),
            (0.60, 0.18),
            (0.45, 0.30)
        ]

        let mode = modeValues[max(0, min(musicXMLRhythmModePop.indexOfSelectedItem, modeValues.count - 1))]
        let straight = straightValues[max(0, min(musicXMLStraightNotePop.indexOfSelectedItem, straightValues.count - 1))]
        let triplet = tripletValues[max(0, min(musicXMLTripletNotePop.indexOfSelectedItem, tripletValues.count - 1))]
        let sr = restValues[max(0, min(musicXMLRestPop.indexOfSelectedItem, restValues.count - 1))]
        let bs = barValues[max(0, min(musicXMLBarStartPop.indexOfSelectedItem, barValues.count - 1))]
        let sm = smoothing[max(0, min(musicXMLSmoothingPop.indexOfSelectedItem, smoothing.count - 1))]

        return MusicXMLDisplayOptions(
            startGrid: 0,
            shortRestThreshold: sr,
            occupancyThreshold: sm.occupancy,
            durationTolerance: sm.tolerance,
            minimumNoteValue: nil,
            rhythmMode: mode,
            minimumStraightNoteValue: straight,
            minimumTripletNoteValue: triplet,
            barStartSnapThreshold: bs,
            splitAtBeatBoundaries: musicXMLSplitBeatsCheck.state == .on,
            pianoStaffMode: ["auto", "single", "two"][max(0, min(musicXMLPianoStaffPop.indexOfSelectedItem, 2))],
            pianoSplitPoint: [48,50,52,53,55,57,59,60,62,64,65,67,69,71,72][max(0, min(musicXMLPianoSplitPop.indexOfSelectedItem, 14))]
        )
    }

    private func currentMusicXMLDisplayOptions() -> MusicXMLDisplayOptions {
        notationProfile.options
    }

    private func nearestIndex(_ value: Double, in values: [Double]) -> Int {
        values.indices.min(by: { abs(values[$0] - value) < abs(values[$1] - value) }) ?? 0
    }

    private func applyNotationProfileToControls() {
        let o = notationProfile.options
        switch notationProfile.preset {
        case .readablePiano: musicXMLPresetPop.selectItem(at: 0)
        case .midiNear: musicXMLPresetPop.selectItem(at: 1)
        case .custom: musicXMLPresetPop.selectItem(at: 2)
        }

        let mode = o.rhythmMode ?? "auto"
        musicXMLRhythmModePop.selectItem(at: mode == "straight" ? 1 : (mode == "triplet" ? 2 : 0))

        // Abwärtskompatibilität zu V5.0.11 und älteren Profilen.
        let straight: Double? = {
            if let v = o.minimumStraightNoteValue { return v }
            if let v = o.minimumNoteValue { return v }
            if o.startGrid > 0 &&
               abs(o.startGrid - 1.0/3.0) > 0.01 &&
               abs(o.startGrid - 1.0/6.0) > 0.01 { return o.startGrid }
            return nil
        }()
        let triplet: Double? = {
            if let v = o.minimumTripletNoteValue { return v }
            if abs(o.startGrid - 1.0/3.0) < 0.01 { return 1.0/3.0 }
            if abs(o.startGrid - 1.0/6.0) < 0.01 { return 1.0/6.0 }
            return nil
        }()

        if let v = straight {
            musicXMLStraightNotePop.selectItem(at: 1 + nearestIndex(v, in: [1.0, 0.5, 0.25, 0.125, 0.0625]))
        } else {
            musicXMLStraightNotePop.selectItem(at: 0)
        }

        if let v = triplet {
            musicXMLTripletNotePop.selectItem(at: 1 + nearestIndex(v, in: [2.0/3.0, 1.0/3.0, 1.0/6.0, 1.0/12.0]))
        } else {
            musicXMLTripletNotePop.selectItem(at: 0)
        }

        musicXMLRestPop.selectItem(at: nearestIndex(o.shortRestThreshold, in: [0, 0.125, 0.25, 0.5]))
        musicXMLBarStartPop.selectItem(at: nearestIndex(o.barStartSnapThreshold, in: [0, 0.125, 0.25, 0.5]))

        let smoothingValues: [(occupancy: Double, tolerance: Double)] = [
            (1.0, 0.0), (0.75, 0.10), (0.60, 0.18), (0.45, 0.30)
        ]
        let smoothingIndex = smoothingValues.indices.min(by: {
            let a = abs(smoothingValues[$0].occupancy - o.occupancyThreshold) + abs(smoothingValues[$0].tolerance - o.durationTolerance)
            let b = abs(smoothingValues[$1].occupancy - o.occupancyThreshold) + abs(smoothingValues[$1].tolerance - o.durationTolerance)
            return a < b
        }) ?? 0
        musicXMLSmoothingPop.selectItem(at: smoothingIndex)
        musicXMLSplitBeatsCheck.state = o.splitAtBeatBoundaries ? .on : .off
        switch o.pianoStaffMode ?? "auto" {
        case "single": musicXMLPianoStaffPop.selectItem(at: 1)
        case "two": musicXMLPianoStaffPop.selectItem(at: 2)
        default: musicXMLPianoStaffPop.selectItem(at: 0)
        }
        let splitMIDIs = [48,50,52,53,55,57,59,60,62,64,65,67,69,71,72]
        let targetSplit = o.pianoSplitPoint ?? 60
        let splitIndex = splitMIDIs.indices.min(by: { abs(splitMIDIs[$0] - targetSplit) < abs(splitMIDIs[$1] - targetSplit) }) ?? 7
        musicXMLPianoSplitPop.selectItem(at: splitIndex)
    }

    private func saveNotationProfile() {
        Storage.shared.saveNotationProfile(notationProfile)
    }

    private func restoreMusicXMLDisplaySettings() {
        if let stored = Storage.shared.loadNotationProfile() {
            notationProfile = stored
        } else {
            // Einmalige Migration älterer V4.9.0/V5.0.11-Einstellungen.
            let d = AppPreferences.standard
            if d.object(forKey: "musicXML.startGrid") != nil {
                let startGridValues: [Double] = [0, 1.0, 0.5, 0.25, 0.125, 1.0/3.0, 1.0/6.0]
                let restValues: [Double] = [0, 0.125, 0.25, 0.5]
                let barValues: [Double] = [0, 0.125, 0.25, 0.5]
                let smoothing: [(Double, Double)] = [(1.0,0.0),(0.75,0.10),(0.60,0.18),(0.45,0.30)]
                let pi = max(0, min(d.integer(forKey: "musicXML.preset"), 2))
                let si = max(0, min(d.integer(forKey: "musicXML.startGrid"), 6))
                let ri = max(0, min(d.integer(forKey: "musicXML.rest"), 3))
                let smi = max(0, min(d.integer(forKey: "musicXML.smoothing"), 3))
                let bi = max(0, min(d.integer(forKey: "musicXML.barStart"), 3))
                let preset: NotationPreset = pi == 0 ? .readablePiano : (pi == 1 ? .midiNear : .custom)
                notationProfile = NotationProfile(
                    version: 1,
                    preset: preset,
                    options: MusicXMLDisplayOptions(
                        startGrid: startGridValues[si],
                        shortRestThreshold: restValues[ri],
                        occupancyThreshold: smoothing[smi].0,
                        durationTolerance: smoothing[smi].1,
                        barStartSnapThreshold: barValues[bi],
                        splitAtBeatBoundaries: d.bool(forKey: "musicXML.splitBeats")
                    )
                )
                saveNotationProfile()
            } else {
                notationProfile = .readablePiano
                saveNotationProfile()
            }
        }
        applyNotationProfileToControls()
    }

    private func updateMusicXMLWorkspaceSummary() {
        musicXMLCurrentLabel.stringValue = "Aktuelles Stück: " + (lastScore?.ti ?? "–")
        let o = currentMusicXMLDisplayOptions()
        let modeText: String = {
            switch o.rhythmMode ?? "auto" {
            case "straight": return "Gerade"
            case "triplet": return "Triolisch"
            default: return "Auto"
            }
        }()

        func straightText(_ v: Double?) -> String {
            guard let v else { return "aus" }
            if abs(v - 1.0) < 0.001 { return "Viertel" }
            if abs(v - 0.5) < 0.001 { return "Achtel" }
            if abs(v - 0.25) < 0.001 { return "16tel" }
            if abs(v - 0.125) < 0.001 { return "32tel" }
            if abs(v - 0.0625) < 0.001 { return "64tel" }
            return "\(v) Beat"
        }

        func tripletText(_ v: Double?) -> String {
            guard let v else { return "aus" }
            if abs(v - 2.0/3.0) < 0.01 { return "Vierteltriolen" }
            if abs(v - 1.0/3.0) < 0.01 { return "Achteltriolen" }
            if abs(v - 1.0/6.0) < 0.01 { return "16teltriolen" }
            if abs(v - 1.0/12.0) < 0.01 { return "32teltriolen" }
            return "\(v) Beat"
        }

        musicXMLSummaryLabel.stringValue =
            "Profil: \(notationProfile.preset.displayName) · Modus \(modeText) · " +
            "gerade \(straightText(o.minimumStraightNoteValue)) · " +
            "triolisch \(tripletText(o.minimumTripletNoteValue)) · " +
            "Pausenglättung bis \(o.shortRestThreshold) Beat · " +
            "Taktanfang bis \(o.barStartSnapThreshold) Beat · " +
            "Klavier \((o.pianoStaffMode ?? "auto") == "two" ? "2 Systeme" : ((o.pianoStaffMode ?? "auto") == "single" ? "1 System" : "automatisch")), Split \(o.pianoSplitPoint ?? 60) · " +
            (o.splitAtBeatBoundaries ? "Bindungen an Zählzeiten aktiv." : "keine automatische Zählzeitenteilung.")
    }

    private func scheduleMusicXMLPreviewRefresh() {
        musicXMLPreviewTimer?.invalidate()
        musicXMLPreviewTimer = nil
        // Notation is expensive (MusicXML generation + WebKit/Verovio rendering).
        // Only refresh it while the Noten workspace is actually visible.
        guard workspaceSegment.selectedSegment == 1 else { return }
        let timer = Timer(timeInterval: 0.20,
                          target: self,
                          selector: #selector(musicXMLPreviewTimerFired(_:)),
                          userInfo: nil,
                          repeats: false)
        timer.tolerance = 0.08
        RunLoop.main.add(timer, forMode: .default)
        musicXMLPreviewTimer = timer
    }

    @objc private func musicXMLPreviewTimerFired(_ timer: Timer) {
        refreshMusicXMLPreview()
    }

    private func refreshMusicXMLPreview() {
        if case .bool(true)? = lastPortableMetadata["directLilyPond"] {
            if let output = lastLilyPondOutput { musicXMLPreview.setLilyPond(output.pages) }
            else { musicXMLPreview.setMusicXML(nil) }
            return
        }
        guard let score = lastScore else {
            musicXMLPreview.setMusicXML(nil)
            return
        }
        let data = MusicXMLBuilder.build(score, options: currentMusicXMLDisplayOptions())
        musicXMLPreview.setMusicXML(data)
    }

    @objc private func saveConfiguredMusicXMLPressed() {
        saveNotationProfile()
        saveMusicXMLPressed()
    }

    private func buildCompositionWorkspace(_ parent: NSView) {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 18, left: 24, bottom: 18, right: 24)
        root.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            root.topAnchor.constraint(equalTo: parent.topAnchor),
            root.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        let controls = buildV64Controls(); root.addArrangedSubview(controls); controls.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let work = buildV64WorkArea(); root.addArrangedSubview(work); work.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        work.setContentHuggingPriority(.defaultLow, for: .vertical); work.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        let deck = buildV64Deck(); root.addArrangedSubview(deck); deck.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let bottom = buildV64BottomBar(); root.addArrangedSubview(bottom); bottom.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }

    private func v64Panel() -> NSBox {
        let b = NSBox(); b.boxType = .custom; b.cornerRadius = 12; b.borderWidth = 1; b.contentViewMargins = NSSize(width: 14, height: 12); return b
    }

    private func buildV64Controls() -> NSView {
        let box = v64Panel(); let row = NSStackView(); row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 10; box.contentView = row
        if providerPop.numberOfItems == 0 { providerPop.addItems(withTitles: Provider.allCases.map(\.displayName)); providerPop.target = self; providerPop.action = #selector(providerChanged) }
        if effortPop.numberOfItems == 0 { effortPop.addItems(withTitles: Effort.allCases.map(\.displayName)) }
        let ai = NSTextField(labelWithString: "KI"); ai.font = .systemFont(ofSize: 12, weight: .semibold); row.addArrangedSubview(ai)
        row.addArrangedSubview(providerPop); row.addArrangedSubview(modelPop)
        modelPop.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        modelPop.widthAnchor.constraint(lessThanOrEqualToConstant: 280).isActive = true
        modelPop.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        modelPop.toolTip = "Vollständige Modellliste über Technisches → KI-Modelle aktualisieren laden."
        row.addArrangedSubview(effortPop); row.addArrangedSubview(NSView())
        func label(_ text: String) { row.addArrangedSubview(NSTextField(labelWithString: text)) }
        func field(_ f: NSTextField, _ placeholder: String, _ width: CGFloat) { f.placeholderString = placeholder; f.widthAnchor.constraint(equalToConstant: width).isActive = true; row.addArrangedSubview(f) }
        if measuresField.numberOfItems == 0 {
            measuresField.addItems(withObjectValues: [2, 4, 8, 16, 24, 32, 48, 64].map(String.init))
            measuresField.isEditable = true
            measuresField.completes = false
        }
        label("Takte"); field(measuresField, "24", 62); field(meterField, "4/4", 54); label("Tempo"); field(tempoField, "96", 58); label("Tonart"); field(musicalKeyField, "C-Dur", 86)
        label("Instrumente"); ensembleField.placeholderString = "Piano"; ensembleField.widthAnchor.constraint(equalToConstant: 150).isActive = true; row.addArrangedSubview(ensembleField)
        return box
    }

    private func buildV64WorkArea() -> NSView {
        let row = NSStackView(); row.orientation = .horizontal; row.alignment = .top; row.spacing = 14
        let chat = v64Panel(); let cs = NSStackView(); cs.orientation = .vertical; cs.alignment = .leading; cs.spacing = 10; chat.contentView = cs
        let title = NSTextField(labelWithString: "MusicChat"); title.font = .systemFont(ofSize: 20, weight: .bold); cs.addArrangedSubview(title)
        chatView.isEditable = false; chatView.isSelectable = true; chatView.font = .systemFont(ofSize: 13); let log = textScroll(chatView, minHeight: 230); cs.addArrangedSubview(log); log.widthAnchor.constraint(equalTo: cs.widthAnchor).isActive = true; log.heightAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true; log.setContentHuggingPriority(.defaultLow, for: .vertical)
        let input = NSStackView(); input.orientation = .horizontal; input.alignment = .centerY; input.spacing = 8; chatInput.placeholderString = "Kompositionsauftrag, Frage oder Änderungswunsch …"; chatInput.isBezeled = true; chatInput.bezelStyle = .roundedBezel; chatInput.heightAnchor.constraint(equalToConstant: 38).isActive = true; input.addArrangedSubview(chatInput)
        let send = NSButton(title: "Senden", target: self, action: #selector(chatPressed)); send.bezelStyle = .rounded; send.widthAnchor.constraint(equalToConstant: 92).isActive = true; input.addArrangedSubview(send); cs.addArrangedSubview(input); input.widthAnchor.constraint(equalTo: cs.widthAnchor).isActive = true

        let idea = v64Panel(); let isv = NSStackView(); isv.orientation = .vertical; isv.alignment = .leading; isv.spacing = 9; idea.contentView = isv
        let it = NSTextField(labelWithString: "Aktuelle Kompositionsidee"); it.font = .systemFont(ofSize: 16, weight: .bold); isv.addArrangedSubview(it)
        conceptView.isEditable = true; conceptView.isSelectable = true; conceptView.font = .systemFont(ofSize: 13); let ideaScroll = textScroll(conceptView, minHeight: 260); ideaScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 285).isActive = true; ideaScroll.setContentHuggingPriority(.defaultLow, for: .vertical); ideaScroll.setContentCompressionResistancePriority(.defaultLow, for: .vertical); isv.addArrangedSubview(ideaScroll); ideaScroll.widthAnchor.constraint(equalTo: isv.widthAnchor).isActive = true
        row.addArrangedSubview(chat); row.addArrangedSubview(idea); chat.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.66, constant: -7).isActive = true; idea.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.34, constant: -7).isActive = true; chat.heightAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true; idea.heightAnchor.constraint(equalTo: chat.heightAnchor).isActive = true
        return row
    }

    private func buildV64Deck() -> NSView {
        let panel = v64Panel()
        panel.contentViewMargins = NSSize(width: 7, height: 5)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        panel.contentView = stack

        let title = NSTextField(labelWithString: "Stücke (1–10)")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        stack.addArrangedSubview(title)

        let scroll = FastScrollView()
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.heightAnchor.constraint(equalToConstant: 184).isActive = true

        let cards = NSStackView()
        cards.orientation = .horizontal
        cards.alignment = .centerY
        cards.spacing = 8
        cards.edgeInsets = NSEdgeInsets(top: 2, left: 1, bottom: 2, right: 1)
        cards.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = cards

        var buttons: [PieceSlotDropButton] = []
        for i in 0..<10 {
            let b = PieceSlotDropButton(title: "\(i + 1)", target: self, action: #selector(pieceSlotPressed(_:)))
            b.tag = i
            b.setButtonType(.toggle)
            b.font = .systemFont(ofSize: 12, weight: .medium)
            b.alignment = .center
            b.widthAnchor.constraint(equalToConstant: 116).isActive = true
            b.heightAnchor.constraint(equalToConstant: 164).isActive = true
            b.onDropFile = { [weak self, weak b] url in
                guard let self, let b else { return }
                self.importFile(url, intoPieceSlot: b.tag)
            }

            let menu = NSMenu()
            let midi = NSMenuItem(title: "MIDI-Datei laden …", action: #selector(v651LoadMIDIIntoSlot(_:)), keyEquivalent: "")
            midi.target = self
            midi.tag = i
            menu.addItem(midi)
            let clab = NSMenuItem(title: "CLAB-Datei laden …", action: #selector(v651LoadCLABIntoSlot(_:)), keyEquivalent: "")
            clab.target = self
            clab.tag = i
            menu.addItem(clab)
            menu.addItem(NSMenuItem.separator())
            let clear = NSMenuItem(title: "Stück löschen", action: #selector(v662DeletePieceSlot(_:)), keyEquivalent: "")
            clear.target = self
            clear.tag = i
            menu.addItem(clear)
            b.menu = menu

            buttons.append(b)
            cards.addArrangedSubview(b)
        }

        cards.widthAnchor.constraint(greaterThanOrEqualToConstant: 1235).isActive = true
        mainPieceSlotButtons = buttons
        updatePieceSlotButtons()
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return panel
    }

    private func buildV64BottomBar() -> NSView {
        let panel = v64Panel()
        panel.contentViewMargins = NSSize(width: 8, height: 5)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        panel.contentView = stack

        // Zeile 1: reiner MIDI-Player.
        let playerRow = NSStackView()
        playerRow.orientation = .horizontal
        playerRow.alignment = .centerY
        playerRow.spacing = 7

        playerRow.addArrangedSubview(NSButton(title: "▶Ⅱ", target: self, action: #selector(playCurrentMIDI)))
        playerRow.addArrangedSubview(NSButton(title: "■", target: self, action: #selector(stopCurrentMIDI)))
        playerLoopButton.setButtonType(.toggle)
        playerLoopButton.target = self
        playerLoopButton.action = #selector(playerLoopChanged)
        playerRow.addArrangedSubview(playerLoopButton)
        playerRow.addArrangedSubview(playerTimeLabel)

        playerProgress.target = self
        playerProgress.action = #selector(playerSeekChanged)
        playerProgress.isContinuous = true
        playerProgress.widthAnchor.constraint(equalToConstant: 260).isActive = true
        playerRow.addArrangedSubview(playerProgress)

        playerRow.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        playerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        playerTempoField.target = self
        playerTempoField.action = #selector(playerTempoChanged)
        playerRow.addArrangedSubview(playerTempoField)

        playerRow.addArrangedSubview(NSTextField(labelWithString: "Lautstärke"))
        playerVolume.widthAnchor.constraint(equalToConstant: 130).isActive = true
        playerVolume.target = self
        playerVolume.action = #selector(playerVolumeChanged)
        playerRow.addArrangedSubview(playerVolume)

        stack.addArrangedSubview(playerRow)

        // Zeile 2: Funktionen. Alles linksbündig, keine nach rechts gedrückte Aktionsgruppe.
        let functionRow = NSStackView()
        functionRow.orientation = .horizontal
        functionRow.alignment = .centerY
        functionRow.spacing = 8

        functionRow.addArrangedSubview(NSButton(title: "MIDI sichern", target: self, action: #selector(saveMIDIPressed)))
        functionRow.addArrangedSubview(NSButton(title: "CLAB sichern", target: self, action: #selector(v307SaveCLABPressed)))
        functionRow.addArrangedSubview(NSButton(title: "CLAB laden …", target: self, action: #selector(v307LoadCLABPressed)))

        let gap = NSView()
        gap.widthAnchor.constraint(equalToConstant: 22).isActive = true
        functionRow.addArrangedSubview(gap)

        functionRow.addArrangedSubview(NSButton(title: "Import …", target: self, action: #selector(importIntoActivePieceSlotPressed)))
        functionRow.addArrangedSubview(NSButton(title: "Motiv …", target: self, action: #selector(generateMotifPressed)))

        let compose = NSButton(title: "Mit gewählter KI komponieren", target: self, action: #selector(composePressed))
        compose.bezelStyle = .rounded
        compose.keyEquivalent = "\r"
        functionRow.addArrangedSubview(compose)

        stack.addArrangedSubview(functionRow)
        return panel
    }

    private func importFile(_ url: URL, intoPieceSlot index: Int) {
        guard index >= 0, index < pieceSlots.count else { return }
        if url.pathExtension.lowercased() == "clabproject" { loadLegacyProject(url: url); return }
        do {
            // Validate before selecting/replacing a slot. Failed imports must
            // never copy the previous current score into the destination.
            let data = try Data(contentsOf: url)
            switch url.pathExtension.lowercased() {
            case "clab": try CoreServices.validateDocument(data)
            case "xml", "musicxml": _ = try CoreServices.importMusicXML(data, title: url.lastPathComponent)
            default: _ = try CoreServices.importMIDI(data, title: url.lastPathComponent)
            }
            if index != activePieceSlot { captureCurrentInActiveSlot() }
            activePieceSlot = index
            loadCompositionReference(url: url)
            if lastScore != nil { captureCurrentInActiveSlot() }
            updatePieceSlotButtons()
        } catch { status("Datei nicht übernommen: " + error.localizedDescription, good: false) }
    }

    @objc private func importIntoActivePieceSlotPressed() {
        let panel = NSOpenPanel(); panel.allowedFileTypes = ["mid", "midi", "musicxml", "xml", "clab", "clabproject"]; panel.allowsMultipleSelection = false; panel.canChooseDirectories = false; panel.message = "Datei in Stück-Slot \(activePieceSlot + 1) laden"; guard panel.runModal() == .OK, let url = panel.url else { return }; importFile(url, intoPieceSlot: activePieceSlot)
    }

    private func buildTechnicalWorkspace(_ parent: NSView) {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            root.topAnchor.constraint(equalTo: parent.topAnchor),
            root.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        root.addArrangedSubview(title("Technik"))
        let intro = NSTextField(wrappingLabelWithString: "API-Schlüssel, MIDI-Ausgabe, technische Prüfung, JSON, Diagnose und Verlauf. Diese Werkzeuge sind bewusst von der musikalischen Hauptseite getrennt.")
        intro.textColor = .secondaryLabelColor
        root.addArrangedSubview(intro)
        intro.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.addArrangedSubview(NSButton(title: "API-Schlüssel …", target: self, action: #selector(menuAPIKeys)))
        actions.addArrangedSubview(NSButton(title: "MIDI-Ausgabe …", target: self, action: #selector(menuMIDIOutput)))
        actions.addArrangedSubview(NSButton(title: "CLAB öffnen …", target: self, action: #selector(openCLABPressed)))
        actions.addArrangedSubview(NSButton(title: "CLAB sichern …", target: self, action: #selector(saveCLABPressed)))
        actions.addArrangedSubview(NSButton(title: "JSON sichern …", target: self, action: #selector(saveJSONPressed)))
        root.addArrangedSubview(actions)

        let tabs = NSTabView()
        tabs.translatesAutoresizingMaskIntoConstraints = false

        let validationTab = NSTabViewItem(identifier: "validation")
        validationTab.label = "Technische Prüfung"
        validationView.isEditable = false
        validationTab.view = textScroll(validationView, minHeight: 360)
        tabs.addTabViewItem(validationTab)

        let jsonTab = NSTabViewItem(identifier: "json")
        jsonTab.label = "JSON"
        jsonView.isEditable = false
        jsonTab.view = textScroll(jsonView, minHeight: 360)
        tabs.addTabViewItem(jsonTab)

        let historyTab = NSTabViewItem(identifier: "history")
        historyTab.label = "Verlauf"
        historyTab.view = buildHistoryTab()
        tabs.addTabViewItem(historyTab)

        root.addArrangedSubview(tabs)
        tabs.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        tabs.heightAnchor.constraint(greaterThanOrEqualToConstant: 430).isActive = true
    }

    @objc private func v662DeletePieceSlot(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0, index < pieceSlots.count else { return }
        guard pieceSlots[index] != nil else {
            status("Stück-Slot \(index + 1) ist bereits leer.", good: true)
            return
        }
        pieceSlots[index] = nil
        if index == activePieceSlot { clearCurrentPiece() }
        updatePieceSlotButtons()
        status("Stück-Slot \(index + 1) gelöscht.", good: true)
    }

    @objc private func v307SaveCLABPressed() {
        guard let score = lastScore else {
            status("Keine Komposition zum Sichern vorhanden.", good: false)
            NSSound.beep()
            return
        }

        saveSettingsFromUI()
        let currentProvider = lastProvider ?? provider
        let currentModel = lastModel ?? model
        let doc = V307CLABDocument(
            format: "composition-lab-clab",
            version: 3,
            title: score.ti,
            score: score,
            compositionAssignment: promptView.string,
            compositionIdea: conceptView.string,
            provider: currentProvider,
            model: currentModel,
            settings: settings,
            createdAt: Date()
        )

        let panel = NSSavePanel()
        panel.allowedFileTypes = ["clab"]
        panel.nameFieldStringValue = safeFilename(score.ti) + ".clab"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try JSONEncoder.pretty.encode(doc)
            try data.write(to: url, options: .atomic)
            status("CLAB gespeichert: \(url.lastPathComponent) · Auftrag und Kompositionsidee sind enthalten.", good: true)
        } catch {
            status("CLAB konnte nicht gespeichert werden: \(error.localizedDescription)", good: false)
            NSSound.beep()
        }
    }

    @objc private func v307LoadCLABPressed() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["clab"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "CLAB-Datei laden"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        v307LoadCLAB(url, intoPieceSlot: activePieceSlot)
    }

    private func v307LoadCLAB(_ url: URL, intoPieceSlot index: Int) {
        guard index >= 0, index < pieceSlots.count else { return }
        do {
            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(V307CLABDocument.self, from: data)
            guard doc.format == "composition-lab-clab", doc.version >= 3 else {
                throw NSError(domain: "CompositionLab.CLAB", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Kein Composition-Lab-3-CLAB-Dokument."])
            }

            // Explicit CLAB loading restores the musical working state as well
            // as the score. This is different from merely browsing another slot.
            settings = doc.settings
            restoreSettings()
            activePieceSlot = index
            promptView.string = doc.compositionAssignment
            conceptView.string = doc.compositionIdea
            lastConcept = doc.compositionIdea

            slotSelectionLoad = true
            install(score: doc.score,
                    concept: doc.compositionIdea,
                    provider: doc.provider,
                    model: doc.model,
                    addHistory: false)
            slotSelectionLoad = false

            // install() may touch legacy state; assert the CLAB working text again.
            promptView.string = doc.compositionAssignment
            conceptView.string = doc.compositionIdea
            lastConcept = doc.compositionIdea

            captureCurrentInActiveSlot()
            updatePieceSlotButtons()
            scheduleMusicXMLPreviewRefresh()
            saveSettingsFromUI()
            status("CLAB geladen: \(doc.title) · Auftrag und Kompositionsidee wiederhergestellt.", good: true)
        } catch {
            // Backward compatibility: let the existing legacy CLAB importer try
            // older files created before the 3.x central CLAB document.
            status("Älteres CLAB-Format erkannt – versuche kompatibles Laden …", good: true)
            importFile(url, intoPieceSlot: index)
        }
    }

    @objc private func v651LoadMIDIIntoSlot(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mid", "midi"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "MIDI-Datei in Stück-Slot \(sender.tag + 1) laden"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(url, intoPieceSlot: sender.tag)
    }

    @objc private func v651LoadCLABIntoSlot(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["clab"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "CLAB-Datei in Stück-Slot \(sender.tag + 1) laden"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        v307LoadCLAB(url, intoPieceSlot: sender.tag)
    }

    @objc private func v65ProjectAction(_ sender: NSPopUpButton) {
        let choice = sender.indexOfSelectedItem
        sender.selectItem(at: 0)
        switch choice {
        case 1:
            menuNameProject()
            v65ProjectLabel.stringValue = "Projekt: \(projectName)"
        case 2:
            v65SaveProject()
        case 3:
            v65LoadProject()
        case 4:
            menuExportBackup()
        case 5:
            menuImportBackup()
        default:
            break
        }
    }

    @objc private func v65NotationTempoChanged() {
        playerTempoField.stringValue = notationPlayerTempoField.stringValue
        playerTempoChanged()
        notationPlayerTempoField.stringValue = playerTempoField.stringValue
    }

    @objc private func v65NotationVolumeChanged() {
        playerVolume.doubleValue = notationPlayerVolume.doubleValue
        playerVolumeChanged()
    }

    @objc private func v65NotationLoopChanged() {
        playerLoopButton.state = notationPlayerLoopButton.state
        playerLoopChanged()
        notationPlayerLoopButton.title = playerLoopButton.title
        notationPlayerLoopButton.contentTintColor = playerLoopButton.contentTintColor
    }

    private func v65SaveProject() {
        captureCurrentInActiveSlot()
        saveSettingsFromUI()
        var doc = V65ProjectDocument(format: "composition-lab-v6-project",
                                     name: projectName,
                                     activeSlot: activePieceSlot,
                                     slots: pieceSlots,
                                     settings: settings,
                                     history: history)
        doc.concept = conceptView.string; doc.chat = chatView.string; doc.extraFields = workspaceExtraFields
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["clabproject"]
        panel.nameFieldStringValue = safeFilename(projectName) + ".clabproject"
        if let url = projectURL { panel.directoryURL = url.deletingLastPathComponent() }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONEncoder.pretty.encode(doc)
            try data.write(to: url, options: .atomic)
            projectURL = url
            v65ProjectLabel.stringValue = "Projekt: \(projectName)"
            updateWindowTitle()
            status("Projekt „\(projectName)“ mit allen 10 Stück-Slots gespeichert.", good: true)
        } catch {
            status("Projekt konnte nicht gespeichert werden: \(error.localizedDescription)", good: false)
        }
    }

    private func v65LoadProject() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["clabproject"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadWorkspaceProject(url: url)
    }

    private func loadWorkspaceProject(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            try CoreServices.validateWorkspace(data)
            let doc = try JSONDecoder().decode(V65ProjectDocument.self, from: data)
            guard doc.format == "composition-lab-v6-project" else {
                throw NSError(domain: "CompositionLab.V65", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Unbekanntes V6-Projektformat."])
            }
            workspaceExtraFields = doc.extraFields
            if let chat = doc.chat { chatView.string = chat }
            projectName = doc.name
            projectURL = url
            settings = doc.settings
            history = doc.history
            pieceSlots = Array(doc.slots.prefix(10))
            if pieceSlots.count < 10 { pieceSlots.append(contentsOf: [HistoryItem?](repeating: nil, count: 10 - pieceSlots.count)) }
            activePieceSlot = max(0, min(doc.activeSlot, 9))
            restoreSettings()
            Storage.shared.saveHistory(history)
            refreshVisibleHistories()
            updatePieceSlotButtons()
            v65ProjectLabel.stringValue = "Projekt: \(projectName)"
            updateWindowTitle()
            if let item = pieceSlots[activePieceSlot] {
                slotSelectionLoad = true
                install(score: item.score, concept: item.concept, provider: item.provider, model: item.model,
                        addHistory: false, costUSD: item.costUSD,
                        inputTokens: item.inputTokens, outputTokens: item.outputTokens, metadata: item.extraFields)
                slotSelectionLoad = false
            } else { clearCurrentPiece() }
            scheduleMusicXMLPreviewRefresh()
            status("Projekt „\(projectName)“ geladen.", good: true)
        } catch {
            status("Projekt konnte nicht geladen werden: \(error.localizedDescription)", good: false)
        }
    }

    private struct V307CLABDocument: Codable {
        var format: String
        var version: Int
        var title: String
        var score: Score
        var compositionAssignment: String
        var compositionIdea: String
        var provider: Provider
        var model: String
        var settings: AppSettings
        var createdAt: Date
    }

    @objc private func workspaceChanged() {
        let i = max(0, min(workspaceSegment.selectedSegment, workspaceViews.count - 1))
        for (index, host) in workspaceViews.enumerated() {
            host.isHidden = index != i
        }
        refreshVisibleHistories()
        if i == 1 { scheduleMusicXMLPreviewRefresh() }
    }

    private func selectWorkspace(_ index: Int) {
        workspaceSegment.selectedSegment = max(0, min(index, 2))
        workspaceChanged()
    }

    private func label(_ text:String) -> NSTextField {
        let x = NSTextField(labelWithString:text)
        x.font = .systemFont(ofSize:12, weight:.semibold)
        return x
    }

    private func title(_ text:String) -> NSTextField {
        let x = NSTextField(labelWithString:text)
        x.font = .systemFont(ofSize:17, weight:.bold)
        return x
    }

    private func textScroll(_ tv:NSTextView, minHeight:CGFloat) -> NSScrollView {
        tv.isRichText = false
        tv.font = .systemFont(ofSize: 13)
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        if let container = tv.textContainer {
            container.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            container.widthTracksTextView = true
        }

        let s = FastScrollView()
        s.borderType = .bezelBorder
        s.hasVerticalScroller = true
        s.hasHorizontalScroller = false
        s.autohidesScrollers = true
        s.documentView = tv
        s.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
        return s
    }

    private func row(_ views:[NSView], spacing:CGFloat = 8) -> NSStackView {
        let s = NSStackView(views:views)
        s.orientation = .horizontal
        s.spacing = spacing
        s.distribution = .fillEqually
        return s
    }

    private func buildLeft(_ parent:NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top:16,left:16,bottom:20,right:16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo:parent.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo:parent.trailingAnchor),
            stack.topAnchor.constraint(equalTo:parent.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo:parent.bottomAnchor)
        ])

        let brand = NSStackView()
        brand.orientation = .vertical
        brand.alignment = .centerX
        brand.spacing = 7
        brand.translatesAutoresizingMaskIntoConstraints = false
        brand.widthAnchor.constraint(equalToConstant:318).isActive = true

        let iconView = NSImageView()
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            iconView.image = icon
        } else {
            iconView.image = NSApp.applicationIconImage
        }
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.widthAnchor.constraint(equalToConstant:104).isActive = true
        iconView.heightAnchor.constraint(equalToConstant:104).isActive = true
        brand.addArrangedSubview(iconView)

        let brandTitle = NSTextField(labelWithString: "Composition Lab")
        brandTitle.font = .systemFont(ofSize:19, weight:.bold)
        brandTitle.alignment = .center
        brand.addArrangedSubview(brandTitle)
        stack.addArrangedSubview(brand)
        stack.addArrangedSubview(separatorBox())

        stack.addArrangedSubview(title("KI"))
        providerPop.addItems(withTitles: Provider.allCases.map(\.displayName))
        providerPop.target = self; providerPop.action = #selector(providerChanged)
        stack.addArrangedSubview(label("Modell-Anbieter"))
        stack.addArrangedSubview(providerPop)
        stack.addArrangedSubview(label("Modell"))
        stack.addArrangedSubview(modelPop)
        effortPop.addItems(withTitles: Effort.allCases.map(\.displayName))
        stack.addArrangedSubview(label("Qualität / Denkaufwand"))
        stack.addArrangedSubview(effortPop)

        stack.addArrangedSubview(separatorBox())
        stack.addArrangedSubview(title("Komposition"))
        let measureMeterRow = row([fieldBox("Takte", measuresField), fieldBox("Taktart", meterField)])
        measureMeterRow.widthAnchor.constraint(equalToConstant: 318).isActive = true
        stack.addArrangedSubview(measureMeterRow)
        let tempoKeyRow = row([fieldBox("Tempo", tempoField), fieldBox("Tonart", musicalKeyField)])
        tempoKeyRow.widthAnchor.constraint(equalToConstant: 318).isActive = true
        stack.addArrangedSubview(tempoKeyRow)
        stack.addArrangedSubview(label("Besetzung"))
        stack.addArrangedSubview(ensembleField)
        stack.addArrangedSubview(label("Kompositionsauftrag"))
        let ps = textScroll(promptView, minHeight:120)
        ps.widthAnchor.constraint(equalToConstant:318).isActive = true
        stack.addArrangedSubview(ps)

        let compose = NSButton(title:"Mit gewählter KI komponieren", target:self, action:#selector(composePressed))
        compose.bezelStyle = .rounded
        compose.keyEquivalent = "\r"
        stack.addArrangedSubview(compose)

        let reset = NSButton(title:"Felder zurücksetzen", target:self, action:#selector(resetFields))
        stack.addArrangedSubview(reset)

        // Kompakter Verlauf innerhalb des bereits vorhandenen linken Scrollbereichs.
        // Dadurch entstehen keinerlei neue Anforderungen an die Hauptfenstergröße.
        stack.addArrangedSubview(separatorBox())
        stack.addArrangedSubview(compositionHistoryFooter)
        compositionHistoryFooter.widthAnchor.constraint(equalToConstant: 318).isActive = true

        for v in stack.arrangedSubviews {
            if !(v is NSBox) { v.widthAnchor.constraint(lessThanOrEqualToConstant:318).isActive = true }
        }
    }

    private func buildNotationPieceSlotBar() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.addArrangedSubview(title("Stücke / Varianten"))
        titleRow.addArrangedSubview(NSView())
        let hint = NSTextField(labelWithString: "Stück auswählen und direkt im Notenbild ansehen")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        titleRow.addArrangedSubview(hint)
        stack.addArrangedSubview(titleRow)
        titleRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.spacing = 7
        var buttons: [NSButton] = []
        for i in 0..<10 {
            let b = NSButton(title: "\(i + 1)", target: self, action: #selector(pieceSlotPressed(_:)))
            b.tag = i
            b.bezelStyle = .rounded
            b.setButtonType(.toggle)
            b.heightAnchor.constraint(equalToConstant: 38).isActive = true
            buttons.append(b)
            row.addArrangedSubview(b)
        }
        notationPieceSlotButtons = buttons
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        updatePieceSlotButtons()
        return stack
    }

    private func updatePieceSlotButtons() {
        for (i, b) in mainPieceSlotButtons.enumerated() where i < pieceSlots.count {
            if let item = pieceSlots[i] {
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let short = title.count > 54 ? String(title.prefix(53)) + "…" : title
                b.title = "\(i + 1)\n\(short)"
                b.toolTip = item.title
            } else {
                // Keep empty cards visually quiet. The whole card remains a drop target.
                b.title = "\(i + 1)"
                b.toolTip = "Datei auf Stück \(i + 1) ziehen"
            }
            b.state = i == activePieceSlot ? .on : .off
        }
        for (i, b) in notationPieceSlotButtons.enumerated() where i < pieceSlots.count {
            let filled = pieceSlots[i] != nil
            b.title = filled ? "●\(i + 1)" : "\(i + 1)"
            b.state = i == activePieceSlot ? .on : .off
            b.toolTip = pieceSlots[i].map { $0.title } ?? "Stück \(i + 1)"
        }
    }

    private func captureCurrentInActiveSlot() {
        guard activePieceSlot >= 0, activePieceSlot < pieceSlots.count,
              let score = lastScore else { return }
        let p = lastProvider ?? provider
        let m = lastModel ?? model
        lastPortableMetadata["description"] = .string(conceptView.string)
        lastPortableMetadata["assignment"] = .string(promptView.string)
        pieceSlots[activePieceSlot] = HistoryItem(id: pieceSlots[activePieceSlot]?.id ?? UUID(),
                                                  time: Date(),
                                                  title: score.ti,
                                                  provider: p,
                                                  model: m,
                                                  concept: lastConcept,
                                                  score: score,
                                                  costUSD: lastCostUSD,
                                                  inputTokens: lastInputTokens,
                                                  outputTokens: lastOutputTokens,
                                                  area: .composition,
                                                  extraFields: lastPortableMetadata)
        updatePieceSlotButtons()
    }

    private func clearCurrentPiece() {
        nativeWorkspaceGeneration += 1
        lastScore = nil; lastMidi = nil; lastConcept = ""; lastPortableMetadata = [:]; lastLilyPondOutput = nil
        midiPlayer.stop(); conceptView.string = ""; jsonView.string = ""; validationView.string = ""
        musicXMLPreview.setMusicXML(nil); resultLabel.stringValue = "Noch keine Komposition."
        musicXMLCurrentLabel.stringValue = "Aktuelles Stück: –"
        updatePlayerTime()
    }

    @objc private func pieceSlotPressed(_ sender: NSButton) {
        let newIndex = sender.tag
        guard newIndex >= 0, newIndex < pieceSlots.count, newIndex != activePieceSlot else { return }
        captureCurrentInActiveSlot()
        activePieceSlot = newIndex
        guard let item = pieceSlots[newIndex] else {
            clearCurrentPiece(); updatePieceSlotButtons()
            status("Stück-Slot \(newIndex + 1) ist leer.", good: true); return
        }
        slotSelectionLoad = true
        install(score: item.score, concept: item.concept, provider: item.provider, model: item.model,
                addHistory: false, costUSD: item.costUSD, inputTokens: item.inputTokens,
                outputTokens: item.outputTokens, metadata: item.extraFields)
        slotSelectionLoad = false
        if case .string(let assignment)? = item.extraFields["assignment"] { promptView.string = assignment }
        updatePieceSlotButtons(); scheduleMusicXMLPreviewRefresh()
        status("Stück \(newIndex + 1) geladen: \(item.title).", good: true)
    }

    @objc private func generateMotifPressed() {
        let alert = NSAlert()
        alert.messageText = "Musikalisches Motiv"
        alert.informativeText = "Wie lang soll das Motiv sein? Der Auftrag wird als Kompositionsidee vorbereitet; Komponieren setzt ihn anschließend um."
        alert.addButton(withTitle: "2 Takte")
        alert.addButton(withTitle: "4 Takte")
        alert.addButton(withTitle: "8 Takte")
        alert.addButton(withTitle: "Abbrechen")
        let response = alert.runModal()
        let bars: Int
        switch response {
        case .alertFirstButtonReturn: bars = 2
        case .alertSecondButtonReturn: bars = 4
        case .alertThirdButtonReturn: bars = 8
        default: return
        }

        // A motif request first prepares the editable composition idea.
        // Only the explicit Compose button starts the musical draft pipeline.
        measuresField.stringValue = String(bars)
        let task = "Komponiere ein prägnantes musikalisches Motiv von \(bars) Takten als Ausgangspunkt für eine spätere Komposition. Übernimm die aktuell gewählte Besetzung, Tonart, Taktart und das Tempo."
        promptView.string = task
        conceptView.string = "\(bars) Takte · \(meterField.stringValue) · \(tempoField.stringValue) BPM · \(musicalKeyField.stringValue) · \(ensembleField.stringValue)\n\nKurzes, eigenständiges Motiv; musikalische Ausarbeitung erfolgt erst mit Komponieren."
        musicChatCompositionContextOverride = ""
        importedReferenceScore = nil
        importedReferenceName = nil
        chatInput.stringValue = ""
        saveSettingsFromUI()
        status("Motivauftrag und Kompositionsidee vorbereitet. Mit Komponieren umsetzen.", good: true)
    }

    private func buildNotationTransport() -> NSView {
        let panel = v64Panel()
        panel.contentViewMargins = NSSize(width: 10, height: 6)
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
        panel.contentView = row

        row.addArrangedSubview(NSButton(title: "▶Ⅱ", target: self, action: #selector(playCurrentMIDI)))
        row.addArrangedSubview(NSButton(title: "■", target: self, action: #selector(stopCurrentMIDI)))
        notationPlayerLoopButton.setButtonType(.toggle)
        notationPlayerLoopButton.bezelStyle = .rounded
        notationPlayerLoopButton.target = self
        notationPlayerLoopButton.action = #selector(v65NotationLoopChanged)
        row.addArrangedSubview(notationPlayerLoopButton)
        row.addArrangedSubview(notationPlayerTimeLabel)

        notationPlayerProgress.target = self
        notationPlayerProgress.action = #selector(notationPlayerSeekChanged)
        notationPlayerProgress.isContinuous = true
        notationPlayerProgress.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        row.addArrangedSubview(notationPlayerProgress)

        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        notationPlayerTempoField.stringValue = playerTempoField.stringValue
        notationPlayerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        notationPlayerTempoField.target = self
        notationPlayerTempoField.action = #selector(v65NotationTempoChanged)
        row.addArrangedSubview(notationPlayerTempoField)

        row.addArrangedSubview(NSTextField(labelWithString: "Lautstärke"))
        notationPlayerVolume.doubleValue = playerVolume.doubleValue
        notationPlayerVolume.widthAnchor.constraint(equalToConstant: 120).isActive = true
        notationPlayerVolume.target = self
        notationPlayerVolume.action = #selector(v65NotationVolumeChanged)
        notationPlayerVolume.isContinuous = true
        row.addArrangedSubview(notationPlayerVolume)
        return panel
    }

    @objc private func notationPlayerSeekChanged() {
        midiPlayer.seek(fraction: notationPlayerProgress.doubleValue)
        playerProgress.doubleValue = notationPlayerProgress.doubleValue
        updatePlayerTime()
    }

    private func separatorBox() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func fieldBox(_ title:String, _ field:NSTextField) -> NSView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 3
        s.addArrangedSubview(label(title))
        s.addArrangedSubview(field)
        field.widthAnchor.constraint(greaterThanOrEqualToConstant:145).isActive = true
        return s
    }

    private func buildRight(_ parent:NSView) {
        let outer = NSStackView()
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = 10
        outer.edgeInsets = NSEdgeInsets(top:16,left:16,bottom:16,right:16)
        outer.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo:parent.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo:parent.trailingAnchor),
            outer.topAnchor.constraint(equalTo:parent.topAnchor),
            outer.bottomAnchor.constraint(equalTo:parent.bottomAnchor)
        ])

        let topSplit = NSSplitView()
        topSplit.isVertical = true
        topSplit.dividerStyle = .thin
        topSplit.heightAnchor.constraint(equalToConstant:330).isActive = true
        outer.addArrangedSubview(topSplit)
        topSplit.widthAnchor.constraint(equalTo:outer.widthAnchor).isActive = true

        let cbox = NSView(), rbox = NSView()
        topSplit.addArrangedSubview(cbox); topSplit.addArrangedSubview(rbox)

        let cstack = NSStackView()
        cstack.orientation = .vertical; cstack.alignment = .leading; cstack.spacing = 6
        cstack.translatesAutoresizingMaskIntoConstraints = false; cbox.addSubview(cstack)
        NSLayoutConstraint.activate([cstack.leadingAnchor.constraint(equalTo:cbox.leadingAnchor),
                                     cstack.trailingAnchor.constraint(equalTo:cbox.trailingAnchor),
                                     cstack.topAnchor.constraint(equalTo:cbox.topAnchor),
                                     cstack.bottomAnchor.constraint(equalTo:cbox.bottomAnchor)])
        cstack.addArrangedSubview(title("Kompositionsidee"))
        let cs = textScroll(conceptView, minHeight:275)
        cstack.addArrangedSubview(cs); cs.widthAnchor.constraint(equalTo:cstack.widthAnchor).isActive = true
        conceptView.isEditable = true

        let rstack = NSStackView()
        rstack.orientation = .vertical; rstack.alignment = .leading; rstack.spacing = 8
        rstack.translatesAutoresizingMaskIntoConstraints = false; rbox.addSubview(rstack)
        NSLayoutConstraint.activate([rstack.leadingAnchor.constraint(equalTo:rbox.leadingAnchor, constant:10),
                                     rstack.trailingAnchor.constraint(equalTo:rbox.trailingAnchor),
                                     rstack.topAnchor.constraint(equalTo:rbox.topAnchor),
                                     rstack.bottomAnchor.constraint(equalTo:rbox.bottomAnchor)])
        rstack.addArrangedSubview(title("Aktuelle Komposition"))
        rstack.addArrangedSubview(resultLabel)

        let playerStack = NSStackView()
        playerStack.orientation = .vertical; playerStack.alignment = .leading; playerStack.spacing = 5
        let transportRow = NSStackView()
        transportRow.orientation = .horizontal; transportRow.spacing = 6
        let playButton = NSButton(title:"▶Ⅱ", target:self, action:#selector(playCurrentMIDI))
        let pauseButton = NSButton(title:"Ⅱ", target:self, action:#selector(pauseCurrentMIDI))
        let stopButton = NSButton(title:"■", target:self, action:#selector(stopCurrentMIDI))
        transportRow.addArrangedSubview(playButton); transportRow.addArrangedSubview(pauseButton); transportRow.addArrangedSubview(stopButton)
        playerLoopButton.setButtonType(.toggle)
        playerLoopButton.bezelStyle = .rounded
        playerLoopButton.target = self
        playerLoopButton.action = #selector(playerLoopChanged)
        transportRow.addArrangedSubview(playerLoopButton)
        playerStack.addArrangedSubview(transportRow)

        let progressRow = NSStackView()
        progressRow.orientation = .horizontal; progressRow.spacing = 8
        playerProgress.target = self; playerProgress.action = #selector(playerSeekChanged)
        playerProgress.isContinuous = true; playerProgress.widthAnchor.constraint(equalToConstant: 250).isActive = true
        progressRow.addArrangedSubview(playerProgress); progressRow.addArrangedSubview(playerTimeLabel)
        playerStack.addArrangedSubview(progressRow)

        let tempoPlayerRow = NSStackView()
        tempoPlayerRow.orientation = .horizontal; tempoPlayerRow.spacing = 8
        tempoPlayerRow.addArrangedSubview(NSTextField(labelWithString:"Tempo"))
        playerTempoField.alignment = .right
        playerTempoField.target = self; playerTempoField.action = #selector(playerTempoChanged)
        playerTempoField.widthAnchor.constraint(equalToConstant: 58).isActive = true
        tempoPlayerRow.addArrangedSubview(playerTempoField)
        tempoPlayerRow.addArrangedSubview(NSTextField(labelWithString:"BPM"))
        playerTempoStepper.minValue = 20; playerTempoStepper.maxValue = 400; playerTempoStepper.increment = 1
        playerTempoStepper.target = self; playerTempoStepper.action = #selector(playerTempoStepperChanged)
        tempoPlayerRow.addArrangedSubview(playerTempoStepper)
        playerStack.addArrangedSubview(tempoPlayerRow)

        let volumeRow = NSStackView()
        volumeRow.orientation = .horizontal; volumeRow.spacing = 8
        playerVolume.target = self; playerVolume.action = #selector(playerVolumeChanged)
        playerVolume.isContinuous = true; playerVolume.widthAnchor.constraint(equalToConstant: 180).isActive = true
        let speaker = NSTextField(labelWithString:"🔊 Lautstärke")
        volumeRow.addArrangedSubview(speaker); volumeRow.addArrangedSubview(playerVolume)
        playerStack.addArrangedSubview(volumeRow)
        rstack.addArrangedSubview(playerStack)

        let importMIDI = NSButton(title:"MIDI / MusicXML / CLAB laden …", target:self, action:#selector(importMIDIPressed))
        importMIDI.bezelStyle = .rounded
        let clearMIDI = NSButton(title:"Vorlage löschen", target:self, action:#selector(clearImportedMIDIPressed))
        clearMIDI.bezelStyle = .rounded
        rstack.addArrangedSubview(row([importMIDI, clearMIDI]))

        let saveCLAB = NSButton(title:"CLAB sichern …", target:self, action:#selector(saveCLABPressed))
        saveCLAB.bezelStyle = .rounded
        let openCLAB = NSButton(title:"CLAB öffnen …", target:self, action:#selector(openCLABPressed))
        openCLAB.bezelStyle = .rounded
        rstack.addArrangedSubview(row([saveCLAB, openCLAB]))

        let midi = ExportDragButton(title:"MIDI sichern / ziehen …", target:self, action:#selector(saveMIDIPressed))
        midi.toolTip = "Klicken zum Speichern oder fertige MIDI-Datei aus Composition Lab herausziehen"
        midi.exportFileProvider = { [weak self] in self?.temporaryMIDIExportURL() }
        let json = NSButton(title:"JSON sichern …", target:self, action:#selector(saveJSONPressed))
        rstack.addArrangedSubview(row([midi,json]))

        let tools = NSStackView()
        tools.orientation = .horizontal
        tools.spacing = 8
        let chatButton = NSButton(title:"Mit der KI über Impuls / Partitur sprechen …", target:self, action:#selector(showChatPanel))
        let checkButton = NSButton(title:"Technische Prüfung", target:self, action:#selector(showValidationPanel))
        let jsonButton = NSButton(title:"Technik / JSON", target:self, action:#selector(showJSONPanel))
        let historyButton = NSButton(title:"Verlauf", target:self, action:#selector(showHistoryPanel))
        let closeButton = NSButton(title:"Bereich schließen", target:self, action:#selector(closeWorkPanel))
        tools.addArrangedSubview(chatButton); tools.addArrangedSubview(checkButton); tools.addArrangedSubview(jsonButton); tools.addArrangedSubview(historyButton); tools.addArrangedSubview(closeButton)
        outer.addArrangedSubview(tools)

        // Die sichtbare Werkzeugleiste oben ist die einzige Navigation.
        // Die interne NSTabView dient nur zum Umschalten der Inhalte und zeigt keine zweite Tableiste.
        workTabs.tabViewType = .noTabsNoBorder

        let chatTab = NSTabViewItem(identifier:"chat"); chatTab.label = "KI-Chat / Überarbeiten"
        let valTab = NSTabViewItem(identifier:"validation"); valTab.label = "Technische Prüfung"
        let jsonTab = NSTabViewItem(identifier:"json"); jsonTab.label = "Technik / JSON"
        let historyTab = NSTabViewItem(identifier:"history"); historyTab.label = "Verlauf"
        workTabs.addTabViewItem(chatTab); workTabs.addTabViewItem(valTab); workTabs.addTabViewItem(jsonTab); workTabs.addTabViewItem(historyTab)
        chatTab.view = buildChatTab()
        valTab.view = textScroll(validationView, minHeight:260)
        validationView.isEditable = false
        jsonTab.view = textScroll(jsonView, minHeight:260)
        jsonView.isEditable = false
        historyTab.view = buildHistoryTab()
        outer.addArrangedSubview(workTabs)
        workTabs.widthAnchor.constraint(equalTo:outer.widthAnchor).isActive = true
        workTabsHeight = workTabs.heightAnchor.constraint(equalToConstant:0)
        workTabsHeight?.isActive = true
        workTabs.isHidden = true
    }

    @objc private func showChatPanel() {
        openWorkPanel(identifier: "chat")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.chatInput.isEditable = true
            self.chatInput.isSelectable = true
            self.chatInput.window?.makeFirstResponder(self.chatInput)
        }
    }
    @objc private func showValidationPanel() { openWorkPanel(identifier: "validation") }
    @objc private func showJSONPanel() { openWorkPanel(identifier: "json") }
    @objc private func showHistoryPanel() {
        history = Storage.shared.loadHistory()
        historyTable.reloadData()
        openWorkPanel(identifier: "history")
    }
    @objc private func closeWorkPanel() {
        workTabsOpen = false
        workTabs.isHidden = true
        workTabsHeight?.constant = 0
    }
    private func openWorkPanel(identifier: String) {
        if let item = workTabs.tabViewItems.first(where: { ($0.identifier as? String) == identifier }) { workTabs.selectTabViewItem(item) }
        workTabs.isHidden = false
        workTabsOpen = true
        workTabsHeight?.constant = 390
    }

    private func buildChatTab() -> NSView {
        let v = NSView()
        let s = NSStackView()
        s.orientation = .vertical; s.spacing = 8
        s.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(s)
        NSLayoutConstraint.activate([s.leadingAnchor.constraint(equalTo:v.leadingAnchor,constant:8),
                                     s.trailingAnchor.constraint(equalTo:v.trailingAnchor,constant:-8),
                                     s.topAnchor.constraint(equalTo:v.topAnchor,constant:8),
                                     s.bottomAnchor.constraint(equalTo:v.bottomAnchor,constant:-8)])
        let log = textScroll(chatView,minHeight:170)
        chatView.isEditable = false
        chatView.isSelectable = true

        // Robuste native Chat-Eingabe als NSTextField.
        chatInput.isEditable = true
        chatInput.isSelectable = true
        chatInput.isBezeled = true
        chatInput.bezelStyle = .roundedBezel
        chatInput.font = .systemFont(ofSize: 13)
        chatInput.placeholderString = "Änderungswunsch oder Frage an die KI …"
        chatInput.heightAnchor.constraint(equalToConstant: 48).isActive = true
        // Eingabe bewusst vor der Ausgabe: schreiben → senden → Antwort lesen.
        s.addArrangedSubview(chatInput)
        let send = NSButton(title:"An die KI senden", target:self, action:#selector(chatPressed))
        let clear = NSButton(title:"Chat löschen", target:self, action:#selector(clearChat))
        s.addArrangedSubview(row([send,clear]))
        s.addArrangedSubview(log)
        return v
    }

    private func buildHistoryTab() -> NSView {
        let v = NSView()
        let col = NSTableColumn(identifier:NSUserInterfaceItemIdentifier("main"))
        col.title = "Frühere Kompositionen"
        historyTable.addTableColumn(col)
        historyTable.headerView = nil
        historyTable.dataSource = self; historyTable.delegate = self
        historyTable.doubleAction = #selector(loadHistorySelection)
        let historyMenu = NSMenu()
        let deleteOne = NSMenuItem(title: "Löschen", action: #selector(deleteHistorySelection), keyEquivalent: "")
        deleteOne.target = self
        historyMenu.addItem(deleteOne)
        historyTable.menu = historyMenu
        let scroll = FastScrollView()
        scroll.documentView = historyTable; scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(scroll)
        let load = NSButton(title:"Ausgewählten Eintrag laden", target:self, action:#selector(loadHistorySelection))
        let clear = NSButton(title:"Verlauf löschen", target:self, action:#selector(clearHistory))
        let buttons = row([load,clear]); buttons.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(buttons)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo:v.leadingAnchor,constant:8),
            scroll.trailingAnchor.constraint(equalTo:v.trailingAnchor,constant:-8),
            scroll.topAnchor.constraint(equalTo:v.topAnchor,constant:8),
            scroll.bottomAnchor.constraint(equalTo:buttons.topAnchor,constant:-8),
            buttons.leadingAnchor.constraint(equalTo:v.leadingAnchor,constant:8),
            buttons.trailingAnchor.constraint(equalTo:v.trailingAnchor,constant:-8),
            buttons.bottomAnchor.constraint(equalTo:v.bottomAnchor,constant:-8)
        ])
        return v
    }

    private func restoreCurrentPlayerState() {
        guard let state = Storage.shared.loadCurrentPlayerState() else { return }

        importedReferenceScore = state.importedReferenceScore
        importedReferenceName = state.importedReferenceName
        importedReferenceMusicXMLData = state.importedReferenceMusicXMLData

        install(score: state.score,
                concept: state.concept,
                provider: state.provider,
                model: state.model,
                addHistory: false,
                costUSD: state.costUSD,
                inputTokens: state.inputTokens,
                outputTokens: state.outputTokens)

        if let pi = Provider.allCases.firstIndex(of: state.provider) {
            providerPop.selectItem(at: pi)
            refillModels()
        }
        settings.models[state.provider.rawValue] = state.model
        refillModels()
        keyField.stringValue = SessionSecrets.shared.key(for: state.provider)
        status("\(state.score.ti) als letzter Player-Stand wiederhergestellt.", good: true)
    }

    private func restoreSettings() {
        if let i = Provider.allCases.firstIndex(of: settings.provider) { providerPop.selectItem(at:i) }
        refillModels()
        let pkey = settings.provider.rawValue
        if let e = Effort(rawValue: settings.efforts[pkey] ?? "medium"),
           let idx = Effort.allCases.firstIndex(of:e) { effortPop.selectItem(at:idx) }
        measuresField.stringValue = settings.measures
        meterField.stringValue = settings.meter
        tempoField.stringValue = settings.tempo
        musicalKeyField.stringValue = settings.key
        ensembleField.stringValue = settings.ensemble
        promptView.string = settings.prompt
        keyField.stringValue = SessionSecrets.shared.key(for: settings.provider)
        historyTable.reloadData()
    }

    private var provider: Provider { Provider.allCases[max(0,providerPop.indexOfSelectedItem)] }
    private var model: String {
        modelPop.selectedItem?.representedObject as? String ?? settings.models[provider.rawValue] ?? provider.models.first?.0 ?? ""
    }
    private var effort: Effort { Effort.allCases[max(0,effortPop.indexOfSelectedItem)] }

    private func refillModels() {
        modelPop.removeAllItems()
        var list = modelsForProvider(provider)
        let stored = settings.models[provider.rawValue]
        // Imported projects can reference a model absent from today's catalog.
        // Keep that exact ID selectable instead of silently changing the model.
        if let stored, !stored.isEmpty, !list.contains(where: { $0.0 == stored }) { list.insert((stored, stored), at: 0) }
        var labels = Set<String>()
        for (id, title) in list {
            let base = title == id ? id : title + " · " + id
            var label = base, suffix = 2
            while labels.contains(label) { label = base + " (\(suffix))"; suffix += 1 }
            labels.insert(label)
            modelPop.addItem(withTitle: label)
            modelPop.lastItem?.representedObject = id
            modelPop.lastItem?.toolTip = modelCatalog.models(for: provider).first(where: { $0.id == id })?.details
        }
        if let stored, let item = modelPop.itemArray.first(where: { $0.representedObject as? String == stored }) { modelPop.select(item) }
        else { modelPop.selectItem(at: 0) }
        modelPop.target = self; modelPop.action = #selector(providerModelChanged)
        keyLabel.stringValue = "API-Key für \(provider.displayName)"
        keyField.placeholderString = "\(provider.displayName) API-Key"
    }

    @objc private func providerModelChanged() { saveSettingsFromUI() }

    @objc func menuRefreshModels() { refreshProviderModels() }

    @objc private func refreshProviderModels() {
        let selectedProvider = provider
        let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { status("Bitte zuerst den API-Schlüssel dieses Providers eintragen.", good: false); return }
        modelCatalogGeneration += 1
        let generation = modelCatalogGeneration
        let selectedModel = model
        status("Vollständige Modellliste wird geladen …", good: true)
        NativeModelCatalogClient().list(provider: selectedProvider, key: key) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.modelCatalogGeneration == generation,
                      self.provider == selectedProvider,
                      self.keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) == key else { return }
                switch result {
                case .success(let models):
                    self.modelCatalog.accept(models, for: selectedProvider)
                    self.settings.models[selectedProvider.rawValue] = selectedModel
                    self.refillModels()
                    self.status("\(models.count) Modelle vollständig vom Provider geladen.", good: true)
                case .failure(let error): self.status(error.localizedDescription, good: false)
                }
            }
        }
    }

    @objc private func providerChanged() {
        if let oldModel = modelPop.selectedItem?.representedObject as? String { settings.models[settings.provider.rawValue] = oldModel }
        settings.efforts[settings.provider.rawValue] = effort.rawValue
        settings.provider = provider
        modelCatalogGeneration += 1
        refillModels()
        let selectedEffort = Effort(rawValue: settings.efforts[provider.rawValue] ?? "medium") ?? .medium
        effortPop.selectItem(at: Effort.allCases.firstIndex(of: selectedEffort) ?? 1)
        keyField.stringValue = SessionSecrets.shared.key(for: provider)
        Storage.shared.saveSettings(settings)
    }

    private func saveSettingsFromUI() {
        settings.provider = provider
        settings.models[provider.rawValue] = model
        settings.efforts[provider.rawValue] = effort.rawValue
        settings.measures = measuresField.stringValue
        settings.meter = meterField.stringValue
        settings.tempo = tempoField.stringValue
        settings.key = musicalKeyField.stringValue
        settings.ensemble = ensembleField.stringValue
        settings.prompt = promptView.string
        settings.zoomPercent = Int(round(zoomFactor * 100))
        Storage.shared.saveSettings(settings)
    }

    @objc private func saveKeyPressed() {
        SessionSecrets.shared.set(keyField.stringValue, for:provider)
        status("API-Key für \(provider.displayName) dauerhaft lokal gespeichert.", good:true)
    }

    @objc private func deleteKeyPressed() {
        SessionSecrets.shared.remove(provider)
        keyField.stringValue = ""
        status("API-Key dauerhaft gelöscht.", good:true)
    }

    @objc private func loadKeyPressed() {
        keyField.stringValue = SessionSecrets.shared.key(for:provider)
        status(keyField.stringValue.isEmpty ? "Für diesen Anbieter ist noch kein API-Key gespeichert." : "Gespeicherter API-Key ist geladen.", good: !keyField.stringValue.isEmpty)
    }

    @objc private func resetFields() {
        measuresField.stringValue = ""; meterField.stringValue = ""; tempoField.stringValue = ""
        musicalKeyField.stringValue = ""; ensembleField.stringValue = ""
        promptView.string = "Komponiere ein eigenständiges, musikalisch überzeugendes Stück."
    }

    private func compositionInput() throws -> CoreServices.CompositionInput {
        let parameters = ["ensemble": ensembleField.stringValue, "measures": measuresField.stringValue,
                          "meter": meterField.stringValue, "tempo": tempoField.stringValue, "key": musicalKeyField.stringValue]
        var source: Data?
        if let reference = importedReferenceScore, let score = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(reference)) {
            source = try? JSONSerialization.data(withJSONObject: ["name": importedReferenceName ?? "importierte Vorlage", "score": score])
        }
        let input = try CoreServices.compositionInput(chat: chatInput.stringValue, idea: conceptView.string, fallback: promptView.string,
            parametersJSON: JSONEncoder().encode(parameters), sourceJSON: source)
        if input.localSource != nil { return input }
        var result = input.assignment
        if !musicChatCompositionContextOverride.isEmpty { result += "\n\nMUSICCHAT-ARBEITSMATERIAL:\n" + musicChatCompositionContextOverride }
        return CoreServices.CompositionInput(assignment: result, localSource: nil)
    }

    private func conceptDisplay(_ concept: String, provider: Provider, model: String) -> String {
        let modelName = provider.models.first(where: { $0.0 == model })?.1 ?? model
        return "KI: \(provider.displayName) · \(modelName)\n\n\(concept)"
    }

    @objc private func composePressed() {
        guard !nativeRequestInFlight else { status("Bitte die laufende Anfrage abwarten.", good: false); return }
        let p = provider, m = model
        let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let destination = (pieceSlots[activePieceSlot] == nil ? activePieceSlot : pieceSlots.firstIndex(where: { $0 == nil })) else {
            status("Alle 10 Stück-Slots sind belegt. Bitte zuerst einen Slot freimachen.", good: false); return
        }
        let input: CoreServices.CompositionInput
        do { input = try compositionInput() }
        catch { status(error.localizedDescription, good: false); return }
        if input.localSource == nil && key.isEmpty { status("Bitte API-Key für \(p.displayName) eingeben.", good: false); return }
        let assignment = input.assignment
        saveSettingsFromUI()
        nativeRequestGeneration += 1
        let generation = nativeRequestGeneration
        nativeRequestInFlight = true
        if let original = input.localSource {
            let diagnostic: [String: Any] = ["stage": "local-source-import", "composition": original, "assignment": original,
                "interface": "macOS AppKit", "interfaceVersion": CoreServices.version, "estimatedCostUSD": 0.0,
                "inputTokens": 0, "outputTokens": 0, "compositionAICalls": 0, "conversionAICalls": 0]
            lastDiagnostic = diagnostic
            if let saved = try? JSONSerialization.data(withJSONObject: diagnostic) {
                AppPreferences.standard.set(saved, forKey: "CompositionLab.v4.pendingComposition")
            }
            status("Vorhandener Notentext wird lokal übernommen …", good: true)
            acceptOriginalResponse(original, diagnostic: diagnostic, assignment: assignment, provider: p, model: m, destination: destination, generation: generation)
            return
        }
        let request: [String: Any] = ["assignment": assignment, "provider": p.rawValue, "model": m, "effort": effort.rawValue]
        guard let data = try? JSONSerialization.data(withJSONObject: request) else { nativeRequestInFlight = false; return }
        status("KI komponiert …", good: true)
        nativeRequestHandle = CoreServices.chat(requestJSON: data, apiKey: key, compositionOnly: true) { [weak self] response in
            DispatchQueue.main.async {
                guard let self, self.nativeRequestGeneration == generation else { return }
                switch response {
                case .failure(let error): self.nativeRequestInFlight = false; self.status(error.localizedDescription, good: false)
                case .success(let data):
                    do {
                        var diagnostic = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                        diagnostic["interface"] = "macOS AppKit"; diagnostic["interfaceVersion"] = CoreServices.version
                        diagnostic["conversionAICalls"] = 0
                        self.lastDiagnostic = diagnostic
                        let original = diagnostic["composition"] as? String ?? ""
                        // Preserve the paid answer before parsing or engraving can fail.
                        AppPreferences.standard.set(data, forKey: "CompositionLab.v4.pendingComposition")
                        self.status("Originalantwort gesichert. Lokale Ausgabe wird erzeugt …", good: true)
                        self.acceptOriginalResponse(original, diagnostic: diagnostic, assignment: assignment, provider: p, model: m, destination: destination, generation: generation)
                    } catch { self.nativeRequestInFlight = false; self.status(error.localizedDescription, good: false) }
                }
            }
        }
    }

    private func acceptOriginalResponse(_ original: String, diagnostic: [String: Any], assignment: String,
                                        provider p: Provider, model m: String, destination: Int, generation: Int) {
        NativeLocalCompositionService(compiler: localCompiler).interpret(original) { result in
            DispatchQueue.main.async {
                guard self.nativeRequestGeneration == generation else { return }
                self.nativeRequestInFlight = false
                switch result {
                case .failure(let error):
                    var failed = diagnostic; failed["stage"] = "local-output-failed"; failed["error"] = error.localizedDescription
                    self.lastDiagnostic = failed
                    self.status("Original gesichert; Ausgabe fehlgeschlagen: " + error.localizedDescription, good: false)
                case .success(nil):
                    if self.lastScore == nil { self.conceptView.string = original } else { self.appendChat("Originalantwort", original) }
                    self.status("Original gesichert. Das Format ist nicht lokal lesbar; keine automatische zweite KI-Anfrage.", good: false)
                case .success(.some(let work)):
                    guard self.pieceSlots[destination] == nil else { self.status("Ziel-Slot inzwischen belegt. Original bleibt in der Diagnose erhalten.", good: false); return }
                    self.pendingCompositionSlot = destination
                    var completed = diagnostic; completed["stage"] = "completed"; completed["conversionAICalls"] = 0
                    if let scoreData = try? JSONEncoder().encode(work.score), let score = try? JSONSerialization.jsonObject(with: scoreData) { completed["score"] = score }
                    self.lastDiagnostic = completed
                    var metadata = work.metadata
                    metadata["assignment"] = .string(assignment)
                    if let effort = diagnostic["reasoning"] as? String { metadata["reasoning"] = .string(effort) }
                    self.install(score: work.score, concept: original, provider: p, model: m,
                        costUSD: diagnostic["estimatedCostUSD"] as? Double,
                        inputTokens: diagnostic["inputTokens"] as? Int, outputTokens: diagnostic["outputTokens"] as? Int,
                        metadata: metadata)
                    AppPreferences.standard.removeObject(forKey: "CompositionLab.v4.pendingComposition")
                    self.status("Komposition lokal übernommen. Keine zusätzliche KI-Übertragung.", good: true)
                }
            }
        }
    }

    @objc func menuRecoverOriginal() {
        guard !nativeRequestInFlight else { return }
        guard let destination = pieceSlots.firstIndex(where: { $0 == nil }) else { status("Bitte einen Stück-Slot freimachen.", good: false); return }
        do {
            let saved = AppPreferences.standard.data(forKey: "CompositionLab.v4.pendingComposition")
            let diagnostic = try saved.map { try JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? lastDiagnostic
            guard let diagnostic, let original = diagnostic["composition"] as? String, !original.isEmpty else { throw APIError.badResponse("Keine gesicherte Originalantwort vorhanden.") }
            let p = Provider(rawValue: diagnostic["provider"] as? String ?? "") ?? provider
            let m = diagnostic["model"] as? String ?? model
            nativeRequestGeneration += 1; nativeRequestInFlight = true
            acceptOriginalResponse(original, diagnostic: diagnostic, assignment: diagnostic["assignment"] as? String ?? "",
                provider: p, model: m, destination: destination, generation: nativeRequestGeneration)
        } catch { status(error.localizedDescription, good: false) }
    }

    @objc func menuSaveLilyPond() {
        do {
            let source = try LilyPondSource.extract(conceptView.string)
            let panel = NSSavePanel(); panel.allowedFileTypes = ["ly"]
            panel.nameFieldStringValue = safeFilename(lastScore?.ti ?? "Komposition") + ".ly"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try Data(source.utf8).write(to: url, options: .atomic)
            status("LilyPond-Quelltext gespeichert.", good: true)
        } catch { status(error.localizedDescription, good: false) }
    }

    @objc func menuOpenHacklily() {
        do {
            let source = try LilyPondSource.extract(conceptView.string)
            let encoded = source.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            let url = "https://www.hacklily.org/wasm#src=" + encoded
            let value = try JSONSerialization.data(withJSONObject: [url])
            let literal = String(decoding: value, as: UTF8.self).dropFirst().dropLast()
            let html = "<!doctype html><html lang=\"de\"><meta charset=\"utf-8\"><title>An Hacklily übergeben</title><p>Die Komposition wird in Hacklily geöffnet.</p><script>location.replace(" + literal + ");</script></html>"
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("CompositionLab-Hacklily-" + UUID().uuidString + ".html")
            try Data(html.utf8).write(to: file, options: .atomic)
            NSWorkspace.shared.open(file)
        } catch { status(error.localizedDescription, good: false) }
    }

    private func loadOriginalPreview() {
        lastLilyPondOutput = nil
        guard case .bool(true)? = lastPortableMetadata["directLilyPond"] else { return }
        let text: String
        if case .string(let edited)? = lastPortableMetadata["lilyPondSource"] { text = edited } else { text = lastConcept }
        guard let source = try? LilyPondSource.extract(text) else { return }
        let generation = nativeWorkspaceGeneration
        localCompiler.compile(source) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.nativeWorkspaceGeneration == generation else { return }
                switch result {
                case .success(let output): self.lastLilyPondOutput = output; self.refreshMusicXMLPreview()
                case .failure(let error): self.status(error.localizedDescription, good: false)
                }
            }
        }
    }

    private func refreshCurrentNotation() {
        guard !nativeRequestInFlight else { status("Bitte die laufende Anfrage abwarten.", good: false); return }
        let text = conceptView.string
        guard (try? LilyPondSource.extract(text))?.contains("\\score") == true else { refreshMusicXMLPreview(); return }
        let generation = nativeWorkspaceGeneration, slot = activePieceSlot
        let original = lastConcept, metadata = lastPortableMetadata
        let p = lastProvider ?? provider, m = lastModel ?? model
        nativeRequestGeneration += 1
        let requestGeneration = nativeRequestGeneration
        nativeRequestInFlight = true
        NativeLocalCompositionService(compiler: localCompiler).interpret(text) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.nativeRequestGeneration == requestGeneration else { return }
                self.nativeRequestInFlight = false
                guard self.nativeWorkspaceGeneration == generation, self.activePieceSlot == slot, self.conceptView.string == text else { return }
                switch result {
                case .success(.some(let work)):
                    var updated = metadata
                    for (key, value) in work.metadata { updated[key] = value }
                    guard self.saveScoreUndoSnapshot() else { return }
                    self.install(score: work.score, concept: original, provider: p, model: m, addHistory: false,
                        costUSD: self.lastCostUSD, inputTokens: self.lastInputTokens, outputTokens: self.lastOutputTokens, metadata: updated)
                    self.conceptView.string = text
                    self.status("Bearbeiteter LilyPond-Code übernommen. Original bleibt erhalten.", good: true)
                case .success(nil): self.status("Kein lokal lesbarer Quelltext. Letzte gültige Fassung bleibt erhalten.", good: false)
                case .failure(let error):
                    self.lastDiagnostic = ["format": "composition-lab-native-diagnostic", "stage": "failed", "entryPoint": "edited-lilypond",
                        "composition": text, "lastValidSource": { if case .string(let applied)? = metadata["lilyPondSource"] { return applied }; return original }(),
                        "error": error.localizedDescription, "conversionAICalls": 0]
                    self.status(error.localizedDescription, good: false)
                }
            }
        }
    }

    private func revisionStep(_ operation: String) throws -> [String: Any] {
        let slots: [Any] = try pieceSlots.map { item in
            guard let item else { return NSNull() }
            return ["identity": item.id.uuidString, "document": try JSONSerialization.jsonObject(with: JSONEncoder().encode(item))] as [String: Any]
        }
        var request: [String: Any] = ["operation": operation, "slots": slots, "slot": activePieceSlot]
        if let state = scoreRevisionState { request["state"] = state }
        let result = try JSONSerialization.jsonObject(with: ScoreRevisionStore.step(JSONSerialization.data(withJSONObject: request))) as! [String: Any]
        scoreRevisionState = result["state"] as? [String: Any]
        return result
    }
    private func saveScoreUndoSnapshot() -> Bool {
        do { _ = try revisionStep("push"); return true }
        catch { status(error.localizedDescription, good: false); return false }
    }
    @objc func menuUndoScore() { restoreScoreRevision(redo: false) }
    @objc func menuRedoScore() { restoreScoreRevision(redo: true) }
    private func restoreScoreRevision(redo: Bool) {
        guard !nativeRequestInFlight else { status("Bitte die laufende Anfrage abwarten.", good: false); return }
        do {
            let result = try revisionStep(redo ? "redo" : "undo")
            guard let slot = result["slot"] as? Int, let value = result["document"] else { status("Keine weitere Partituränderung vorhanden.", good: true); return }
            let item = try JSONDecoder().decode(HistoryItem.self, from: JSONSerialization.data(withJSONObject: value))
            captureCurrentInActiveSlot(); activePieceSlot = slot; pieceSlots[slot] = item
            install(score: item.score, concept: item.concept, provider: item.provider, model: item.model,
                addHistory: false, costUSD: item.costUSD, inputTokens: item.inputTokens, outputTokens: item.outputTokens, metadata: item.extraFields)
            if case .string(let assignment)? = item.extraFields["assignment"] { promptView.string = assignment }
            v309SaveSessionMemory()
            status(redo ? "Partituränderung wiederhergestellt." : "Partituränderung rückgängig gemacht.", good: true)
        } catch { status(error.localizedDescription, good: false) }
    }

    @objc func menuCancelRequest() {
        nativeRequestGeneration += 1; nativeWorkspaceGeneration += 1
        nativeRequestHandle?.cancel(); nativeRequestHandle = nil
        nativeDialogueClient?.cancel(); nativeDialogueClient = nil
        nativeRequestInFlight = false
        status("Anfrage lokal abgebrochen. Letzte gültige Fassung bleibt erhalten.", good: true)
    }

    @objc func menuReviewRegisters() {
        guard !nativeRequestInFlight, lastScore != nil else { status("Bitte ein Stück laden und die laufende Anfrage abwarten.", good: false); return }
        let source = conceptView.string, generation = nativeWorkspaceGeneration
        let slot = activePieceSlot, original = lastConcept, metadata = lastPortableMetadata
        let p = provider, m = model, e = effort
        var key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { key = SessionSecrets.shared.key(for: p) }
        let apiKey = key
        nativeRequestGeneration += 1
        let requestGeneration = nativeRequestGeneration
        nativeRequestInFlight = true
        status("Oktavlagen werden geprüft …", good: true)
        NativeRegisterRepairService(compiler: localCompiler).repair(source: source, transport: { instruction, done in
            guard !apiKey.isEmpty else { done(.failure(APIError.badResponse("Für die ausdrücklich angeforderte Oktavkorrektur fehlt der API-Schlüssel."))); return }
            do {
                let request = try JSONSerialization.data(withJSONObject: ["assignment": instruction, "provider": p.rawValue, "model": m, "effort": e.rawValue])
                DispatchQueue.main.async {
                guard self.nativeWorkspaceGeneration == generation else { done(.failure(APIError.badResponse("Anfrage abgebrochen."))); return }
                self.nativeRequestHandle = CoreServices.chat(requestJSON: request, apiKey: apiKey) { result in
                    DispatchQueue.main.async {
                        guard self.nativeRequestGeneration == requestGeneration else { done(.failure(APIError.badResponse("Anfrage abgebrochen."))); return }
                        if case .success(let data) = result, let diagnostic = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            self.lastDiagnostic = diagnostic
                        }
                        done(result)
                    }
                }
                }
            } catch { done(.failure(error)) }
        }) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.nativeRequestGeneration == requestGeneration else { return }
                self.nativeRequestInFlight = false
                guard self.nativeWorkspaceGeneration == generation, self.activePieceSlot == slot, self.conceptView.string == source else { return }
                switch result {
                case .success(let work):
                    var updated = metadata
                    for (key, value) in work.metadata { updated[key] = value }
                    guard self.saveScoreUndoSnapshot() else { return }
                    var cost = self.lastCostUSD, input = self.lastInputTokens, output = self.lastOutputTokens
                    if case .object(let review)? = work.metadata["octaveReview"], case .object(let response)? = review["response"] {
                        if case .number(let n)? = response["estimatedCostUSD"] { cost += n }
                        if case .number(let n)? = response["inputTokens"] { input += Int(n) }
                        if case .number(let n)? = response["outputTokens"] { output += Int(n) }
                    }
                    self.install(score: work.score, concept: original, provider: p, model: m, addHistory: false,
                        costUSD: cost, inputTokens: input, outputTokens: output, metadata: updated)
                    self.status("Oktavprüfung abgeschlossen. Original bleibt erhalten.", good: true)
                case .failure(let error): self.status(error.localizedDescription + " Letzte gültige Fassung bleibt erhalten.", good: false)
                }
            }
        }
    }

    private func selectOriginalSource(_ message: [String: Any]) {
        guard let line = message["line"] as? Int, let character = message["character"] as? Int else { return }
        let rendered: String
        if case .string(let edited)? = lastPortableMetadata["lilyPondSource"] { rendered = edited } else { rendered = lastConcept }
        let selected = LilyPondSource.selection(rendered: rendered, editor: conceptView.string,
            from: .init(line: line, character: character), to: .init(line: message["endLine"] as? Int ?? line, character: message["endCharacter"] as? Int ?? character))
        guard let start = selected.start, let length = selected.length else {
            status("Notenbild und Editor unterscheiden sich. Erst Notation aktualisieren.", good: false); return
        }
        selectWorkspace(0)
        conceptView.setSelectedRange(NSRange(location: start, length: length))
        conceptView.scrollRangeToVisible(NSRange(location: start, length: length))
        view.window?.makeFirstResponder(conceptView)
    }

    private func install(score:Score, concept:String, provider:Provider, model:String, addHistory:Bool = true,
                         costUSD: Double? = nil, inputTokens: Int? = nil, outputTokens: Int? = nil,
                         metadata: [String: JSONValue] = [:]) {
        nativeWorkspaceGeneration += 1
        lastPortableMetadata = metadata
        lastLilyPondOutput = nil
        if addHistory, let requestedSlot = pendingCompositionSlot {
            activePieceSlot = max(0, min(requestedSlot, pieceSlots.count - 1))
            pendingCompositionSlot = nil
        }
        lastScore = score; lastConcept = concept; lastProvider = provider; lastModel = model
        musicXMLCurrentLabel.stringValue = "Aktuelles Stück: " + score.ti
        scheduleMusicXMLPreviewRefresh()
        lastCostUSD = costUSD ?? 0
        lastInputTokens = inputTokens ?? 0
        lastOutputTokens = outputTokens ?? 0
        if case .string(let encoded)? = metadata["sourceMidiData"], let data = Data(base64Encoded: encoded) { lastMidi = data }
        else { lastMidi = MIDIBuilder.build(score) }
        loadOriginalPreview()
        let initialBPM = metadata["sourceMidiData"] != nil ? (lastMidi.flatMap { try? PlaybackMIDICopy.initialBPM($0) } ?? score.bpm) : score.bpm
        let displayBPM = max(20, min(400, Int(initialBPM.rounded())))
        playerTempoField.integerValue = displayBPM
        playerTempoStepper.integerValue = displayBPM
        midiPlayer.stop()
        reloadMainPlayerForPlaybackSettings(errorPrefix: "Player konnte nicht geladen werden")
        updatePlayerTime()
        var info = "\(score.ti)\n\(Int(score.bpm)) BPM · \(score.k) · \(score.tr.count) Spur(en)\n\(score.sm)"
        if let costUSD = costUSD { info += "\nAPI-Kosten ca.: \(APICost.display(costUSD))" }
        resultLabel.stringValue = info
        if let jd = try? JSONEncoder.pretty.encode(score) { jsonView.string = String(data:jd,encoding:.utf8) ?? "" }
        validationView.string = validate(score)
        if case .string(let edited)? = metadata["description"] { conceptView.string = edited }
        else { conceptView.string = concept.trimmingCharacters(in: .whitespacesAndNewlines) }
        Storage.shared.saveCurrentPlayerState(
            CurrentPlayerState(score: score,
                               concept: concept,
                               provider: provider,
                               model: model,
                               costUSD: costUSD ?? 0,
                               inputTokens: inputTokens ?? 0,
                               outputTokens: outputTokens ?? 0,
                               importedReferenceScore: importedReferenceScore,
                               importedReferenceName: importedReferenceName,
                               importedReferenceMusicXMLData: importedReferenceMusicXMLData)
        )

        if !slotSelectionLoad { captureCurrentInActiveSlot() }
        updatePieceSlotButtons()

        if addHistory {
            let scoreData = try? JSONEncoder().encode(score)
            let duplicate = history.contains { item in
                guard item.area == .composition,
                      item.provider == provider,
                      item.model == model,
                      item.concept == concept,
                      let existingData = try? JSONEncoder().encode(item.score),
                      let scoreData
                else { return false }
                return existingData == scoreData
            }

            if !duplicate {
                history.insert(HistoryItem(id:UUID(),time:Date(),title:score.ti,provider:provider,model:model,concept:concept,score:score,
                                           costUSD:costUSD,inputTokens:inputTokens,outputTokens:outputTokens,area:.composition,extraFields:metadata),at:0)
                history = trimmedHistory(history)
                Storage.shared.saveHistory(history)
                refreshVisibleHistories()
            }
        }
    }

    @objc private func playCurrentMIDI() {
        guard lastMidi != nil else { status("Noch keine MIDI-Komposition vorhanden.", good:false); return }
        if midiPlayer.isPlaying { pauseCurrentMIDI(); return }
        midiPlayer.play(); startPlayerTimer(); status("Wiedergabe läuft.", good:true)
    }
    @objc private func playerLoopChanged() {
        let active = (playerLoopButton.state == .on)
        midiPlayer.loopEnabled = active
        playerLoopButton.title = active ? "↻ Loop AN" : "↻ Loop"
        playerLoopButton.contentTintColor = active ? .systemGreen : nil
        notationPlayerLoopButton.state = playerLoopButton.state
        notationPlayerLoopButton.title = playerLoopButton.title
        notationPlayerLoopButton.contentTintColor = playerLoopButton.contentTintColor
    }
    @objc private func pauseCurrentMIDI() { midiPlayer.pause(); updatePlayerTime(); status("Wiedergabe pausiert.", good:true) }
    @objc private func stopCurrentMIDI() { midiPlayer.stop(); updatePlayerTime(); playerTimer?.invalidate(); status("Wiedergabe gestoppt.", good:true) }
    private func startPlayerTimer() {
        playerTimer?.invalidate()
        playerTimer = Timer.scheduledTimer(timeInterval: 0.25,
                                           target: self,
                                           selector: #selector(playerTimerTick(_:)),
                                           userInfo: nil,
                                           repeats: true)
    }
    @objc private func playerTimerTick(_ timer: Timer) {
        updatePlayerTime()
        if midiPlayer.isPlaying == false {
            timer.invalidate()
            playerTimer = nil
        }
    }
    private func updatePlayerTime() {
        func t(_ x:TimeInterval)->String { let n=max(0,Int(x.rounded())); return String(format:"%d:%02d",n/60,n%60) }
        let pos = midiPlayer.position, dur = midiPlayer.duration
        playerTimeLabel.stringValue="\(t(pos)) / \(t(dur))"
        notationPlayerTimeLabel.stringValue = playerTimeLabel.stringValue
        if dur > 0 {
            let f = max(0, min(1, pos / dur))
            playerProgress.doubleValue = f
            notationPlayerProgress.doubleValue = f
        } else {
            playerProgress.doubleValue = 0
            notationPlayerProgress.doubleValue = 0
        }
    }

    @objc private func playerSeekChanged() {
        midiPlayer.seek(fraction: playerProgress.doubleValue)
        updatePlayerTime()
    }

    private func reloadMainPlayerForPlaybackSettings(errorPrefix: String) {
        guard let score = lastScore else { return }
        let wasPlaying = midiPlayer.isPlaying
        let fraction = midiPlayer.duration > 0 ? midiPlayer.position / midiPlayer.duration : 0
        let bpm = max(20, min(400, playerTempoField.integerValue > 0 ? playerTempoField.integerValue : Int(score.bpm.rounded())))
        playerTempoField.integerValue = bpm; playerTempoStepper.integerValue = bpm
        do {
            let original = lastPortableMetadata["sourceMidiData"] != nil ? (lastMidi ?? Data()) : MIDIBuilder.build(score, endPaddingSeconds: 3)
            let data = try PlaybackMIDICopy.make(original, velocityFactor: playerVolume.doubleValue, targetBPM: Double(bpm))
            try midiPlayer.load(score: score, data: data, preserveOriginal: true)
            midiPlayer.seek(fraction: fraction)
            if wasPlaying { midiPlayer.play(); startPlayerTimer() }
            updatePlayerTime()
        } catch { status(errorPrefix + ": " + error.localizedDescription, good: false) }
    }

    @objc private func playerTempoStepperChanged() {
        playerTempoField.integerValue = playerTempoStepper.integerValue
        playerTempoChanged()
    }

    @objc private func playerTempoChanged() {
        notationPlayerTempoField.stringValue = playerTempoField.stringValue
        reloadMainPlayerForPlaybackSettings(errorPrefix: "Player-Tempo konnte nicht geändert werden")
    }

    @objc private func playerVolumeChanged() {
        notationPlayerVolume.doubleValue = playerVolume.doubleValue
        reloadMainPlayerForPlaybackSettings(errorPrefix: "Player-Lautstärke konnte nicht geändert werden")
    }

    @objc private func midiOutputModeChanged() {
        midiPlayer.outputModeChanged()
        updatePlayerTime()
        let mgr = MIDIOutputManager.shared
        if mgr.mode == .midiDestination {
            status("MIDI-Ausgabe: \(mgr.selectedDestinationName ?? "kein Ziel verfügbar")", good: mgr.selectedDestination() != nil)
        } else {
            status("MIDI-Ausgabe: eingebauter Sound", good: true)
        }
    }

    @objc func menuMIDIOutput() {
        let wc = MIDIOutputSettingsWindowController()
        midiOutputWindowController = wc
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
    }

    private func validate(_ score:Score) -> String {
        var errors:[String] = [], warnings:[String] = []
        var notes = 0, controls = 0, maxBeat = 0.0
        if score.bpm < 20 || score.bpm > 400 { errors.append("Tempo ungültig: \(score.bpm)") }
        if score.ts.n < 1 || score.ts.n > 32 { errors.append("Taktzähler ungültig: \(score.ts.n)") }
        if ![1,2,4,8,16,32,64].contains(score.ts.d) { errors.append("Taktnenner ungültig: \(score.ts.d)") }
        let beatsPerBar = Double(score.ts.n) * 4.0 / Double(max(1,score.ts.d))
        let wantedBars = Double(measuresField.stringValue) ?? 0
        let expected = wantedBars * beatsPerBar
        for (ti,t) in score.tr.enumerated() {
            if !(0...15).contains(t.ch) { errors.append("Spur \(ti+1): Kanal \(t.ch) ungültig") }
            if !(0...127).contains(t.pg) { errors.append("Spur \(ti+1): Programm \(t.pg) ungültig") }
            notes += t.nt.count; controls += t.ct?.count ?? 0
            var lastByPitch:[Int:Double] = [:]
            for (ni,n) in t.nt.enumerated() {
                if n.count < 4 { errors.append("Spur \(ti+1), Note \(ni+1): ungültiges Notenformat"); continue }
                let start = n[0], dur = n[1], pitch = Int(n[2]), vel = Int(n[3]), gate = n.count>5 ? n[5] : 0.95
                if start < 0 || dur <= 0 { errors.append("Spur \(ti+1), Note \(ni+1): Start/Dauer ungültig") }
                if !(0...127).contains(pitch) { errors.append("Spur \(ti+1), Note \(ni+1): Pitch \(pitch) ungültig") }
                if !(1...127).contains(vel) { errors.append("Spur \(ti+1), Note \(ni+1): Velocity \(vel) ungültig") }
                if gate <= 0 || gate > 4 { errors.append("Spur \(ti+1), Note \(ni+1): Gate \(gate) ungültig") }
                let end = start + dur
                let soundingEnd = start + dur*gate
                maxBeat = max(maxBeat,end,soundingEnd)
                if expected > 0 && end > expected + 0.000001 {
                    warnings.append("Spur \(ti+1), Note \(ni+1): endet hinter gewünschter Länge.")
                }
                if let prev = lastByPitch[pitch], start < prev - 0.000001 {
                    warnings.append("Spur \(ti+1), Note \(ni+1): überlappt denselben Pitch \(pitch).")
                }
                lastByPitch[pitch] = max(lastByPitch[pitch] ?? -Double.infinity, soundingEnd)
            }
        }
        if expected > 0 {
            let diff = maxBeat-expected
            if diff < -beatsPerBar*0.75 { warnings.append("Stück ist deutlich kürzer als angefordert.") }
            if diff > beatsPerBar*0.25 { warnings.append("Stück ist länger als angefordert.") }
        }
        var out = ["Geprüfte Noten: \(notes)","Controller-Ereignisse: \(controls)","Spuren: \(score.tr.count)",
                   String(format:"Ermittelte Länge: ca. %.2f Takte", beatsPerBar > 0 ? maxBeat/beatsPerBar : 0)]
        if !errors.isEmpty { out += ["","FEHLER:"] + errors.map{"- "+$0} }
        if !warnings.isEmpty { out += ["","WARNUNGEN:"] + warnings.map{"- "+$0} }
        if errors.isEmpty && warnings.isEmpty { out += ["","Keine technischen Auffälligkeiten gefunden."] }
        else if errors.isEmpty { out += ["","Keine harten MIDI-Fehler gefunden; siehe Warnungen oben."] }
        return out.joined(separator:"\n")
    }

    private func musicChatWorkspaceContext() -> String {
        var slotObjects: [[String: Any]] = []
        for (index, item) in pieceSlots.enumerated() {
            guard let item else { continue }
            slotObjects.append(["slot":index+1,"title":item.title,"concept":item.concept,
                                "provider":item.provider.rawValue,"model":item.model])
        }
        let fullConversation = chatView.string
        let limit = 12000
        let recentConversation = fullConversation.count > limit
            ? "[Älterer Dialog lokal gespeichert; für diesen Aufruf gekürzt.]\\n" + String(fullConversation.suffix(limit))
            : fullConversation
        let object: [String: Any] = [
            "settings":["measures":measuresField.stringValue,"meter":meterField.stringValue,
                        "tempo":tempoField.stringValue,"key":musicalKeyField.stringValue,"ensemble":ensembleField.stringValue],
            "activeSlot":activePieceSlot+1,
            "slotIndex":slotObjects,
            "recentConversation":recentConversation,
            "currentAssignment":promptView.string,
            "currentCompositionIdea":conceptView.string
        ]
        guard JSONSerialization.isValidJSONObject(object),
              let data=try? JSONSerialization.data(withJSONObject:object,options:[.sortedKeys]),
              let text=String(data:data,encoding:.utf8) else { return "{}" }
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

    @objc private func chatPressed() {
        guard !nativeRequestInFlight else { status("Bitte die laufende Anfrage abwarten.", good: false); return }
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
        let dialoguePrompt = WorkspaceDialogue.prompt(message: msg, workspace: workspace)

        lastDiagnostic = [
            "format": "composition-lab-native-diagnostic",
            "engineBuild": ComposerPrompts.engineBuild,
            "interface": "macOS AppKit",
            "interfaceVersion": CoreServices.version,
            "entryPoint": "musicchat",
            "stage": "dialogue-request",
            "userMessage": msg,
            "workspaceContext": workspace,
            "dialoguePrompt": dialoguePrompt
        ]
        nativeRequestGeneration += 1
        let generation = nativeRequestGeneration
        nativeRequestInFlight = true
        let client = APIClient(); nativeDialogueClient = client
        status("KI denkt im MusicChat mit …", good: true)

        client.call(provider: p, model: m, key: key, effort: e,
                              purpose: "MainViewController.chatPressed", system: ComposerPrompts.system,
                              user: dialoguePrompt,
                              wantJSON: true) { [weak self] result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    guard self?.nativeRequestGeneration == generation else { return }
                    self?.nativeRequestInFlight = false
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
                    let data = try WorkspaceDialogue.decode(response.text)
                    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                    let reply = (object["reply"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let assignment = (object["compositionAssignment"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let idea = (object["compositionIdea"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let sourceSlots = (object["sourceSlots"] as? [Any] ?? []).compactMap { value -> Int? in
                        if let n = value as? Int { return n }
                        if let n = value as? NSNumber { return n.intValue }
                        return nil
                    }.filter { $0 >= 1 && $0 <= 10 }
                    let resolvedSettings = object["resolvedSettings"] as? [String: Any] ?? [:]
                    func resolvedString(_ key: String) -> String? {
                        let value = resolvedSettings[key]
                        if value == nil || value is NSNull { return nil }
                        if let x = value as? String {
                            let t = x.trimmingCharacters(in: .whitespacesAndNewlines)
                            return t.isEmpty ? nil : t
                        }
                        if let x = value as? NSNumber { return x.stringValue }
                        return nil
                    }
                    let resolvedMeasures = resolvedString("measures")
                    let resolvedMeter = resolvedString("meter")
                    let resolvedTempo = resolvedString("tempo")
                    let resolvedKey = resolvedString("key")
                    let resolvedEnsemble = resolvedString("ensemble")

                    DispatchQueue.main.async {
                        guard let self else { return }
                        guard self.nativeRequestGeneration == generation else { return }
                        self.nativeRequestInFlight = false
                        let answer = (reply?.isEmpty == false) ? reply! : "Ich habe den musikalischen Zusammenhang aufgenommen."
                        self.appendChat(p.displayName, answer)

                        // The newest explicit natural-language instruction wins and is
                        // made visible immediately in the top controls. This keeps the UI,
                        // assignment and idea in one coherent state.
                        if let x = resolvedMeasures { self.measuresField.stringValue = x }
                        if let x = resolvedMeter { self.meterField.stringValue = x }
                        if let x = resolvedTempo { self.tempoField.stringValue = x }
                        if let x = resolvedKey { self.musicalKeyField.stringValue = x }
                        if let x = resolvedEnsemble { self.ensembleField.stringValue = x }

                        if let assignment, !assignment.isEmpty {
                            self.promptView.string = assignment
                        }
                        if let idea, !idea.isEmpty {
                            self.conceptView.string = idea
                            // Planning is a draft; retain the accepted score original.
                        }
                        if assignment?.isEmpty == false || idea?.isEmpty == false {
                            self.musicChatCompositionContextOverride = self.musicChatSourceMaterial(sourceSlots)
                            if sourceSlots.isEmpty, assignment?.isEmpty == false {
                                self.importedReferenceScore = nil
                                self.importedReferenceName = nil
                            }
                            self.saveSettingsFromUI()
                        }

                        if var d = self.lastDiagnostic {
                            d["stage"] = "dialogue-completed"
                            d["dialogueResponse"] = response.text
                            d["reply"] = answer
                            d["sourceSlots"] = sourceSlots
                            d["resolvedSettings"] = resolvedSettings
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
                        guard self?.nativeRequestGeneration == generation else { return }
                    self?.nativeRequestInFlight = false
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

    private func appendChat(_ who:String,_ text:String) {
        if !chatView.string.isEmpty { chatView.string += "\n\n" }
        chatView.string += "\(who):\n\(text)"
        chatView.scrollToEndOfDocument(nil)
    }

    @objc private func clearChat() { chatView.string = "" }

    @objc private func importMIDIPressed() {
        let p = NSOpenPanel()
        p.allowedFileTypes = ["mid", "midi", "musicxml", "xml", "clab", "clabproject"]
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        p.message = "MIDI, MusicXML oder Composition-Lab-Datei auswählen"
        guard p.runModal() == .OK, let url = p.url else { return }
        loadCompositionReference(url: url)
    }

    private func loadCompositionReference(url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "clab":
            loadCLABDocument(url: url)
        case "clabproject":
            loadLegacyProject(url: url)
        case "musicxml", "xml":
            loadMusicXMLAsCompositionReference(url: url)
        default:
            loadMIDIAsCompositionReference(url: url)
        }
    }

    private func loadMIDIAsCompositionReference(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            var score = try MIDIParser.parse(data: data, fallbackTitle: url.deletingPathExtension().lastPathComponent)

            // Bei einer geladenen Datei ist der Dateiname die verlässlichste sichtbare
            // Bezeichnung. MIDI-Dateien enthalten oft gar keinen Titel oder nur generische
            // Track-/Sequence-Namen. Deshalb wird der Dateiname ohne Endung als Titel gesetzt.
            let fileTitle = url.deletingPathExtension().lastPathComponent
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !fileTitle.isEmpty {
                score.ti = fileTitle
            }

            importedReferenceScore = score
            importedReferenceName = url.lastPathComponent
            importedReferenceMusicXMLData = nil

            // Eine extern geladene MIDI-Datei hat keinen zugehörigen musikalischen Impuls.
            // Ein alter Impuls darf deshalb nicht mit der neuen Vorlage vermischt werden.
            lastConcept = ""
            conceptView.string = ""
            install(score: score, concept: "", provider: provider, model: model, addHistory: false, metadata: ["sourceMidiData": .string(data.base64EncodedString())])
            conceptView.string = ""
            selectWorkspace(0)
            workspaceSegment.selectedSegment = 0
            status("MIDI-Vorlage geladen – jetzt Auftrag formulieren oder im KI-Chat weiterarbeiten.", good: true)
        } catch {
            status("MIDI-Import fehlgeschlagen: \(error.localizedDescription)", good: false)
        }
    }

    private func loadMusicXMLAsCompositionReference(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            var score = try MusicXMLParser.parse(data: data, fallbackTitle: url.deletingPathExtension().lastPathComponent)

            let fileTitle = url.deletingPathExtension().lastPathComponent
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !fileTitle.isEmpty { score.ti = fileTitle }
            importedReferenceScore = score
            importedReferenceName = url.lastPathComponent
            importedReferenceMusicXMLData = data
            lastConcept = ""
            conceptView.string = ""
            install(score: score, concept: "", provider: provider, model: model, addHistory: false)
            conceptView.string = ""
            selectWorkspace(0)
            workspaceSegment.selectedSegment = 0
            status("MusicXML-Vorlage geladen – jetzt Auftrag formulieren oder im KI-Chat weiterarbeiten.", good: true)
        } catch {
            status("MusicXML-Import fehlgeschlagen: \(error.localizedDescription)", good: false)
        }
    }

    @objc private func clearImportedMIDIPressed() {
        guard importedReferenceScore != nil else {
            status("Keine Vorlage geladen.", good: false)
            return
        }
        importedReferenceScore = nil
        importedReferenceName = nil
        importedReferenceMusicXMLData = nil

        // Den automatisch erzeugten Hinweis zur importierten Vorlage auch aus
        // dem Konzept entfernen. Ein später hinzugefügtes eigenständiges
        // KI-Konzept bleibt erhalten.
        let marker = "Importierte MIDI-Vorlage:"
        if lastConcept.hasPrefix(marker) {
            let paragraphs = lastConcept.components(separatedBy: "\n\n")
            if paragraphs.count >= 2, paragraphs[1].hasPrefix("Diese vorhandene Musik ist jetzt Ausgangspunkt") {
                lastConcept = paragraphs.dropFirst(2).joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                lastConcept = ""
            }
            if lastConcept.isEmpty {
                conceptView.string = ""
            } else if let provider = lastProvider, let model = lastModel {
                conceptView.string = conceptDisplay(lastConcept, provider: provider, model: model)
            } else {
                conceptView.string = lastConcept
            }
        }
        status("Vorlage gelöscht. Die aktuelle Komposition bleibt erhalten.", good: true)
    }

    private func temporaryExportURL(extension ext: String) -> URL? {
        guard let score = lastScore else { status("Noch keine Komposition vorhanden.", good:false); return nil }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("CompositionLab-DragExport", isDirectory: true)
        do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        catch { status("Temporärer Export fehlgeschlagen: \(error.localizedDescription)", good:false); return nil }
        return dir.appendingPathComponent(safeFilename(score.ti) + "." + ext)
    }

    private func temporaryMIDIExportURL() -> URL? {
        guard let data = lastMidi else { status("Noch keine MIDI-Komposition vorhanden.", good:false); return nil }
        guard let url = temporaryExportURL(extension: "mid") else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            status("MIDI zum Ziehen bereit.", good:true)
            return url
        } catch {
            status("MIDI-Drag-Export fehlgeschlagen: \(error.localizedDescription)", good:false)
            return nil
        }
    }

    private func temporaryMusicXMLExportURL() -> URL? {
        guard let score = lastScore, let data = MusicXMLBuilder.build(score, options: currentMusicXMLDisplayOptions()) else {
            status("Noch keine exportierbare Partitur vorhanden.", good:false); return nil
        }
        guard let url = temporaryExportURL(extension: "musicxml") else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            status("MusicXML zum Ziehen bereit.", good:true)
            return url
        } catch {
            status("MusicXML-Drag-Export fehlgeschlagen: \(error.localizedDescription)", good:false)
            return nil
        }
    }

    private func currentCLABDocument() -> CompositionLabDocument? {
        guard let score = lastScore else { return nil }
        saveSettingsFromUI()
        var document = CompositionLabDocument(
            title: score.ti,
            score: score,
            concept: lastConcept,
            provider: lastProvider,
            model: lastModel,
            measures: measuresField.stringValue,
            meter: meterField.stringValue,
            tempo: tempoField.stringValue,
            musicalKey: musicalKeyField.stringValue,
            ensemble: ensembleField.stringValue,
            assignment: promptView.string,
            sourceName: importedReferenceName,
            sourceScore: importedReferenceScore,
            // Austauschformate werden nicht als maßgebliche Snapshots fixiert.
            // Beim Export werden MIDI und MusicXML stets frisch aus score erzeugt.
            midiData: nil,
            musicXMLData: nil,
            // Nur eine tatsächlich importierte fremde MusicXML-Datei wird als Original bewahrt.
            originalMusicXMLData: importedReferenceMusicXMLData,
            costUSD: lastCostUSD == 0 ? nil : lastCostUSD,
            inputTokens: lastInputTokens == 0 ? nil : lastInputTokens,
            outputTokens: lastOutputTokens == 0 ? nil : lastOutputTokens
        )
        document.extraFields = lastPortableMetadata
        document.extraFields["description"] = .string(conceptView.string)
        return document
    }

    @objc private func saveCLABPressed() {
        saveCLABDocument()
    }

    private func saveCLABDocument() {
        guard let doc = currentCLABDocument() else {
            status("Noch keine Komposition vorhanden.", good:false)
            return
        }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["clab"]
        panel.nameFieldStringValue = safeFilename(doc.title) + ".clab"
        if let url = projectURL { panel.directoryURL = url.deletingLastPathComponent() }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONEncoder.pretty.encode(doc)
            try data.write(to: url, options: .atomic)
            projectName = doc.title
            projectURL = url
            updateWindowTitle()
            status("Composition-Lab-Datei gespeichert. Kompositionsidee und Einstellungen sind enthalten.", good:true)
        } catch {
            status("CLAB-Datei konnte nicht gespeichert werden: \(error.localizedDescription)", good:false)
        }
    }

    @objc private func openCLABPressed() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["clab", "clabproject"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadCompositionReference(url: url)
    }

    private func loadCLABDocument(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(CompositionLabDocument.self, from: data)
            guard doc.format == "composition-lab-document" else {
                throw NSError(domain:"CompositionLab", code:1,
                              userInfo:[NSLocalizedDescriptionKey:"Unbekanntes Composition-Lab-Dateiformat."])
            }

            importedReferenceName = doc.sourceName
            importedReferenceScore = doc.sourceScore
            importedReferenceMusicXMLData = doc.originalMusicXMLData
            measuresField.stringValue = doc.measures
            meterField.stringValue = doc.meter
            tempoField.stringValue = doc.tempo
            musicalKeyField.stringValue = doc.musicalKey
            ensembleField.stringValue = doc.ensemble
            promptView.string = doc.assignment

            let p = doc.provider ?? settings.provider
            let m = doc.model ?? settings.models[p.rawValue] ?? p.models.first?.0 ?? ""
            if let pi = Provider.allCases.firstIndex(of: p) {
                providerPop.selectItem(at: pi)
                refillModels()
            }
            settings.models[p.rawValue] = m
            refillModels()
            keyField.stringValue = SessionSecrets.shared.key(for: p)

            install(score: doc.score,
                    concept: doc.concept,
                    provider: p,
                    model: m,
                    addHistory: false,
                    costUSD: doc.costUSD,
                    inputTokens: doc.inputTokens,
                    outputTokens: doc.outputTokens, metadata: doc.extraFields)

            lastConcept = doc.concept
            lastProvider = doc.provider
            lastModel = doc.model
            projectName = doc.title
            projectURL = url
            saveSettingsFromUI()
            updateWindowTitle()
            selectWorkspace(0)
            workspaceSegment.selectedSegment = 0
            status("CLAB-Datei „\(doc.title)“ vollständig geladen.", good:true)
        } catch {
            status("CLAB-Datei konnte nicht geladen werden: \(error.localizedDescription)", good:false)
        }
    }

    private func loadLegacyProject(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], root["format"] as? String == "composition-lab-v6-project" { loadWorkspaceProject(url: url); return }
            let doc = try JSONDecoder().decode(CompositionLabProject.self, from: data)
            workspaceExtraFields = [:]
            projectName = doc.name
            projectURL = url
            settings = doc.settings
            history = doc.history
            lastConcept = doc.concept
            lastScore = doc.score
            importedReferenceScore = doc.source
            importedReferenceName = doc.sourceName
            importedReferenceMusicXMLData = nil
            lastExperimentConcept = doc.experimentConcept
            lastExperimentScore = doc.experimentScore
            Storage.shared.saveSettings(settings)
            Storage.shared.saveHistory(history)
            restoreSettings()
            refreshVisibleHistories()
            if let score = lastScore {
                install(score: score,
                        concept: lastConcept,
                        provider: settings.provider,
                        model: settings.models[settings.provider.rawValue] ?? settings.provider.models.first?.0 ?? "",
                        addHistory: false)
            }
            updateWindowTitle()
            status("Altes Projekt „\(projectName)“ geladen. Es kann jetzt als .clab gespeichert werden.", good:true)
        } catch {
            status("Projekt konnte nicht geladen werden: \(error.localizedDescription)", good:false)
        }
    }

    @objc private func saveMIDIPressed() {
        guard let data = lastMidi else { status("Noch keine MIDI-Komposition vorhanden.",good:false); return }
        let p = NSSavePanel(); p.allowedFileTypes = ["mid", "midi"]; p.nameFieldStringValue = safeFilename(lastScore?.ti ?? "Komposition")+".mid"
        if p.runModal() == .OK, let url = p.url {
            do { try data.write(to:url); status("MIDI gespeichert.",good:true) }
            catch { status("Speichern fehlgeschlagen: \(error.localizedDescription)",good:false) }
        }
    }

    @objc private func saveMusicXMLPressed() {
        // Wichtig: niemals eine in CLAB eingebettete ältere MusicXML-Darstellung verwenden.
        // Die aktuelle MusicXML-Datei wird bei jedem Export frisch aus dem internen Score gebaut.
        guard let score = lastScore, let data = MusicXMLBuilder.build(score, options: currentMusicXMLDisplayOptions()) else {
            status("Noch keine exportierbare Partitur vorhanden.", good:false)
            return
        }
        let p = NSSavePanel()
        p.allowedFileTypes = ["musicxml", "xml"]
        p.nameFieldStringValue = safeFilename(score.ti) + ".musicxml"
        if p.runModal() == .OK, let url = p.url {
            do {
                try data.write(to: url, options: .atomic)
                status("MusicXML gespeichert.", good:true)
            } catch {
                status("MusicXML-Speichern fehlgeschlagen: \(error.localizedDescription)", good:false)
            }
        }
    }

    @objc private func saveJSONPressed() {
        guard let score = lastScore, let data = try? JSONEncoder.pretty.encode(score) else { return }
        let p = NSSavePanel(); p.allowedFileTypes = ["json"]; p.nameFieldStringValue = safeFilename(score.ti)+".json"
        if p.runModal() == .OK, let url = p.url {
            do { try data.write(to:url); status("JSON gespeichert.",good:true) }
            catch { status("Speichern fehlgeschlagen: \(error.localizedDescription)",good:false) }
        }
    }

    @objc private func saveDiagnosticPressed() {
        guard var diagnostic = lastDiagnostic else {
            status("Noch keine Diagnosedaten vorhanden.", good: false)
            NSSound.beep()
            return
        }

        do {
            diagnostic["aiCommunication"] = AICommunicationLog.shared.snapshot()
            diagnostic["aiCommunicationLogging"] = "complete-central-APIClient-log; API keys and authorization secrets excluded"
            diagnostic["interfaceVersion"] = "3.3.1"

            guard JSONSerialization.isValidJSONObject(diagnostic) else {
                throw NSError(domain: "CompositionLab.Diagnostic", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Die Diagnosedaten enthalten einen nicht speicherbaren Wert."])
            }
            let data = try JSONSerialization.data(withJSONObject: diagnostic,
                                                  options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])

            let fm = FileManager.default
            let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
            try fm.createDirectory(at: downloads, withIntermediateDirectories: true)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let stamp = formatter.string(from: Date())
            let base = lastScore?.ti.trimmingCharacters(in: .whitespacesAndNewlines)
            let stem = safeFilename((base?.isEmpty == false ? base! : "Composition-Lab") + "-Diagnose-" + stamp)
            let url = downloads.appendingPathComponent(stem).appendingPathExtension("json")

            try data.write(to: url, options: .atomic)
            status("Diagnose gespeichert in Downloads: \(url.lastPathComponent)", good: true)
        } catch {
            status("Diagnose konnte nicht gespeichert werden: \(error.localizedDescription)", good: false)
            NSSound.beep()
        }
    }

    private func safeFilename(_ s:String)->String {
        let bad = CharacterSet(charactersIn:"/\\:?%*|\"<>")
        return s.components(separatedBy:bad).joined(separator:"_")
    }

    private func historyItems(for area: HistoryArea) -> [HistoryItem] {
        history.filter { $0.effectiveArea == area }
    }

    /// Maximal 15 Einträge je Arbeitsbereich, ohne die anderen Bereiche zu verdrängen.
    private func trimmedHistory(_ items: [HistoryItem]) -> [HistoryItem] {
        var counts: [HistoryArea:Int] = [.composition:0, .experiment:0, .comparison:0]
        var result: [HistoryItem] = []
        for item in items.sorted(by: { $0.time > $1.time }) {
            let area = item.effectiveArea
            if (counts[area] ?? 0) < 15 {
                result.append(item)
                counts[area, default: 0] += 1
            }
        }
        return result
    }

    func numberOfRows(in tableView:NSTableView)->Int { historyItems(for: .composition).count }
    func tableView(_ tableView:NSTableView, viewFor tableColumn:NSTableColumn?, row:Int)->NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let field = (tableView.makeView(withIdentifier:id,owner:self) as? NSTextField) ?? {
            let x = NSTextField(labelWithString:""); x.identifier = id; x.lineBreakMode = .byTruncatingTail; return x
        }()
        let composerHistory = historyItems(for: .composition)
        guard row >= 0 && row < composerHistory.count else { return nil }
        let h = composerHistory[row]
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
        let costText = h.costUSD.map { " — \(APICost.display($0))" } ?? ""
        field.stringValue = "\(h.title) — \(h.provider.displayName) — \(f.string(from:h.time))\(costText)"
        return field
    }

    private func refreshVisibleHistories() {
        history = Storage.shared.loadHistory()
        historyTable.reloadData()

        let composerHistory = historyItems(for: .composition)
        let experimentHistory = historyItems(for: .experiment)
        let comparisonHistory = historyItems(for: .comparison)

        compositionHistoryFooter.setItems(composerHistory)
        experimentWindow?.setHistory(experimentHistory)

        // Quelle A/B kann weiterhin aus allen gespeicherten Ständen gewählt werden;
        // der Verlauf des Vergleichslabors bleibt trotzdem ein eigener Verlauf.
        compareWindow?.update(items: history, historyItems: comparisonHistory)
    }

    private func addHistoryItem(_ item: HistoryItem) {
        history = Storage.shared.loadHistory()
        history.removeAll { $0.id == item.id }
        history.insert(item, at: 0)
        history = trimmedHistory(history)
        Storage.shared.saveHistory(history)
        refreshVisibleHistories()
    }

    private func loadHistoryItemToComposition(_ h: HistoryItem) {
        importedReferenceScore = nil
        importedReferenceName = nil

        // Verlaufseinträge werden beim Laden vollständig zur aktuellen Komposition:
        // Player, sichtbare Kompositionsdaten und die editierbaren Eckdaten links
        // beziehen sich danach auf genau diesen gespeicherten Stand.
        let score = h.score

        // Editorfelder aus der gespeicherten Partitur rekonstruieren.
        let beatsPerBar = Double(max(1, score.ts.n)) * 4.0 / Double(max(1, score.ts.d))
        var maxBeat = 0.0
        for track in score.tr {
            for note in track.nt where note.count >= 2 {
                maxBeat = max(maxBeat, note[0] + max(0, note[1]))
            }
            for cc in track.ct ?? [] where !cc.isEmpty {
                maxBeat = max(maxBeat, cc[0])
            }
            for raw in track.me ?? [] {
                maxBeat = max(maxBeat, raw.b)
            }
        }
        if beatsPerBar > 0, maxBeat > 0 {
            measuresField.stringValue = String(max(1, Int(ceil((maxBeat - 0.000001) / beatsPerBar))))
        } else {
            measuresField.stringValue = ""
        }
        meterField.stringValue = "\(score.ts.n)/\(score.ts.d)"
        tempoField.stringValue = String(Int(score.bpm.rounded()))
        musicalKeyField.stringValue = score.k
        ensembleField.stringValue = score.tr.map(\.nm).joined(separator: ", ")

        // Der gespeicherte Titel bleibt unverändert erhalten und wird durch install()
        // in "Aktuelle Komposition", Player, JSON/MusicXML/MIDI-Export übernommen.
        install(score:score, concept:h.concept, provider:h.provider, model:h.model, addHistory:false,
                costUSD:h.costUSD, inputTokens:h.inputTokens, outputTokens:h.outputTokens, metadata:h.extraFields)

        if let pi = Provider.allCases.firstIndex(of:h.provider) { providerPop.selectItem(at:pi); refillModels() }
        settings.models[h.provider.rawValue] = h.model; refillModels()
        keyField.stringValue = SessionSecrets.shared.key(for:h.provider)

        // Die rekonstruierten Editorwerte gelten als aktueller Arbeitsstand und
        // bleiben deshalb auch nach einem Neustart erhalten.
        saveSettingsFromUI()
        status("\(h.title) aus dem Verlauf in Player und Editor geladen.", good:true)
    }

    private func loadHistoryItemToExperiment(_ h: HistoryItem, window: ExperimentLabWindowController?) {
        lastExperimentConcept = h.concept
        lastExperimentScore = h.score
        window?.setScore(h.score)
        window?.appendChat("Verlauf", "\(h.title) geladen.")
        window?.setStatus("Verlaufseintrag als Vorlage geladen.", good: true)
    }

    @objc private func loadHistorySelection() {
        let composerHistory = historyItems(for: .composition)
        let r = historyTable.selectedRow
        guard r>=0 && r<composerHistory.count else { return }
        loadHistoryItemToComposition(composerHistory[r])
    }

    private func deleteHistoryItem(_ item: HistoryItem) {
        history = Storage.shared.loadHistory()
        history.removeAll { $0.id == item.id }
        Storage.shared.saveHistory(history)
        refreshVisibleHistories()
        status("Verlaufseintrag \"\(item.title)\" gelöscht.", good: true)
    }

    @objc private func deleteHistorySelection() {
        let composerHistory = historyItems(for: .composition)
        let r = historyTable.clickedRow >= 0 ? historyTable.clickedRow : historyTable.selectedRow
        guard r >= 0 && r < composerHistory.count else { return }
        deleteHistoryItem(composerHistory[r])
    }

    @objc private func clearHistory() {
        let a = NSAlert()
        a.messageText = "Composer-Verlauf löschen?"
        a.informativeText = "Nur die Einträge des Composers werden gelöscht. Experimentallabor und Vergleichslabor bleiben erhalten."
        a.addButton(withTitle:"Löschen"); a.addButton(withTitle:"Abbrechen")
        if a.runModal() == .alertFirstButtonReturn {
            history = Storage.shared.loadHistory()
            history.removeAll { $0.effectiveArea == .composition }
            Storage.shared.saveHistory(history)
            refreshVisibleHistories()
        }
    }

    private func status(_ text:String,good:Bool) {
        statusLabel.stringValue = text
        statusLabel.textColor = good ? .systemGreen : .systemRed
    }


    @objc func menuZoom80() { setZoom(percent: 80) }
    @objc func menuZoom90() { setZoom(percent: 90) }
    @objc func menuZoom100() { setZoom(percent: 100) }
    @objc func menuZoom110() { setZoom(percent: 110) }
    @objc func menuZoom120() { setZoom(percent: 120) }
    @objc func menuZoom130() { setZoom(percent: 130) }
    @objc func menuZoom140() { setZoom(percent: 140) }
    @objc func menuZoom150() { setZoom(percent: 150) }

    private func setZoom(percent: CGFloat, resizeWindow: Bool = true, persist: Bool = true) {
        let newFactor = percent / 100.0
        guard newFactor > 0 else { return }
        let ratio = newFactor / zoomFactor

        // Hauptfenster und alle bereits geöffneten Zusatzfenster gemeinsam skalieren.
        scaleFonts(in: view, ratio: ratio)
        if resizeWindow, let window = view.window { resize(window: window, ratio: ratio) }
        if let w = apiWindow { scaleWindow(w, ratio: ratio, resizeWindow: resizeWindow) }
        if let w = draftsWindow { scaleWindow(w, ratio: ratio, resizeWindow: resizeWindow) }
        if let w = experimentWindow?.window { scaleWindow(w, ratio: ratio, resizeWindow: resizeWindow) }
        if let w = compareWindow?.window { scaleWindow(w, ratio: ratio, resizeWindow: resizeWindow) }
        for w in helpWindows { scaleWindow(w, ratio: ratio, resizeWindow: resizeWindow) }

        zoomFactor = newFactor
        if persist {
            settings.zoomPercent = Int(percent)
            Storage.shared.saveSettings(settings)
        }
        status("Darstellung: \(Int(percent)) %", good: true)
    }

    private func resize(window: NSWindow, ratio: CGFloat) {
        guard ratio > 0, abs(ratio - 1) > 0.0001 else { return }
        let oldFrame = window.frame
        let newSize = NSSize(width: max(window.minSize.width, oldFrame.width * ratio),
                             height: max(window.minSize.height, oldFrame.height * ratio))
        window.setFrame(NSRect(origin: oldFrame.origin, size: newSize), display: true, animate: true)
    }

    private func scaleWindow(_ window: NSWindow, ratio: CGFloat, resizeWindow: Bool = true) {
        if let content = window.contentView { scaleFonts(in: content, ratio: ratio) }
        if resizeWindow { resize(window: window, ratio: ratio) }
    }

    private func applyCurrentZoom(to window: NSWindow, resizeWindow: Bool = true) {
        guard abs(zoomFactor - 1) > 0.0001 else { return }
        scaleWindow(window, ratio: zoomFactor, resizeWindow: resizeWindow)
    }

    private func scaleFonts(in root: NSView, ratio: CGFloat) {
        if let control = root as? NSControl, let font = control.font {
            control.font = NSFont(descriptor: font.fontDescriptor, size: max(9, font.pointSize * ratio)) ?? font
        }
        if let textView = root as? NSTextView, let font = textView.font {
            textView.font = NSFont(descriptor: font.fontDescriptor, size: max(9, font.pointSize * ratio)) ?? font
        }
        if let box = root as? NSBox {
            let font = box.titleFont
            box.titleFont = NSFont(descriptor: font.fontDescriptor, size: max(9, font.pointSize * ratio)) ?? font
        }

        // NSTabView hält immer nur den gerade sichtbaren Arbeitsbereich in seiner
        // normalen Subview-Hierarchie. Deshalb müssen alle Tab-Inhalte ausdrücklich
        // skaliert werden; sonst bleiben Experimentallabor/Vergleichslabor auf 100 %,
        // wenn der Zoom in einem anderen Arbeitsbereich geändert wurde. Das gilt auch
        // für verschachtelte TabViews im Kompositionsbereich.
        if let tabs = root as? NSTabView {
            var seen = Set<ObjectIdentifier>()
            for item in tabs.tabViewItems {
                guard let tabView = item.view else { continue }
                let id = ObjectIdentifier(tabView)
                if seen.insert(id).inserted { scaleFonts(in: tabView, ratio: ratio) }
            }
            return
        }

        for child in root.subviews { scaleFonts(in: child, ratio: ratio) }
    }

    @objc func menuAPIKeys() {
        if let w = apiWindow { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 245),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "API-Schlüssel"
        w.isReleasedWhenClosed = false
        let content = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor), stack.topAnchor.constraint(equalTo: content.topAnchor), stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor)])
        keyLabel.stringValue = "API-Key für \(provider.displayName)"
        keyField.placeholderString = "\(provider.displayName) API-Key"
        keyField.stringValue = SessionSecrets.shared.key(for: provider)
        keyField.widthAnchor.constraint(equalToConstant: 475).isActive = true
        stack.addArrangedSubview(keyLabel); stack.addArrangedSubview(keyField)
        let load = NSButton(title: "Gespeicherten Schlüssel anzeigen", target: self, action: #selector(loadKeyPressed))
        let save = NSButton(title: "Dauerhaft speichern", target: self, action: #selector(saveKeyPressed))
        let del = NSButton(title: "Gespeicherten Schlüssel löschen", target: self, action: #selector(deleteKeyPressed))
        stack.addArrangedSubview(row([load, save, del]))
        let hint = NSTextField(wrappingLabelWithString: "API-Schlüssel werden verschlüsselt im lokalen Application-Support-Ordner von Composition Lab gespeichert und beim App-Start automatisch geladen. Der macOS-Schlüsselbund wird nicht verwendet.")
        hint.textColor = .secondaryLabelColor; hint.maximumNumberOfLines = 2
        stack.addArrangedSubview(hint)
        w.contentView = content; w.center(); apiWindow = w
        applyCurrentZoom(to: w)
        w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    @objc func menuShowDrafts() {
        history = Storage.shared.loadHistory(); historyTable.reloadData()
        if let w = draftsWindow { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 430),
                         styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = "Entwürfe"
        w.minSize = NSSize(width: 620, height: 320); w.isReleasedWhenClosed = false
        let content = NSView(); let scroll = FastScrollView()
        scroll.documentView = historyTable; scroll.hasVerticalScroller = true; scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        let load = NSButton(title: "Entwurf laden", target: self, action: #selector(loadHistorySelection))
        let clear = NSButton(title: "Alle Entwürfe löschen", target: self, action: #selector(clearHistory))
        let buttons = row([load, clear]); buttons.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(buttons)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14), scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14), scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 14), scroll.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12), buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14), buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14)])
        w.contentView = content; w.center(); draftsWindow = w
        applyCurrentZoom(to: w)
        w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    @objc func menuExperimentLab() {
        selectWorkspace(1)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func generateExperiment(_ r:ExperimentRequest, window:ExperimentLabWindowController?) {
        var apiKey = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty {
            apiKey = SessionSecrets.shared.key(for: provider)
            if !apiKey.isEmpty { keyField.stringValue = apiKey }
        }
        if !apiKey.isEmpty { SessionSecrets.shared.set(apiKey, for: provider) }
        guard !apiKey.isEmpty else {
            window?.setStatus("API-Key für \(provider.displayName) fehlt.", good: false)
            return
        }

        let p = provider, m = model, e = effort
        let assignment = r.task
        guard let motifPrompt = try? LaboratoryWorkflow.prompt(kind: "motif", task: r.task,
            measures: r.measures, tempo: r.tempo, ensemble: r.ensemble, style: r.style) else {
            window?.setStatus("Ungültiger Motivauftrag.", good: false); return
        }

        window?.setStatus("KI erzeugt Motiv / Keimzelle …", good: true)
        APIClient.shared.call(provider: p, model: m, key: apiKey, effort: e, purpose: "MainViewController.generateExperiment.motif",
                              system: ComposerPrompts.system, user: motifPrompt, wantJSON: true) { [weak self, weak window] result in
            switch result {
            case .failure(let err):
                DispatchQueue.main.async {
                    window?.setStatus("Fehler: \(err.localizedDescription)", good: false)
                }
            case .success(let response):
                do {
                    let data = try APIClient.shared.extractJSON(response.text)
                    let score = try JSONDecoder().decode(Score.self, from: data)

                    try LaboratoryWorkflow.validateMotif(scoreJSON: JSONEncoder().encode(score), measures: r.measures)

                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.lastExperimentConcept = r.task
                        self.lastExperimentScore = score
                        self.lastDiagnostic = [
                            "format": "composition-lab-native-diagnostic",
                            "operation": "motif-generation",
                            "pipeline": "experiment-motif-isolated-v1",
                            "engineBuild": ComposerPrompts.engineBuild,
                            "interface": "macOS AppKit",
                            "provider": p.rawValue,
                            "model": m,
                            "reasoning": e.rawValue,
                            "requestedMeasures": r.measures,
                            "assignment": assignment,
                            "motifPrompt": motifPrompt,
                            "scoreResponse": response.text
                        ]
                        let item = HistoryItem(id: UUID(), time: Date(), title: score.ti,
                                               provider: p, model: m, concept: r.task,
                                               score: score, area: .experiment)
                        self.addHistoryItem(item)
                        window?.setScore(score)
                        window?.appendChat(p.displayName, "Motiv / Keimzelle erzeugt: \(score.ti) (\(r.measures) Takte). Die Hauptkomposition wurde nicht verändert.")
                        window?.setStatus("Motiv erzeugt. Noch nicht als Ausgangsmaterial übernommen.", good: true)
                        self.status("Experimentallabor: Motiv \"\(score.ti)\" erzeugt; Hauptkomposition unverändert.", good: true)
                    }
                } catch {
                    DispatchQueue.main.async {
                        window?.setStatus("Fehler: \(error.localizedDescription)", good: false)
                    }
                }
            }
        }
    }

    private func loadFileToExperiment(url: URL, window: ExperimentLabWindowController?) {
        do {
            let data = try Data(contentsOf: url)
            let fallback = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension.lowercased()
            let isXML = ext == "musicxml" || ext == "xml"
            let score = try (isXML
                ? MusicXMLParser.parse(data: data, fallbackTitle: fallback)
                : MIDIParser.parse(data: data, fallbackTitle: fallback))
            lastExperimentScore = score
            lastExperimentConcept = isXML ? "Importierte MusicXML-Vorlage" : "Importierte MIDI-Vorlage"
            window?.setScore(score)
            window?.appendChat("Import", "\(isXML ? "MusicXML" : "MIDI")-Datei \"\(fallback)\" als aktuelle Vorlage geladen.")
            window?.setStatus("\(isXML ? "MusicXML" : "MIDI")-Vorlage geladen.", good: true)
            status("Experimentallabor: \(isXML ? "MusicXML" : "MIDI")-Vorlage \"\(score.ti)\" geladen.", good: true)
        } catch {
            window?.setStatus("Import fehlgeschlagen: \(error.localizedDescription)", good: false)
        }
    }

    private func transferExperimentToComposition(window: ExperimentLabWindowController?) {
        guard let score = lastExperimentScore else {
            window?.setStatus("Bitte zuerst eine Vorlage erzeugen.", good: false)
            return
        }
        importedReferenceScore = score
        importedReferenceName = score.ti
        install(score: score, concept: lastExperimentConcept, provider: provider, model: model, addHistory: false)
        selectWorkspace(0)
        window?.setStatus("Vorlage an die Kompositionsseite übernommen.", good: true)
        status("Vorlage \"\(score.ti)\" als Ausgangsmaterial übernommen.", good: true)
    }

    private func transferCompareResultToComposition(_ item: HistoryItem) {
        importedReferenceScore = item.score
        importedReferenceName = item.title
        install(score: item.score, concept: item.concept, provider: item.provider, model: item.model, addHistory: false, metadata: item.extraFields)
        selectWorkspace(0)
        status("\(item.title) aus dem Vergleichslabor an die Kompositionsseite übergeben.", good: true)
    }

    private func chatExperiment(_ question:String, window:ExperimentLabWindowController?) {
        var apiKey = keyField.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
        if apiKey.isEmpty { apiKey = SessionSecrets.shared.key(for:provider); if !apiKey.isEmpty { keyField.stringValue=apiKey } }
        if !apiKey.isEmpty { SessionSecrets.shared.set(apiKey,for:provider) }
        guard !apiKey.isEmpty else { window?.appendChat("Fehler","API-Key für \(provider.displayName) fehlt."); return }
        guard let score=lastExperimentScore else { window?.appendChat("Hinweis","Bitte zuerst eine Vorlage erzeugen."); return }
        let p=provider,m=model,e=effort
        let scoreJSON=(try? String(data:JSONEncoder().encode(score),encoding:.utf8)) ?? ""
        let user = (try? LaboratoryWorkflow.prompt(kind: "analysis", task: question, first: lastExperimentConcept + "\n" + scoreJSON)) ?? ""
        APIClient.shared.call(provider:p,model:m,key:apiKey,effort:e,purpose: "MainViewController.chatExperiment", system:"Du bist ein musikalischer Analyse- und Kompositionspartner. Besprich die vorliegende musikalische Vorlage konkret und musikalisch. Ändere nicht automatisch die MIDI-Daten; antworte zunächst als Gesprächspartner.",user:user,wantJSON:false){ [weak window] result in
            DispatchQueue.main.async { switch result { case .failure(let err): window?.appendChat("Fehler",err.localizedDescription); case .success(let r): window?.appendChat(p.displayName,r.text) } }
        }
    }

    @objc func menuCompareLab() {
        history = Storage.shared.loadHistory()
        compareWindow?.update(items: history, historyItems: historyItems(for: .comparison))
        selectWorkspace(2)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func compare(a:HistoryItem,b:HistoryItem,window:CompareLabWindowController?) {
        var apiKey=keyField.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
        if apiKey.isEmpty { apiKey=SessionSecrets.shared.key(for:provider); if !apiKey.isEmpty { keyField.stringValue=apiKey } }
        if !apiKey.isEmpty { SessionSecrets.shared.set(apiKey,for:provider) }
        guard !apiKey.isEmpty else { window?.setDialogText("API-Key für \(provider.displayName) fehlt."); return }
        let p=provider,m=model,e=effort
        let enc=JSONEncoder(); let ja=(try? String(data:enc.encode(a.score),encoding:.utf8)) ?? ""; let jb=(try? String(data:enc.encode(b.score),encoding:.utf8)) ?? ""
        let user = (try? LaboratoryWorkflow.prompt(kind: "compare", task: "", first: a.concept + "\n" + ja, second: b.concept + "\n" + jb)) ?? ""
        APIClient.shared.call(provider:p,model:m,key:apiKey,effort:e,purpose: "MainViewController.compare", system:"Du bist ein musikalischer Analytiker und vergleichst zwei MIDI-Kompositionen sachlich und konkret.",user:user,wantJSON:false){ [weak window] result in DispatchQueue.main.async { switch result { case .failure(let err):window?.setDialogText("Fehler: \(err.localizedDescription)");case .success(let r):window?.setDialogText(r.text) } } }
    }

    private func routeCompareDialog(a: HistoryItem, b: HistoryItem, text: String, window: CompareLabWindowController?) {
        var apiKey = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty {
            apiKey = SessionSecrets.shared.key(for: provider)
            if !apiKey.isEmpty { keyField.stringValue = apiKey }
        }
        if !apiKey.isEmpty { SessionSecrets.shared.set(apiKey, for: provider) }
        guard !apiKey.isEmpty else {
            window?.setDialogText("API-Key für \(provider.displayName) fehlt.")
            return
        }

        let p = provider, m = model, e = effort
        let enc = JSONEncoder()
        let ja = (try? String(data: enc.encode(a.score), encoding: .utf8)) ?? ""
        let jb = (try? String(data: enc.encode(b.score), encoding: .utf8)) ?? ""
        let user = (try? LaboratoryWorkflow.prompt(kind: "route", task: text, first: a.concept + "\n" + ja, second: b.concept + "\n" + jb)) ?? ""
        let system = ComposerPrompts.system
        APIClient.shared.call(provider: p, model: m, key: apiKey, effort: e,
                              purpose: "MainViewController.routeCompareDialog", system: system, user: user, wantJSON: false) { [weak self, weak window] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .failure(let err):
                    window?.setDialogText("Fehler: \(err.localizedDescription)")
                case .success(let r):
                    let answer = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if answer.contains("[[COMPOSE]]") {
                        window?.beginGeneratedResult()
                        self.createCompareResult(a: a, b: b, instruction: text, window: window)
                    } else {
                        window?.setDialogText(answer)
                    }
                }
            }
        }
    }

    private func createCompareResult(a: HistoryItem, b: HistoryItem, instruction: String, window: CompareLabWindowController?) {
        var apiKey = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty { apiKey = SessionSecrets.shared.key(for: provider); if !apiKey.isEmpty { keyField.stringValue = apiKey } }
        if !apiKey.isEmpty { SessionSecrets.shared.set(apiKey, for: provider) }
        guard !apiKey.isEmpty else { window?.setDialogText("API-Key für \(provider.displayName) fehlt."); return }

        let p = provider, m = model, e = effort
        let enc = JSONEncoder()
        let ja = (try? String(data: enc.encode(a.score), encoding: .utf8)) ?? ""
        let jb = (try? String(data: enc.encode(b.score), encoding: .utf8)) ?? ""
        guard let assignment = try? LaboratoryWorkflow.prompt(kind: "revision", task: instruction,
            first: a.concept + "\n" + ja, second: b.concept + "\n" + jb) else { return }
        APIClient.shared.call(provider: p, model: m, key: apiKey, effort: e,
            purpose: "comparison-revision", system: ComposerPrompts.system, user: assignment, wantJSON: false) { [weak self, weak window] result in
            switch result {
            case .failure(let error): DispatchQueue.main.async { window?.setDialogText(error.localizedDescription) }
            case .success(let response):
                guard let self else { return }
                NativeLocalCompositionService(compiler: self.localCompiler).interpret(response.text) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(.some(let work)):
                            window?.setGeneratedResult(score: work.score, concept: response.text, provider: p, model: m, metadata: work.metadata)
                        case .success(nil): window?.setDialogText("Originalantwort erhalten, aber nicht lokal lesbar: " + response.text)
                        case .failure(let error): window?.setDialogText(error.localizedDescription + "\nOriginalantwort:\n" + response.text)
                        }
                    }
                }
            }
        }
    }

    private func updateWindowTitle() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        view.window?.title = "Composition Lab · Projekt: \(projectName) · V\(version)"
    }

    @objc func menuNameProject() {
        guard let value=askText(title:"Projekt benennen",message:"Name des aktuellen Projekts:",defaultValue:projectName), !value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        projectName=value.trimmingCharacters(in:.whitespacesAndNewlines); updateWindowTitle(); status("Projekt heißt jetzt \"\(projectName)\".",good:true)
    }

    private func projectDocument() -> CompositionLabProject {
        saveSettingsFromUI()
        return CompositionLabProject(name:projectName,settings:settings,concept:lastConcept,score:lastScore,source:importedReferenceScore,sourceName:importedReferenceName,history:history,experimentConcept:lastExperimentConcept,experimentScore:lastExperimentScore)
    }

    @objc func menuSaveProject() {
        v65SaveProject()
    }

    @objc func menuLoadProject() {
        v65LoadProject()
    }

    @objc func menuExportBackup() {
        saveSettingsFromUI()
        SessionSecrets.shared.set(keyField.stringValue,for:provider)
        var password=SessionSecrets.shared.backupPassword
        if password == nil { password=askText(title:"Backup-Passwort festlegen",message:"Dieses Passwort schützt API-Schlüssel, Einstellungen und Verlauf in der Backup-Datei.",secure:true) }
        guard let password, !password.isEmpty else { return }
        let payload=CompositionLabBackupPayload(settings:settings,history:history,apiKeys:SessionSecrets.shared.exportKeys())
        do {
            let data=try BackupCrypto.encrypt(payload,password:password)
            let panel=NSSavePanel(); panel.allowedFileTypes=["clabbackup"]; panel.nameFieldStringValue="Composition-Lab-Backup.clabbackup"
            guard panel.runModal() == .OK, let url=panel.url else { return }
            try data.write(to:url,options:.atomic); SessionSecrets.shared.rememberBackupPassword(password); status("Backup gespeichert.",good:true)
        } catch { status("Backup konnte nicht gespeichert werden: \(error.localizedDescription)",good:false) }
    }

    @objc func menuImportBackup() {
        let panel=NSOpenPanel(); panel.allowedFileTypes=["clabbackup"]; panel.allowsMultipleSelection=false
        guard panel.runModal() == .OK, let url=panel.url else { return }
        guard let password=askText(title:"Backup öffnen",message:"Backup-Passwort einmalig zum Einlesen dieser Datei eingeben:",secure:true), !password.isEmpty else { return }
        do {
            let payload=try BackupCrypto.decrypt(Data(contentsOf:url),password:password)
            settings=payload.settings; history=payload.history; SessionSecrets.shared.importKeys(payload.apiKeys); SessionSecrets.shared.rememberBackupPassword(password)
            Storage.shared.saveSettings(settings); Storage.shared.saveHistory(history); restoreSettings(); keyField.stringValue=SessionSecrets.shared.key(for:provider); historyTable.reloadData(); status("Backup geladen. API-Schlüssel wurden dauerhaft lokal gespeichert und stehen künftig beim Start automatisch bereit.",good:true)
        } catch { status("Backup konnte nicht geladen werden: \(error.localizedDescription)",good:false) }
    }

    // Menü-Aktionen
    @objc func menuShowHelp() {
        if let url = Bundle.main.url(forResource: "Composition_Lab_Benutzerhandbuch_V3_0", withExtension: "pdf") {
            NSWorkspace.shared.open(url)
        } else {
            menuShowQuickHelp()
        }
    }

    @objc func menuShowQuickHelp() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 620),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "Composition Lab · Kurzhilfe"
        w.minSize = NSSize(width: 540, height: 400)

        let scroll = FastScrollView(frame: NSRect(x: 0, y: 0, width: 720, height: 620))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.autoresizingMask = [.width, .height]

        let tv = NSTextView(frame: scroll.contentView.bounds)
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = false
        tv.font = NSFont.systemFont(ofSize: 14)
        tv.textContainerInset = NSSize(width: 28, height: 28)
        tv.backgroundColor = .windowBackgroundColor
        tv.textColor = .textColor
        tv.minSize = NSSize(width: 0, height: scroll.contentView.bounds.height)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.containerSize = NSSize(width: scroll.contentView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        tv.string = HelpText.handbook

        scroll.documentView = tv
        w.contentView = scroll
        w.center()
        applyCurrentZoom(to: w)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        helpWindows.append(w)
    }

    @objc func menuCompose() { composePressed() }
    @objc func menuImportMIDI() { importMIDIPressed() }
    @objc func menuClearImportedMIDI() { clearImportedMIDIPressed() }
    @objc func menuSaveMIDI() { saveMIDIPressed() }
    @objc func menuSaveJSON() { saveJSONPressed() }
    @objc func menuSaveDiagnostic() { saveDiagnosticPressed() }
    @objc func menuFocusChat() { chatInput.window?.makeFirstResponder(chatInput) }
    @objc func menuClearHistory() { clearHistory() }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
        return e
    }
}


// Runs only when the AppDelegate receives --native-self-test in an isolated
// preferences domain. It exercises the real AppKit/WebKit/engraver path offline.
extension MainViewController {
    func runNativeSelfTest(output: String, completion: @escaping (Error?) -> Void) {
        do {
            guard let path = ProcessInfo.processInfo.environment["COMPOSITION_LAB_BACKUP_FIXTURE"] else { throw APIError.badResponse("Backup-Kompatibilitätsfixture fehlt.") }
            let fixture = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]
            let password = fixture["password"] as! String
            let envelope = try JSONSerialization.data(withJSONObject: fixture["envelope"]!)
            let payload = try BackupCrypto.decrypt(envelope, password: password)
            guard payload.apiKeys["anthropic"] == "OFFLINE-TEST-NOT-A-REAL-KEY", payload.settings.prompt == "Test 𝄞" else { throw APIError.badResponse("Backup-Austausch verliert Daten.") }
            let encrypted = try BackupCrypto.encrypt(payload, password: password)
            _ = try BackupCrypto.decrypt(encrypted, password: password)
            do { _ = try BackupCrypto.decrypt(envelope, password: "wrong"); throw APIError.badResponse("Falsches Backup-Passwort akzeptiert.") }
            catch BackupCryptoError.badPassword { }
        } catch { completion(error); return }
        let bad = "\\version \"2.24.0\"\n\\score { { c''''4 e''''4 g''''4 c'''''4 } \\layout {} \\midi {} }"
        let good = "\\version \"2.24.0\"\n\\score { { c''4 e''4 g''4 c'''4 } \\layout {} \\midi {} }"
        var calls = 0
        NativeRegisterRepairService(compiler: localCompiler).repair(source: bad, transport: { _, done in
            calls += 1
            done(Result { try JSONSerialization.data(withJSONObject: ["text": good, "estimatedCostUSD": 0.03]) })
        }) { result in
            DispatchQueue.main.async {
                do {
                    let work = try result.get()
                    guard calls == 1, work.score.tr.flatMap({ $0.nt }).allSatisfy({ $0[2] < 96 }),
                          work.metadata["originalLilyPond"] == .string(bad) else { throw APIError.badResponse("Native Oktavkorrektur nicht geprüft.") }
                    self.runNativeInputSelfTest(output: output, completion: completion)
                } catch { completion(error) }
            }
        }
    }
    private func runNativeInputSelfTest(output: String, completion: @escaping (Error?) -> Void) {
        let source = "\\version \"2.24.0\"\n\\score { << \\new Staff { \\set Staff.midiInstrument = \"violin\" c''4 d'' e'' f'' } \\new PianoStaff << \\new Staff { g'4 a' b' c'' } \\new Staff { \\clef bass c4 d e f } >> >> \\layout {} \\midi {} }"
        conceptView.string = source; chatInput.stringValue = ""; ensembleField.stringValue = "Klavier"; keyField.stringValue = ""
        composePressed()
        func check(_ attempts: Int) {
            if nativeRequestInFlight {
                guard attempts > 0 else { completion(APIError.badResponse("Zeitlimit bei lokaler Auftragsübernahme.")); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { check(attempts - 1) }
                return
            }
            guard lastConcept == source, lastScore?.tr.flatMap({ $0.nt }).count == 12,
                  lastDiagnostic?["compositionAICalls"] as? Int == 0 else {
                completion(APIError.badResponse("Fertige Violin-/Klavierpartitur wurde nicht ohne API-Key lokal übernommen.")); return
            }
            pieceSlots = Array(repeating: nil, count: 10); activePieceSlot = 0
            runNativeWorkspaceSelfTest(output: output, completion: completion)
        }
        check(600)
    }
    private func runNativeWorkspaceSelfTest(output: String, completion: @escaping (Error?) -> Void) {
        let source = "\\version \"2.24.0\"\n\\header { title = \"Native Original\" tagline = ##f }\n\\score { \\new PianoStaff << \\new Staff { \\time 4/4 \\tempo 4 = 96 c'4 d' e' f' } \\new Staff { \\clef bass c4 d e f } >> \\layout {} \\midi {} }\n"
        func require(_ condition: Bool, _ message: String) throws { if !condition { throw APIError.badResponse(message) } }
        func waitFor(_ attempts: Int = 600, condition: @escaping () -> Bool, then action: @escaping () -> Void) {
            if condition() { action(); return }
            guard attempts > 0 else { completion(APIError.badResponse("Zeitlimit im nativen Mac-Funktionstest.")); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { waitFor(attempts - 1, condition: condition, then: action) }
        }
        NativeLocalCompositionService(compiler: localCompiler).interpret(source) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { completion(APIError.badResponse("Testfenster fehlt.")); return }
                do {
                    guard let work = try result.get() else { throw APIError.badResponse("Lokale Originalübernahme fehlt.") }
                    let catalogProvider = self.provider
                    self.modelCatalog.accept([CatalogModel(id: "native-model-a", name: "Gleicher Modellname", details: "A"),
                        CatalogModel(id: "native-model-b", name: "Gleicher Modellname", details: "B")], for: catalogProvider)
                    self.settings.models[catalogProvider.rawValue] = "native-model-a"
                    self.refillModels()
                    try require(self.modelPop.numberOfItems == 2 && self.model == "native-model-a", "Gleich benannte Provider-Modelle gehen in der Mac-Auswahl verloren.")
                    self.modelPop.selectItem(at: 1)
                    try require(self.model == "native-model-b", "Modellauswahl verwendet nicht die tatsächliche Kennung.")
                    self.view.layoutSubtreeIfNeeded()
                    try require(self.modelPop.bounds.width >= 160, "Das Modellfeld ist trotz erfolgreicher Modellabfrage unlesbar schmal.")
                    self.pendingCompositionSlot = 0
                    self.install(score: work.score, concept: source, provider: .gemini, model: "offline-test", metadata: work.metadata)
                    let originalMidi = self.lastMidi
                    try require(self.lastScore?.tr.reduce(0, { $0 + $1.nt.count }) == 8, "Nicht alle acht Noten übernommen.")
                    waitFor(condition: { self.musicXMLPreview.originalPreviewIsReady }) {
                        self.selectWorkspace(1)
                        self.musicXMLPreview.probeOriginalSelection { sent in
                            guard sent else { completion(APIError.badResponse("Mac-SVG-Auswahl sendet keine Quellposition.")); return }
                            waitFor(condition: { self.conceptView.selectedRange().length > 0 }) {
                                do {
                                    try require(self.workspaceSegment.selectedSegment == 0, "Notenauswahl öffnet den Editor nicht.")
                                    let invalid = FileManager.default.temporaryDirectory.appendingPathComponent("clab-invalid-" + UUID().uuidString + ".mid")
                                    try Data("invalid MIDI fixture".utf8).write(to: invalid)
                                    self.importFile(invalid, intoPieceSlot: 1)
                                    try? FileManager.default.removeItem(at: invalid)
                                    try require(self.activePieceSlot == 0 && self.pieceSlots[1] == nil && self.lastMidi == originalMidi, "Fehlerhafter Import ersetzt das aktuelle Stück.")
                                    let button = NSButton(); button.tag = 1; self.pieceSlotPressed(button)
                                    self.captureCurrentInActiveSlot()
                                    try require(self.lastScore == nil && self.pieceSlots[1] == nil, "Leerer Slot übernimmt fremde Partitur.")
                                    button.tag = 0; self.pieceSlotPressed(button)
                                    let edited = source.replacingOccurrences(of: "c'4", with: "e'4")
                                    self.conceptView.string = edited; self.refreshCurrentNotation()
                                    waitFor(condition: { !self.nativeRequestInFlight }) {
                                        do {
                                            try require(self.lastConcept == source, "Bearbeitung überschreibt das Original.")
                                            try require(self.lastMidi != originalMidi, "Bearbeitung aktualisiert MIDI nicht.")
                                            try require(self.lastPortableMetadata["lilyPondSource"] == .string(edited), "Bearbeitete Quelle fehlt.")
                                            let validMidi = self.lastMidi
                                            self.menuUndoScore()
                                            try require(self.lastMidi == originalMidi, "Partitur-Undo stellt Original-MIDI nicht wieder her.")
                                            self.menuRedoScore()
                                            try require(self.lastMidi == validMidi, "Partitur-Redo stellt bearbeitetes MIDI nicht wieder her.")
                                            self.playerVolume.doubleValue = 0; self.playerVolumeChanged()
                                            try require(self.midiPlayer.duration > 0, "Stumme Wiedergabekopie ist nicht ladbar.")
                                            self.playerVolume.doubleValue = 0.5; self.playerTempoField.integerValue = 72
                                            self.reloadMainPlayerForPlaybackSettings(errorPrefix: "Test-Player")
                                            try require(self.lastMidi == validMidi, "Player-Einstellungen verändern das exportierbare Original-MIDI.")
                                            self.conceptView.string = edited + "\n\\unbekannteStimme"
                                            self.refreshCurrentNotation()
                                            waitFor(condition: { !self.nativeRequestInFlight }) {
                                                do {
                                                    try require(self.lastMidi == validMidi && self.lastPortableMetadata["lilyPondSource"] == .string(edited), "Fehlerhafter Entwurf zerstört gültige Ausgabe.")
                                                    let doc = try JSONEncoder().encode(self.currentCLABDocument())
                                                    let restored = try JSONDecoder().decode(CompositionLabDocument.self, from: doc)
                                                    try require(restored.extraFields["lilyPondSource"] == .string(edited), "Mac-CLAB verliert angewendete Quelle.")
                                                    let report: [String: Any] = ["passed": true, "interface": "AppKit/WebKit", "offline": true,
                                                        "checks": ["finished-notation-compose-without-key", "local-original", "duplicate-model-names", "svg-to-editor", "empty-slot", "source-edit", "invalid-edit-rollback", "failed-import-rollback", "clab-metadata", "original-midi", "playback-copy", "score-undo-redo", "explicit-register-repair", "portable-encrypted-backup"]]
                                                    try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
                                                    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: output).appendingPathComponent("result.json"))
                                                    completion(nil)
                                                } catch { completion(error) }
                                            }
                                        } catch { completion(error) }
                                    }
                                } catch { completion(error) }
                            }
                        }
                    }
                } catch { completion(error) }
            }
        }
    }
}

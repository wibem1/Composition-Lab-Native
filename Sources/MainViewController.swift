import Cocoa
import Foundation

final class TopAlignedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let providerPop = NSPopUpButton()
    private let modelPop = NSPopUpButton()
    private let effortPop = NSPopUpButton()
    private let keyField = NSSecureTextField()
        private let keyLabel = NSTextField(labelWithString: "API-Key")

    private let measuresField = NSTextField(string: "")
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
    private let workspaceTabs = NSTabView()
    private let workspaceSegment = NSSegmentedControl(labels: ["Komposition", "Experimentallabor", "Vergleichslabor", "Notensatz"], trackingMode: .selectOne, target: nil, action: nil)
    private let musicXMLPresetPop = NSPopUpButton()
    private let musicXMLRhythmModePop = NSPopUpButton()
    private let musicXMLStraightNotePop = NSPopUpButton()
    private let musicXMLTripletNotePop = NSPopUpButton()
    private let musicXMLRestPop = NSPopUpButton()
    private let musicXMLSmoothingPop = NSPopUpButton()
    private let musicXMLBarStartPop = NSPopUpButton()
    private let musicXMLSplitBeatsCheck = NSButton(checkboxWithTitle: "Zusammengesetzte Notenwerte an Zählzeiten teilen und binden", target: nil, action: nil)
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
    private let playerVolume = NSSlider(value: 0.80, minValue: 0.10, maxValue: 1.0, target: nil, action: nil)
    private let playerTempoField = NSTextField(string: "120")
    private let playerTempoStepper = NSStepper()
    private let playerLoopButton = NSButton(title: "↻ Loop", target: nil, action: nil)
    private var playerTimer: Timer?
    private var experimentWindow: ExperimentLabWindowController?
    private var compareWindow: CompareLabWindowController?
    private var lastExperimentConcept = ""
    private var lastExperimentScore: Score?
    private var lastDiagnostic: [String: Any]?
    private var projectName = "Unbenannt"
    private var projectURL: URL?
    private var reaperBridgeTimer: Timer?
    private var lastReaperBridgeDate: Date?
    private var lastStudioProBridgeDate: Date?

    override func loadView() {
        NotificationCenter.default.addObserver(self, selector: #selector(midiOutputModeChanged), name: MIDIOutputManager.changedNotification, object: nil)
        view = NSView(frame: NSRect(x:0,y:0,width:1260,height:800))
        buildUI()
        restoreSettings()
        restoreCurrentPlayerState()
        if let z = settings.zoomPercent, z != 100 { setZoom(percent: CGFloat(z), resizeWindow: false, persist: false) }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateWindowTitle()
        view.window?.minSize = NSSize(width:1000,height:680)

        // Vorhandene Bridge-Dateien sind beim Programmstart nur Altbestand.
        // Sie dürfen nicht erneut die aktuelle Komposition im Player überschreiben.
        // Erst eine spätere Änderung der Übergabedatei gilt als neue DAW-Übergabe.
        if reaperBridgeTimer == nil {
            lastReaperBridgeDate = ReaperBridge.modificationDate()
            lastStudioProBridgeDate = StudioProBridge.modificationDate()
        }
        startReaperBridgeWatcher()
    }


    private func startReaperBridgeWatcher() {
        guard reaperBridgeTimer == nil else { return }
        reaperBridgeTimer = Timer.scheduledTimer(timeInterval: 0.75,
                                                 target: self,
                                                 selector: #selector(reaperBridgeTimerFired(_:)),
                                                 userInfo: nil,
                                                 repeats: true)
    }

    @objc private func reaperBridgeTimerFired(_ timer: Timer) {
        checkReaperBridge()
        checkStudioProBridge()
    }

    private func checkReaperBridge() {
        // Nur Dateien verarbeiten, die sich seit dem Start/letzten Empfang geändert haben.
        guard let date = ReaperBridge.modificationDate() else { return }
        if let last = lastReaperBridgeDate, date <= last { return }
        lastReaperBridgeDate = date
        do {
            let score = try ReaperBridge.loadScore()
            importedReferenceScore = score
            importedReferenceName = "REAPER: " + score.ti
            lastConcept = ""
            conceptView.string = ""
            install(score: score, concept: "", provider: provider, model: model, addHistory: false)
            conceptView.string = ""
            workspaceTabs.selectTabViewItem(at: 0)
            workspaceSegment.selectedSegment = 0
            NSApp.activate(ignoringOtherApps: true)
            view.window?.makeKeyAndOrderFront(nil)
            status("REAPER-Vorlage übernommen – \(score.tr.reduce(0) { $0 + $1.nt.count }) Noten.", good: true)
        } catch {
            status("REAPER-Übergabe fehlgeschlagen: \(error.localizedDescription)", good: false)
        }
    }

    private func checkStudioProBridge() {
        // Nur Dateien verarbeiten, die sich seit dem Start/letzten Empfang geändert haben.
        guard let date = StudioProBridge.modificationDate() else { return }
        if let last = lastStudioProBridgeDate, date <= last { return }
        lastStudioProBridgeDate = date
        do {
            let score = try StudioProBridge.loadScore()
            importedReferenceScore = score
            importedReferenceName = "Studio Pro: " + score.ti
            lastConcept = ""
            conceptView.string = ""
            install(score: score, concept: "", provider: provider, model: model, addHistory: false)
            conceptView.string = ""
            workspaceTabs.selectTabViewItem(at: 0)
            workspaceSegment.selectedSegment = 0
            NSApp.activate(ignoringOtherApps: true)
            view.window?.makeKeyAndOrderFront(nil)
            status("Studio-Pro-Vorlage übernommen – \(score.tr.reduce(0) { $0 + $1.nt.count }) Noten.", good: true)
        } catch {
            status("Studio-Pro-Übergabe fehlgeschlagen: \(error.localizedDescription)", good: false)
        }
    }

    private func buildUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        workspaceTabs.wantsLayer = true
        workspaceTabs.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
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

        let project = NSTextField(labelWithString: "Composition Lab")
        project.font = .systemFont(ofSize: 15, weight: .semibold)
        project.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(project)

        workspaceTabs.tabViewType = .noTabsNoBorder
        workspaceTabs.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(workspaceTabs)

        let compositionItem = NSTabViewItem(identifier: "composition")
        let experimentItem = NSTabViewItem(identifier: "experiment")
        let compareItem = NSTabViewItem(identifier: "compare")
        let notationItem = NSTabViewItem(identifier: "notation")
        compositionItem.label = "Komposition"
        experimentItem.label = "Experimentallabor"
        compareItem.label = "Vergleichslabor"
        notationItem.label = "Notensatz"
        workspaceTabs.addTabViewItem(compositionItem)
        workspaceTabs.addTabViewItem(experimentItem)
        workspaceTabs.addTabViewItem(compareItem)
        workspaceTabs.addTabViewItem(notationItem)

        let compositionHost = CompositionFileDropHostView()
        compositionHost.wantsLayer = true
        compositionHost.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        compositionItem.view = compositionHost
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
            let host = NSView()
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
            experimentItem.view = host
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
            let host = NSView()
            host.wantsLayer = true
            host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            host.addSubview(labView)
            NSLayoutConstraint.activate([
                labView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                labView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                labView.topAnchor.constraint(equalTo: host.topAnchor),
                labView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
            ])
            compareItem.view = host
        }

        let notationHost = NSView()
        notationHost.wantsLayer = true
        notationHost.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        notationItem.view = notationHost
        buildMusicXMLWorkspace(notationHost)

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
            workspaceSegment.widthAnchor.constraint(equalToConstant: 650),

            workspaceTabs.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            workspaceTabs.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            workspaceTabs.topAnchor.constraint(equalTo: header.bottomAnchor),
            workspaceTabs.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

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
        let leftScroll = NSScrollView()
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

        left.addArrangedSubview(title("Notensatz"))
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

        musicXMLPresetPop.addItems(withTitles: ["Klavier – lesbar", "MIDI-nah", "Benutzerdefiniert"])
        musicXMLRhythmModePop.addItems(withTitles: ["Auto", "Gerade", "Triolisch"])
        musicXMLStraightNotePop.addItems(withTitles: ["Aus", "Viertel", "Achtel", "16tel", "32tel", "64tel"])
        musicXMLTripletNotePop.addItems(withTitles: ["Aus", "Vierteltriolen", "Achteltriolen", "16teltriolen", "32teltriolen"])
        musicXMLRestPop.addItems(withTitles: ["Alle Pausen zeigen", "bis 32tel glätten", "bis 16tel glätten", "bis Achtel glätten"])
        musicXMLSmoothingPop.addItems(withTitles: ["Aus", "Leicht", "Mittel", "Stark"])
        musicXMLBarStartPop.addItems(withTitles: ["Aus", "bis 32tel", "bis 16tel", "bis Achtel"])

        musicXMLPresetPop.target = self
        musicXMLPresetPop.action = #selector(musicXMLPresetChanged)
        for pop in [musicXMLRhythmModePop, musicXMLStraightNotePop, musicXMLTripletNotePop, musicXMLRestPop, musicXMLSmoothingPop, musicXMLBarStartPop] {
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
        musicXMLPreview.onRefreshRequested = { [weak self] in self?.refreshMusicXMLPreview() }
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
            splitAtBeatBoundaries: musicXMLSplitBeatsCheck.state == .on
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
    }

    private func saveNotationProfile() {
        Storage.shared.saveNotationProfile(notationProfile)
    }

    private func restoreMusicXMLDisplaySettings() {
        if let stored = Storage.shared.loadNotationProfile() {
            notationProfile = stored
        } else {
            // Einmalige Migration älterer V4.9.0/V5.0.11-Einstellungen.
            let d = UserDefaults.standard
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
            (o.splitAtBeatBoundaries ? "Bindungen an Zählzeiten aktiv." : "keine automatische Zählzeitenteilung.")
    }

    private func scheduleMusicXMLPreviewRefresh() {
        musicXMLPreviewTimer?.invalidate()
        musicXMLPreviewTimer = Timer.scheduledTimer(timeInterval: 0.35,
                                                    target: self,
                                                    selector: #selector(musicXMLPreviewTimerFired(_:)),
                                                    userInfo: nil,
                                                    repeats: false)
    }

    @objc private func musicXMLPreviewTimerFired(_ timer: Timer) {
        refreshMusicXMLPreview()
    }

    private func refreshMusicXMLPreview() {
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
        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(split)
        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            split.topAnchor.constraint(equalTo: parent.topAnchor),
            split.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        let leftScroll = NSScrollView()
        leftScroll.hasVerticalScroller = true
        leftScroll.drawsBackground = false
        let left = TopAlignedDocumentView()
        left.translatesAutoresizingMaskIntoConstraints = false
        leftScroll.documentView = left
        leftScroll.addConstraint(left.widthAnchor.constraint(equalToConstant: 350))
        leftScroll.widthAnchor.constraint(equalToConstant: 350).isActive = true

        let right = NSView()
        split.addArrangedSubview(leftScroll)
        split.addArrangedSubview(right)
        split.setPosition(365, ofDividerAt: 0)

        buildLeft(left)
        buildRight(right)
    }

    @objc private func workspaceChanged() {
        let i = max(0, min(workspaceSegment.selectedSegment, workspaceTabs.numberOfTabViewItems - 1))
        workspaceTabs.selectTabViewItem(at: i)
        refreshVisibleHistories()
        if i == 3 { scheduleMusicXMLPreviewRefresh() }
    }

    private func selectWorkspace(_ index: Int) {
        workspaceSegment.selectedSegment = max(0, min(index, 3))
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

        let s = NSScrollView()
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
        cstack.addArrangedSubview(title("Musikalischer Impuls"))
        let cs = textScroll(conceptView, minHeight:275)
        cstack.addArrangedSubview(cs); cs.widthAnchor.constraint(equalTo:cstack.widthAnchor).isActive = true
        conceptView.isEditable = false

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
        let playButton = NSButton(title:"▶", target:self, action:#selector(playCurrentMIDI))
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
        playerTempoStepper.minValue = 20; playerTempoStepper.maxValue = 300; playerTempoStepper.increment = 1
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
        let scroll = NSScrollView()
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
        if let mi = state.provider.models.firstIndex(where: { $0.0 == state.model }) {
            modelPop.selectItem(at: mi)
        }
        keyField.stringValue = SessionSecrets.shared.key(for: state.provider)
        status("\(state.score.ti) als letzter Player-Stand wiederhergestellt.", good: true)
    }

    private func restoreSettings() {
        if let i = Provider.allCases.firstIndex(of: settings.provider) { providerPop.selectItem(at:i) }
        refillModels()
        let pkey = settings.provider.rawValue
        if let m = settings.models[pkey], let idx = settings.provider.models.firstIndex(where:{$0.0 == m}) { modelPop.selectItem(at:idx) }
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
        let list = provider.models
        guard !list.isEmpty else { return "" }
        return list[max(0,min(modelPop.indexOfSelectedItem,list.count-1))].0
    }
    private var effort: Effort { Effort.allCases[max(0,effortPop.indexOfSelectedItem)] }

    private func refillModels() {
        modelPop.removeAllItems()
        modelPop.addItems(withTitles: provider.models.map{$0.1})
        let stored = settings.models[provider.rawValue]
        if let stored, let idx = provider.models.firstIndex(where:{$0.0 == stored}) {
            modelPop.selectItem(at:idx)
        } else { modelPop.selectItem(at:0) }
        keyLabel.stringValue = "API-Key für \(provider.displayName)"
        keyField.placeholderString = "\(provider.displayName) API-Key"
    }

    @objc private func providerChanged() {
        saveSettingsFromUI()
        refillModels()
        keyField.stringValue = SessionSecrets.shared.key(for: provider)
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

    private func basePrompt() -> String {
        func value(_ raw:String, fallback:String)->String {
            let v=raw.trimmingCharacters(in:.whitespacesAndNewlines)
            return v.isEmpty ? fallback : v
        }
        let taskRaw=promptView.string.trimmingCharacters(in:.whitespacesAndNewlines)
        let task=taskRaw.isEmpty ? "" : taskRaw
        var result = """
        Besetzung: \(value(ensembleField.stringValue, fallback:"frei"))
        Takte: \(value(measuresField.stringValue, fallback:"32"))
        Taktart: \(value(meterField.stringValue, fallback:"4/4"))
        Tempo: \(value(tempoField.stringValue, fallback:"96")) BPM
        Tonart: \(value(musicalKeyField.stringValue, fallback:"frei"))

        Auftrag:
        \(task)
        """
        if let imported=importedReferenceScore,
           let data=try? JSONEncoder().encode(imported),
           let json=String(data:data,encoding:.utf8) {
            result += "\n\nVORHANDENES MATERIAL (\(imported.ti)):\n\(json)"
        }
        return result
    }

    private func conceptDisplay(_ concept: String, provider: Provider, model: String) -> String {
        let modelName = provider.models.first(where: { $0.0 == model })?.1 ?? model
        return "KI: \(provider.displayName) · \(modelName)\n\n\(concept)"
    }

    private func titleAvoidanceInstruction() -> String {
        let recent = Storage.shared.loadHistory()
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let unique = Array(NSOrderedSet(array: recent).compactMap { $0 as? String }.prefix(12))
        guard !unique.isEmpty else {
            return "Vergib der Komposition einen eigenständigen, prägnanten Titel."
        }
        let list = unique.map { "– \($0)" }.joined(separator: "\n")
        return """
        TITEL:
        Vergib der Komposition einen neuen, eigenständigen und prägnanten Titel.
        Verwende keinen der folgenden bereits vergebenen Titel erneut und vermeide auch bloße minimale Varianten davon:
        \(list)
        """
    }

    @objc private func composePressed() {
        let tempoText = tempoField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tempoText.isEmpty && Double(tempoText.replacingOccurrences(of: ",", with: ".")) == nil {
            status("Tempo bitte als Zahl eingeben oder das Feld leer lassen.", good: false)
            return
        }
        var key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { key = SessionSecrets.shared.key(for:provider); if !key.isEmpty { keyField.stringValue=key } }
        if !key.isEmpty { SessionSecrets.shared.set(key, for:provider) }
        guard !key.isEmpty else { status("Bitte API-Key für \(provider.displayName) eingeben.", good: false); return }
        saveSettingsFromUI()
        // Kein Zugriff auf den macOS-Schlüsselbund: Schlüssel gelten nur für diese Sitzung.

        let p = provider
        let m = model
        let e = effort
        let prompt = basePrompt()
        status("KI entwickelt musikalischen Impuls …", good: true)

        APIClient.shared.call(provider: p, model: m, key: key, effort: e,
                              system: ComposerPrompts.system,
                              user: ComposerPrompts.conceptPrompt(prompt),
                              wantJSON: false) { [weak self] firstResult in
            switch firstResult {
            case .failure(let error):
                DispatchQueue.main.async { self?.status("Fehler: \(error.localizedDescription)", good: false) }
            case .success(let concept):
                DispatchQueue.main.async {
                    self?.lastConcept = concept.text
                    self?.conceptView.string = self?.conceptDisplay(concept.text, provider: p, model: m) ?? concept.text
                    self?.status("KI komponiert …", good: true)
                }

                let compPrompt = """
                \(ComposerPrompts.technical)

                AUFTRAG:
                \(prompt)

                DEIN KONZEPT:
                \(concept.text)

                \(self?.titleAvoidanceInstruction() ?? "Vergib der Komposition einen eigenständigen, prägnanten Titel.")

                Gib jetzt die fertige JSON-Partitur aus.
                """

                APIClient.shared.call(provider: p, model: m, key: key, effort: e,
                                      system: ComposerPrompts.system, user: compPrompt, wantJSON: true) { [weak self] secondResult in
                    switch secondResult {
                    case .failure(let error):
                        DispatchQueue.main.async { self?.status("Fehler: \(error.localizedDescription)", good: false) }
                    case .success(let response):
                        do {
                            let data = try APIClient.shared.extractJSON(response.text)
                            let score = try JSONDecoder().decode(Score.self, from: data)
                            let inputTokens = concept.inputTokens + response.inputTokens
                            let outputTokens = concept.outputTokens + response.outputTokens
                            let costUSD = APICost.estimate(provider: p, model: m, inputTokens: inputTokens, outputTokens: outputTokens)
                            DispatchQueue.main.async {
                                self?.lastDiagnostic = [
                                    "format": "composition-lab-native-diagnostic",
                                    "engineBuild": ComposerPrompts.engineBuild,
                                    "interface": "macOS AppKit",
                                    "interfaceVersion": "1.0",
                                    "provider": p.rawValue,
                                    "model": m,
                                    "reasoning": e.rawValue,
                                    "assignment": prompt,
                                    "systemPrompt": ComposerPrompts.system,
                                    "conceptPrompt": ComposerPrompts.conceptPrompt(prompt),
                                    "conceptResponse": concept.text,
                                    "compositionPrompt": compPrompt,
                                    "scoreResponse": response.text
                                ]
                                self?.install(score: score, concept: concept.text, provider: p, model: m,
                                              costUSD: costUSD, inputTokens: inputTokens, outputTokens: outputTokens)
                                self?.status("Komposition erfolgreich abgeschlossen! · API-Kosten ca. \(APICost.display(costUSD))", good: true)
                            }
                        } catch {
                            DispatchQueue.main.async { self?.status("Fehler: \(error.localizedDescription)", good: false) }
                        }
                    }
                }
            }
        }
    }

    private func install(score:Score, concept:String, provider:Provider, model:String, addHistory:Bool = true,
                         costUSD: Double? = nil, inputTokens: Int? = nil, outputTokens: Int? = nil) {
        lastScore = score; lastConcept = concept; lastProvider = provider; lastModel = model
        musicXMLCurrentLabel.stringValue = "Aktuelles Stück: " + score.ti
        scheduleMusicXMLPreviewRefresh()
        lastCostUSD = costUSD ?? 0
        lastInputTokens = inputTokens ?? 0
        lastOutputTokens = outputTokens ?? 0
        lastMidi = MIDIBuilder.build(score)
        do {
            try StudioProBridge.writeReturnScore(score)
        } catch {
            // Die Studio-Pro-Rückgabe ist eine Komfortfunktion und darf die Komposition nicht blockieren.
            print("Studio Pro return JSON write failed: \(error.localizedDescription)")
        }
        if let midi = lastMidi {
            do {
                try StudioProBridge.writeReturnMIDI(midi)
            } catch {
                // Die Studio-Pro-Rückgabe ist eine Komfortfunktion und darf die Komposition nicht blockieren.
                print("Studio Pro return MIDI write failed: \(error.localizedDescription)")
            }
        }
        do {
            try ReaperBridge.writeResult(score: score)
        } catch {
            // Die REAPER-Rückgabe ist eine Komfortfunktion und darf die Komposition nicht blockieren.
            print("REAPER result bridge write failed: \(error.localizedDescription)")
        }
        let displayBPM = max(20, min(300, Int(score.bpm.rounded())))
        playerTempoField.integerValue = displayBPM
        playerTempoStepper.integerValue = displayBPM
        if let midi = lastMidi { try? midiPlayer.load(score: score, data: midi) }
        updatePlayerTime()
        var info = "\(score.ti)\n\(Int(score.bpm)) BPM · \(score.k) · \(score.tr.count) Spur(en)\n\(score.sm)"
        if let costUSD = costUSD { info += "\nAPI-Kosten ca.: \(APICost.display(costUSD))" }
        resultLabel.stringValue = info
        if let jd = try? JSONEncoder.pretty.encode(score) { jsonView.string = String(data:jd,encoding:.utf8) ?? "" }
        validationView.string = validate(score)
        conceptView.string = concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : conceptDisplay(concept, provider: provider, model: model)
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
                                           costUSD:costUSD,inputTokens:inputTokens,outputTokens:outputTokens,area:.composition),at:0)
                history = trimmedHistory(history)
                Storage.shared.saveHistory(history)
                refreshVisibleHistories()
            }
        }
    }

    @objc private func playCurrentMIDI() {
        guard lastMidi != nil else { status("Noch keine MIDI-Komposition vorhanden.", good:false); return }
        midiPlayer.play(); startPlayerTimer(); status("Wiedergabe läuft.", good:true)
    }
    @objc private func playerLoopChanged() {
        let active = (playerLoopButton.state == .on)
        midiPlayer.loopEnabled = active
        playerLoopButton.title = active ? "↻ Loop AN" : "↻ Loop"
        playerLoopButton.contentTintColor = active ? .systemGreen : nil
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
        if dur > 0 { playerProgress.doubleValue = max(0, min(1, pos / dur)) } else { playerProgress.doubleValue = 0 }
    }

    @objc private func playerSeekChanged() {
        midiPlayer.seek(fraction: playerProgress.doubleValue)
        updatePlayerTime()
    }

    private func scoreWithVolume(_ score: Score, factor: Double) -> Score {
        var sc = score
        sc.tr = sc.tr.map { tr in
            var t = tr
            t.nt = tr.nt.map { n in
                var x = n
                if x.count > 3 { x[3] = max(1, min(127, x[3] * factor)) }
                return x
            }
            return t
        }
        return sc
    }

    private func reloadMainPlayerForPlaybackSettings(errorPrefix: String) {
        guard let score = lastScore else { return }
        let wasPlaying = midiPlayer.isPlaying
        let fraction = midiPlayer.duration > 0 ? midiPlayer.position / midiPlayer.duration : 0
        var adjusted = scoreWithVolume(score, factor: playerVolume.doubleValue)
        var bpm = playerTempoField.integerValue
        if bpm <= 0 { bpm = Int(score.bpm.rounded()) }
        bpm = max(20, min(300, bpm))
        playerTempoField.integerValue = bpm
        playerTempoStepper.integerValue = bpm
        adjusted.bpm = Double(bpm)
        let data = MIDIBuilder.build(adjusted)
        do {
            try midiPlayer.load(score: adjusted, data: data)
            midiPlayer.seek(fraction: fraction)
            if wasPlaying { midiPlayer.play(); startPlayerTimer() }
            updatePlayerTime()
        } catch { status("\(errorPrefix): \(error.localizedDescription)", good:false) }
    }

    @objc private func playerTempoStepperChanged() {
        playerTempoField.integerValue = playerTempoStepper.integerValue
        playerTempoChanged()
    }

    @objc private func playerTempoChanged() {
        reloadMainPlayerForPlaybackSettings(errorPrefix: "Player-Tempo konnte nicht geändert werden")
    }

    @objc private func playerVolumeChanged() {
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
        if score.bpm < 20 || score.bpm > 300 { errors.append("Tempo ungültig: \(score.bpm)") }
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

    @objc private func chatPressed() {
        let msg = chatInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty, let score = lastScore else { return }
        var key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { key = SessionSecrets.shared.key(for:provider); if !key.isEmpty { keyField.stringValue=key } }
        if !key.isEmpty { SessionSecrets.shared.set(key, for:provider) }
        guard !key.isEmpty else { status("Bitte API-Key eingeben.", good: false); return }
        let p = provider
        let m = model
        let e = effort
        let conceptSnapshot = lastConcept
        appendChat("Du", msg)
        chatInput.stringValue = ""
        status("KI arbeitet mit Konzept und Partitur …", good: true)

        do {
            let scoreData = try JSONEncoder().encode(score)
            let scoreText = String(data: scoreData, encoding: .utf8) ?? "{}"
            let prompt = """
            \(ComposerPrompts.technical)

            URSPRÜNGLICHE / AKTUELLE KOMPOSITIONSIDEE:
            \(conceptSnapshot.isEmpty ? "Keine Kompositionsidee gespeichert." : conceptSnapshot)

            AKTUELLE PARTITUR (JSON):
            \(scoreText)

            NUTZER-ANWEISUNG / FRAGE:
            \(msg)

            Du kannst mit dem Nutzer sowohl die Kompositionsidee als auch die konkrete Partitur besprechen. Wenn der Nutzer nur eine Frage stellt, ändere nichts. Wenn er ausdrücklich die Kompositionsidee ändern möchte, gib die überarbeitete vollständige Kompositionsidee im Feld concept zurück. Wenn er Änderungen an der Musik verlangt, darfst du die Partitur entsprechend ändern. Bewahre nicht verlangte Aspekte nach Möglichkeit unverändert.

            Antworte ausschließlich mit einem JSON-Objekt im Format: {"reply":"Deine Textantwort", "concept": null ODER "vollständige geänderte Kompositionsidee", "score": null ODER modifizierte Partitur falls Noten geändert wurden}
            """

            APIClient.shared.call(provider: p, model: m, key: key, effort: e,
                                  system: ComposerPrompts.system, user: prompt, wantJSON: true) { [weak self] result in
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.appendChat("Fehler", error.localizedDescription)
                        self?.status("Fehler: \(error.localizedDescription)", good: false)
                    }
                case .success(let response):
                    do {
                        let data = try APIClient.shared.extractJSON(response.text)
                        let object = try JSONSerialization.jsonObject(with: data) as? [String:Any] ?? [:]
                        let reply = object["reply"] as? String ?? "Antwort erhalten."
                        var newConcept: String? = nil
                        var newScore: Score? = nil
                        if let c = object["concept"] as? String, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { newConcept = c }
                        if let scObj = object["score"], !(scObj is NSNull) {
                            let sd = try JSONSerialization.data(withJSONObject: scObj)
                            newScore = try JSONDecoder().decode(Score.self, from: sd)
                        }
                        let chatCostUSD = APICost.estimate(provider: p, model: m, inputTokens: response.inputTokens, outputTokens: response.outputTokens)
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            self.lastCostUSD += chatCostUSD
                            self.lastInputTokens += response.inputTokens
                            self.lastOutputTokens += response.outputTokens
                            self.appendChat(p.displayName, reply)
                            var changed = false
                            if let c = newConcept {
                                self.lastConcept = c
                                self.conceptView.string = self.conceptDisplay(c, provider: p, model: m)
                                changed = true
                            }
                            if let sc = newScore {
                                self.lastScore = sc
                                self.lastMidi = MIDIBuilder.build(sc)
                                do {
                                    try StudioProBridge.writeReturnScore(sc)
                                    if let midi = self.lastMidi {
                                        try StudioProBridge.writeReturnMIDI(midi)
                                    }
                                } catch {
                                    print("Studio Pro return update failed: \(error.localizedDescription)")
                                }
                                self.resultLabel.stringValue = "\(sc.ti) (Überarbeitet)\nAPI-Kosten bisher ca.: \(APICost.display(self.lastCostUSD))"
                                self.validationView.string = self.validate(sc)
                                if let jd = try? JSONEncoder.pretty.encode(sc) { self.jsonView.string = String(data: jd, encoding: .utf8) ?? "" }
                                changed = true
                            }
                            if changed, let sc = self.lastScore {
                                self.history.insert(HistoryItem(id: UUID(), time: Date(), title: sc.ti, provider: p, model: m, concept: self.lastConcept, score: sc,
                                                                costUSD: self.lastCostUSD, inputTokens: self.lastInputTokens, outputTokens: self.lastOutputTokens, area: .composition), at: 0)
                                self.history = self.trimmedHistory(self.history)
                                Storage.shared.saveHistory(self.history)
                                self.refreshVisibleHistories()
                            }
                            self.status("Antwort erhalten. · Diese KI-Anfrage ca. \(APICost.display(chatCostUSD))", good: true)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self?.appendChat("Fehler", error.localizedDescription)
                            self?.status("Fehler: \(error.localizedDescription)", good: false)
                        }
                    }
                }
            }
        } catch {
            appendChat("Fehler", error.localizedDescription)
            status("Fehler: \(error.localizedDescription)", good: false)
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
            install(score: score, concept: "", provider: provider, model: model, addHistory: false)
            conceptView.string = ""
            workspaceTabs.selectTabViewItem(at: 0)
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
            workspaceTabs.selectTabViewItem(at: 0)
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
        return CompositionLabDocument(
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
            if let mi = p.models.firstIndex(where: { $0.0 == m }) {
                modelPop.selectItem(at: mi)
            }
            keyField.stringValue = SessionSecrets.shared.key(for: p)

            install(score: doc.score,
                    concept: doc.concept,
                    provider: p,
                    model: m,
                    addHistory: false,
                    costUSD: doc.costUSD,
                    inputTokens: doc.inputTokens,
                    outputTokens: doc.outputTokens)

            lastConcept = doc.concept
            lastProvider = doc.provider
            lastModel = doc.model
            projectName = doc.title
            projectURL = url
            saveSettingsFromUI()
            updateWindowTitle()
            workspaceTabs.selectTabViewItem(at: 0)
            workspaceSegment.selectedSegment = 0
            status("CLAB-Datei „\(doc.title)“ vollständig geladen.", good:true)
        } catch {
            status("CLAB-Datei konnte nicht geladen werden: \(error.localizedDescription)", good:false)
        }
    }

    private func loadLegacyProject(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(CompositionLabProject.self, from: data)
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
        guard let d=lastDiagnostic, JSONSerialization.isValidJSONObject(d), let data=try? JSONSerialization.data(withJSONObject:d,options:[.prettyPrinted,.sortedKeys]) else {
            status("Noch keine Diagnosedatei vorhanden. Bitte zuerst komponieren.",good:false); return
        }
        let p=NSSavePanel(); p.allowedFileTypes=["json"]; p.nameFieldStringValue=safeFilename(lastScore?.ti ?? "Komposition")+"-Diagnose-Engine14.json"
        if p.runModal() == .OK, let url = p.url { do { try data.write(to:url); status("Diagnosedatei gespeichert.",good:true) } catch { status("Speichern fehlgeschlagen: \(error.localizedDescription)",good:false) } }
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
                costUSD:h.costUSD, inputTokens:h.inputTokens, outputTokens:h.outputTokens)

        if let pi = Provider.allCases.firstIndex(of:h.provider) { providerPop.selectItem(at:pi); refillModels() }
        if let mi = h.provider.models.firstIndex(where:{$0.0==h.model}) { modelPop.selectItem(at:mi) }
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
        let content = NSView(); let scroll = NSScrollView()
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
        var apiKey=keyField.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
        if apiKey.isEmpty { apiKey=SessionSecrets.shared.key(for:provider); if !apiKey.isEmpty { keyField.stringValue=apiKey } }
        if !apiKey.isEmpty { SessionSecrets.shared.set(apiKey,for:provider) }
        guard !apiKey.isEmpty else { window?.setStatus("API-Key für \(provider.displayName) fehlt.",good:false); return }
        let p=provider,m=model,e=effort
        let tempo=r.tempo.isEmpty ? "96" : r.tempo
        let ensemble=r.ensemble.isEmpty ? "frei" : r.ensemble
        let stylePrefix=r.style.isEmpty ? "" : "Stil / Charakter: \(r.style)\n"
        let assignment="""
        Besetzung: \(ensemble)
        Takte: \(r.measures)
        Taktart: 4/4
        Tempo: \(tempo) BPM
        Tonart: frei

        Auftrag:
        \(stylePrefix)\(r.task)
        """
        APIClient.shared.call(provider:p,model:m,key:apiKey,effort:e,system:ComposerPrompts.system,user:ComposerPrompts.conceptPrompt(assignment),wantJSON:false){ [weak self, weak window] first in
            switch first {
            case .failure(let err): DispatchQueue.main.async { window?.setStatus("Fehler: \(err.localizedDescription)",good:false) }
            case .success(let concept):
                let prompt="""
                \(ComposerPrompts.technical)

                AUFTRAG:
                \(assignment)

                DEIN KONZEPT:
                \(concept.text)

                \(self?.titleAvoidanceInstruction() ?? "Vergib der Komposition einen eigenständigen, prägnanten Titel.")

                Gib jetzt die fertige JSON-Partitur aus.
                """
                APIClient.shared.call(provider:p,model:m,key:apiKey,effort:e,system:ComposerPrompts.system,user:prompt,wantJSON:true){ second in
                    switch second {
                    case .failure(let err): DispatchQueue.main.async { window?.setStatus("Fehler: \(err.localizedDescription)",good:false) }
                    case .success(let response):
                        do {
                            let data=try APIClient.shared.extractJSON(response.text)
                            let score=try JSONDecoder().decode(Score.self,from:data)
                            DispatchQueue.main.async {
                                guard let self=self else { return }
                                self.lastExperimentConcept = concept.text
                                self.lastExperimentScore = score
                                let item = HistoryItem(id: UUID(), time: Date(), title: score.ti, provider: p, model: m, concept: concept.text, score: score, area: .experiment)
                                self.addHistoryItem(item)
                                window?.setScore(score)
                                window?.appendChat(p.displayName, "Vorlage erzeugt: \(score.ti). Du kannst sie hier besprechen und bei Gefallen an die Kompositionsseite übernehmen.")
                                window?.setStatus("Vorlage erzeugt. Noch nicht in die Komposition übernommen.",good:true)
                                self.status("Experimentallabor: Vorlage \"\(score.ti)\" erzeugt.",good:true)
                            }
                        } catch { DispatchQueue.main.async { window?.setStatus("Fehler: \(error.localizedDescription)",good:false) } }
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
        install(score: item.score, concept: item.concept, provider: item.provider, model: item.model, addHistory: false)
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
        let user="""
        MUSIKALISCHER IMPULS:
        \(lastExperimentConcept)

        VORLAGE:
        \(scoreJSON)

        FRAGE / WUNSCH:
        \(question)
        """
        APIClient.shared.call(provider:p,model:m,key:apiKey,effort:e,system:"Du bist ein musikalischer Analyse- und Kompositionspartner. Besprich die vorliegende musikalische Vorlage konkret und musikalisch. Ändere nicht automatisch die MIDI-Daten; antworte zunächst als Gesprächspartner.",user:user,wantJSON:false){ [weak window] result in
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
        let user="""
        VERGLEICHE A UND B MUSIKALISCH.
        A: \(a.title)\nImpuls: \(a.concept)\nMIDI-JSON: \(ja)
        B: \(b.title)\nImpuls: \(b.concept)\nMIDI-JSON: \(jb)

        Beurteile knapp: Charakter, motivische Arbeit, Harmonik, Rhythmik, Form, Eigenständigkeit und welche Fassung musikalisch überzeugender ist. Begründe konkret.
        """
        APIClient.shared.call(provider:p,model:m,key:apiKey,effort:e,system:"Du bist ein musikalischer Analytiker und vergleichst zwei MIDI-Kompositionen sachlich und konkret.",user:user,wantJSON:false){ [weak window] result in DispatchQueue.main.async { switch result { case .failure(let err):window?.setDialogText("Fehler: \(err.localizedDescription)");case .success(let r):window?.setDialogText(r.text) } } }
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
        let user = """
        MUSIK A: \(a.title)
        Impuls A: \(a.concept)
        MIDI-JSON A: \(ja)

        MUSIK B: \(b.title)
        Impuls B: \(b.concept)
        MIDI-JSON B: \(jb)

        NUTZER:
        \(text)
        """
        let system = """
        Du bist der KI-Dialog im Vergleichslabor einer MIDI-Kompositions-App.
        Entscheide anhand der Bedeutung der Nutzereingabe:
        - Wenn der Nutzer eine neue, veränderte, kombinierte, fortgesetzte oder sonstwie neu zu komponierende musikalische Fassung aus A und/oder B verlangt, antworte AUSSCHLIESSLICH mit [[COMPOSE]].
        - Wenn der Nutzer nur analysieren, vergleichen, fragen, diskutieren oder eine Einschätzung erhalten möchte, antworte normal als musikalischer Gesprächspartner.
        WICHTIG: Erzeuge in diesem Dialog niemals Python-Code, MIDI-Binärdaten, Base64, ein MIDI-Skript oder Anweisungen zum Erzeugen einer Datei. Behaupte auch nicht, dass du keine Binärdatei anhängen kannst. Die App erzeugt MIDI selbst.
        """
        APIClient.shared.call(provider: p, model: m, key: apiKey, effort: e,
                              system: system, user: user, wantJSON: false) { [weak self, weak window] result in
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

    private func chatCompare(a: HistoryItem, b: HistoryItem, question: String, window: CompareLabWindowController?) {
        var apiKey = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty { apiKey = SessionSecrets.shared.key(for: provider); if !apiKey.isEmpty { keyField.stringValue = apiKey } }
        if !apiKey.isEmpty { SessionSecrets.shared.set(apiKey, for: provider) }
        guard !apiKey.isEmpty else { window?.setDialogText("API-Key für \(provider.displayName) fehlt."); return }
        let p = provider, m = model, e = effort
        let enc = JSONEncoder()
        let ja = (try? String(data: enc.encode(a.score), encoding: .utf8)) ?? ""
        let jb = (try? String(data: enc.encode(b.score), encoding: .utf8)) ?? ""
        let user = """
        MUSIK A: \(a.title)
        Impuls A: \(a.concept)
        MIDI-JSON A: \(ja)

        MUSIK B: \(b.title)
        Impuls B: \(b.concept)
        MIDI-JSON B: \(jb)

        FRAGE / WUNSCH:
        \(question)
        """
        APIClient.shared.call(provider: p, model: m, key: apiKey, effort: e,
                              system: "Du bist ein musikalischer Analyse- und Kompositionspartner. Besprich zwei vorliegende MIDI-Kompositionen konkret und musikalisch. Antworte zunächst als Gesprächspartner und erzeuge in diesem Dialog keine JSON-Partitur.",
                              user: user, wantJSON: false) { [weak window] result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let err): window?.setDialogText("Fehler: \(err.localizedDescription)")
                case .success(let r): window?.setDialogText(r.text)
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
        let assignment = """
        Zwei vorhandene Kompositionen sind Ausgangsmaterial.

        A: \(a.title)
        Impuls A: \(a.concept)
        MIDI-JSON A: \(ja)

        B: \(b.title)
        Impuls B: \(b.concept)
        MIDI-JSON B: \(jb)

        Auftrag:
        \(instruction)
        """

        APIClient.shared.call(provider: p, model: m, key: apiKey, effort: e,
                              system: ComposerPrompts.system,
                              user: ComposerPrompts.conceptPrompt(assignment),
                              wantJSON: false) { [weak window] first in
            switch first {
            case .failure(let err): DispatchQueue.main.async { window?.setDialogText("Fehler: \(err.localizedDescription)") }
            case .success(let concept):
                let prompt = """
                \(ComposerPrompts.technical)

                AUFTRAG:
                \(assignment)

                DEIN KONZEPT:
                \(concept.text)

                \(self.titleAvoidanceInstruction())

                Gib jetzt die fertige JSON-Partitur aus.
                """
                APIClient.shared.call(provider: p, model: m, key: apiKey, effort: e,
                                      system: ComposerPrompts.system, user: prompt, wantJSON: true) { second in
                    switch second {
                    case .failure(let err): DispatchQueue.main.async { window?.setDialogText("Fehler: \(err.localizedDescription)") }
                    case .success(let response):
                        do {
                            let data = try APIClient.shared.extractJSON(response.text)
                            let score = try JSONDecoder().decode(Score.self, from: data)
                            DispatchQueue.main.async { window?.setGeneratedResult(score: score, concept: concept.text, provider: p, model: m) }
                        } catch {
                            DispatchQueue.main.async { window?.setDialogText("Fehler: \(error.localizedDescription)") }
                        }
                    }
                }
            }
        }
    }

    private func updateWindowTitle() {
        view.window?.title = "Composition Lab · Projekt: \(projectName) · V5.0.12"
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
        saveCLABDocument()
    }

    @objc func menuLoadProject() {
        openCLABPressed()
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

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 720, height: 620))
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

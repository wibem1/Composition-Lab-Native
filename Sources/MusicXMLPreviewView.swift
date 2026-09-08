import Cocoa
import WebKit
import PDFKit

/// Schnelle, rein visuelle MusicXML-Vorschau.
/// Das MusicXML wird von Composition Lab erzeugt; Verovio rendert es nur als SVG.
/// MIDI und interner Score werden hier niemals verändert.
final class MusicXMLPreviewView: NSView, WKScriptMessageHandler, WKNavigationDelegate {
    private let webView: WKWebView
    private let backButton = NSButton(title: "◀", target: nil, action: nil)
    private let forwardButton = NSButton(title: "▶", target: nil, action: nil)
    private let pageLabel = NSTextField(labelWithString: "Seite – / –")
    private let minusButton = NSButton(title: "−", target: nil, action: nil)
    private let plusButton = NSButton(title: "+", target: nil, action: nil)
    private let zoomLabel = NSTextField(labelWithString: "100 %")
    private let refreshButton = NSButton(title: "Aktualisieren", target: nil, action: nil)
    private let printButton = NSButton(title: "Drucken …", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "Vorschau wird vorbereitet …")

    var onRefreshRequested: (() -> Void)?

    private var ready = false
    private var pendingData: Data?
    private var currentPage = 1
    private var pageCount = 0
    private var zoomPercent = 100
    private var isPrinting = false
    private var magnificationObservation: NSKeyValueObservation?

    override init(frame frameRect: NSRect) {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init(frame: frameRect)

        config.userContentController.add(self, name: "preview")
        webView.navigationDelegate = self

        // Native WebKit-Vergrößerung: Maus-/Trackpad-Zoom und +/- benutzen denselben
        // persistenten Zoomwert. Ein erneutes Rendern der Partitur setzt ihn nicht mehr zurück.
        webView.allowsMagnification = true
        magnificationObservation = webView.observe(\.magnification, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            let percent = Int((webView.magnification * 100.0).rounded())
            self.zoomPercent = max(50, min(200, percent))
            self.zoomLabel.stringValue = "\(self.zoomPercent) %"
        }

        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        buildUI()
        loadRendererPage()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "preview")
    }

    private func buildUI() {
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        backButton.target = self; backButton.action = #selector(previousPage)
        forwardButton.target = self; forwardButton.action = #selector(nextPage)
        minusButton.target = self; minusButton.action = #selector(zoomOut)
        plusButton.target = self; plusButton.action = #selector(zoomIn)
        refreshButton.target = self; refreshButton.action = #selector(refreshPressed)
        printButton.target = self; printButton.action = #selector(printPressed)

        for b in [backButton, forwardButton, minusButton, plusButton] {
            b.bezelStyle = .rounded
            b.controlSize = .small
        }
        refreshButton.bezelStyle = .rounded
        refreshButton.controlSize = .small
        printButton.bezelStyle = .rounded
        printButton.controlSize = .small
        refreshButton.setContentHuggingPriority(.required, for: .horizontal)
        printButton.setContentHuggingPriority(.required, for: .horizontal)
        refreshButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        printButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        pageLabel.font = .systemFont(ofSize: 12, weight: .medium)
        zoomLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        toolbar.addArrangedSubview(backButton)
        toolbar.addArrangedSubview(pageLabel)
        toolbar.addArrangedSubview(forwardButton)
        toolbar.addArrangedSubview(minusButton)
        toolbar.addArrangedSubview(zoomLabel)
        toolbar.addArrangedSubview(plusButton)
        toolbar.addArrangedSubview(refreshButton)
        toolbar.addArrangedSubview(printButton)
        toolbar.setHuggingPriority(.defaultHigh, for: .vertical)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.setContentHuggingPriority(.defaultLow, for: .vertical)
        webView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(toolbar)
        addSubview(webView)
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            toolbar.topAnchor.constraint(equalTo: topAnchor, constant: 8),

            webView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 6),
            webView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -4),

            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            statusLabel.heightAnchor.constraint(equalToConstant: 16)
        ])

        updateControls()
    }

    /// Setzt neues MusicXML. Falls der Renderer noch lädt, wird es anschließend automatisch angezeigt.
    func setMusicXML(_ data: Data?) {
        pendingData = data
        currentPage = 1
        pageCount = 0
        updateControls()

        guard let data else {
            statusLabel.stringValue = "Keine Komposition für die Vorschau geladen."
            webView.evaluateJavaScript("clearScore()", completionHandler: nil)
            return
        }

        statusLabel.stringValue = ready ? "Notenbild wird aktualisiert …" : "Notensatzmodul wird geladen …"
        if ready { render(data: data, page: 1) }
    }

    private func loadRendererPage() {
        ready = false
        statusLabel.stringValue = "Notensatzmodul wird geladen …"
        webView.loadHTMLString(Self.html, baseURL: nil)
    }

    private func render(data: Data, page: Int) {
        let base64 = data.base64EncodedString()
        let js = "renderMusicXML('\(base64)', \(max(1, page)), 100)"
        webView.evaluateJavaScript(js) { [weak self] _, error in
            guard let self, let error else { return }
            self.statusLabel.stringValue = "Vorschaufehler: \(error.localizedDescription)"
        }
    }

    @objc private func previousPage() {
        guard currentPage > 1, let data = pendingData else { return }
        currentPage -= 1
        render(data: data, page: currentPage)
    }

    @objc private func nextPage() {
        guard currentPage < pageCount, let data = pendingData else { return }
        currentPage += 1
        render(data: data, page: currentPage)
    }

    @objc private func zoomOut() {
        zoomPercent = max(50, zoomPercent - 10)
        applyZoom()
    }

    @objc private func zoomIn() {
        zoomPercent = min(200, zoomPercent + 10)
        applyZoom()
    }

    private func applyZoom() {
        zoomLabel.stringValue = "\(zoomPercent) %"
        let center = NSPoint(x: webView.bounds.midX, y: webView.bounds.midY)
        webView.setMagnification(CGFloat(zoomPercent) / 100.0, centeredAt: center)
    }

    @objc private func refreshPressed() {
        onRefreshRequested?()
    }

    @objc private func printPressed() {
        guard !isPrinting, ready, let data = pendingData, pageCount > 0 else { return }
        isPrinting = true
        printButton.isEnabled = false
        statusLabel.stringValue = "Druckseiten werden vorbereitet …"

        let pageToRestore = currentPage
        let base64 = data.base64EncodedString()
        let merged = PDFDocument()

        func appendPage(_ pageNumber: Int) {
            let js = "renderMusicXML('\(base64)', \(pageNumber), 100); setPrintCleanMode(true);"
            webView.evaluateJavaScript(js) { [weak self] _, error in
                guard let self else { return }
                if let error {
                    self.finishPrintingWithError("Druckseite \(pageNumber) konnte nicht gerendert werden: \(error.localizedDescription)")
                    return
                }

                // Verovio/WebKit kurz Zeit geben, die einzelne Seite vollständig zu layouten.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    let config = WKPDFConfiguration()
                    self.webView.createPDF(configuration: config) { [weak self] result in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            switch result {
                            case .failure(let error):
                                self.finishPrintingWithError("PDF-Seite \(pageNumber) konnte nicht erzeugt werden: \(error.localizedDescription)")
                            case .success(let pdfData):
                                guard let onePagePDF = PDFDocument(data: pdfData),
                                      let firstPage = onePagePDF.page(at: 0) else {
                                    self.finishPrintingWithError("Die erzeugte Druckseite \(pageNumber) ist leer.")
                                    return
                                }

                                // Jede Verovio-Partiturseite wird genau eine PDF-Seite.
                                merged.insert(firstPage, at: merged.pageCount)

                                if pageNumber < self.pageCount {
                                    appendPage(pageNumber + 1)
                                } else {
                                    self.runPrintOperation(document: merged, restorePage: pageToRestore)
                                }
                            }
                        }
                    }
                }
            }
        }

        appendPage(1)
    }

    private func runPrintOperation(document: PDFDocument, restorePage: Int) {
        guard document.pageCount > 0 else {
            finishPrintingWithError("Es wurden keine Druckseiten erzeugt.")
            return
        }

        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.orientation = .portrait
        info.horizontalPagination = .fit
        info.verticalPagination = .fit
        info.leftMargin = 18
        info.rightMargin = 18
        info.topMargin = 18
        info.bottomMargin = 18

        guard let operation = document.printOperation(
            for: info,
            scalingMode: .pageScaleToFit,
            autoRotate: true
        ) else {
            finishPrintingWithError("Der macOS-Druckdialog konnte nicht vorbereitet werden.")
            return
        }

        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        _ = operation.run()

        webView.evaluateJavaScript("setPrintCleanMode(false)", completionHandler: nil)
        isPrinting = false
        printButton.isEnabled = true
        statusLabel.stringValue = "Vorschau aktuell."
        if let restoreData = pendingData {
            currentPage = max(1, min(restorePage, max(1, pageCount)))
            render(data: restoreData, page: currentPage)
        }
    }

    private func finishPrintingWithError(_ message: String) {
        webView.evaluateJavaScript("setPrintCleanMode(false)", completionHandler: nil)
        isPrinting = false
        printButton.isEnabled = true
        statusLabel.stringValue = message
    }

    private func updateControls() {
        pageLabel.stringValue = pageCount > 0 ? "Seite \(currentPage) / \(pageCount)" : "Seite – / –"
        backButton.isEnabled = pageCount > 0 && currentPage > 1
        forwardButton.isEnabled = pageCount > 0 && currentPage < pageCount
        printButton.isEnabled = ready && pendingData != nil && !isPrinting
        zoomLabel.stringValue = "\(zoomPercent) %"
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "preview", let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            ready = true
            statusLabel.stringValue = "Notensatzmodul bereit."
            applyZoom()
            if let data = pendingData { render(data: data, page: 1) }
        case "rendered":
            if let count = body["pageCount"] as? Int { pageCount = max(1, count) }
            else if let number = body["pageCount"] as? NSNumber { pageCount = max(1, number.intValue) }
            if let page = body["page"] as? Int { currentPage = max(1, min(page, pageCount)) }
            else if let number = body["page"] as? NSNumber { currentPage = max(1, min(number.intValue, pageCount)) }
            statusLabel.stringValue = "Vorschau aktuell."
            updateControls()
        case "error":
            let text = body["message"] as? String ?? "Unbekannter Fehler"
            statusLabel.stringValue = text
            ready = false
        default:
            break
        }
    }

    private static let html = #"""
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        html,body { margin:0; padding:0; background:#ececec; font-family:-apple-system,BlinkMacSystemFont,sans-serif; }
        #message { color:#666; text-align:center; padding:36px 12px; font-size:13px; }
        #page { margin:14px auto 30px auto; background:white; box-shadow:0 1px 5px rgba(0,0,0,.18); width:calc(100% - 28px); min-height:180px; overflow:visible; }
        #notation { width:100%; overflow:visible; }
        #notation svg { display:block; width:100%; height:auto; margin:0 auto; transform-origin:top center; }
        .print-page { background:white; margin:0 auto; break-after:page; page-break-after:always; }
        .print-page:last-child { break-after:auto; page-break-after:auto; }

        html.print-clean, html.print-clean body { background:white !important; }
        html.print-clean #page {
          margin:0 !important;
          padding:0 !important;
          width:100% !important;
          min-height:0 !important;
          background:white !important;
          box-shadow:none !important;
          border:none !important;
        }
        html.print-clean #notation {
          margin:0 !important;
          padding:0 !important;
          background:white !important;
        }

        @media print {
          @page { size:A4 portrait; margin:10mm; }
          html,body { background:white !important; }
          #message { display:none !important; }
          #page { margin:0; padding:0; width:auto; min-height:0; box-shadow:none; background:white; }
          #notation { width:100%; overflow:visible; }
          #notation svg { width:100% !important; max-width:none !important; height:auto !important; transform:none !important; }
          .print-page { width:100%; margin:0; padding:0; page-break-after:always; break-after:page; }
          .print-page:last-child { page-break-after:auto; break-after:auto; }
        }
      </style>
      <script>
        let toolkit = null;
        let zoom = 100;

        function post(obj) {
          try { window.webkit.messageHandlers.preview.postMessage(obj); } catch(e) {}
        }

        function clearScore() {
          document.getElementById('notation').innerHTML = '';
          document.getElementById('message').textContent = 'Keine Komposition geladen.';
        }

        function decodeBase64Utf8(b64) {
          const binary = atob(b64);
          const bytes = new Uint8Array(binary.length);
          for (let i=0; i<binary.length; i++) bytes[i] = binary.charCodeAt(i);
          return new TextDecoder('utf-8').decode(bytes);
        }

        function setPreviewZoom(percent) {
          zoom = percent || 100;
          const svg = document.querySelector('#notation svg');
          if (svg) {
            svg.style.width = zoom + '%';
            svg.style.maxWidth = 'none';
          }
        }

        function renderMusicXML(b64, requestedPage, requestedZoom) {
          if (!toolkit) {
            post({type:'error', message:'Notensatzmodul ist noch nicht bereit.'});
            return;
          }
          try {
            const xml = decodeBase64Utf8(b64);
            toolkit.setOptions({ pageWidth: 1800, pageHeight: 2450, scale: 32, footer: "none" });
            const ok = toolkit.loadData(xml);
            if (ok === false) throw new Error('MusicXML konnte nicht gelesen werden.');
            const count = Math.max(1, toolkit.getPageCount());
            const page = Math.max(1, Math.min(requestedPage || 1, count));
            const svg = toolkit.renderToSVG(page, false);
            if (!svg) throw new Error('Verovio hat kein Notenbild erzeugt.');
            document.getElementById('message').textContent = '';
            document.getElementById('notation').innerHTML = svg;
            setPreviewZoom(requestedZoom || 100);
            post({type:'rendered', page:page, pageCount:count});
          } catch(e) {
            document.getElementById('notation').innerHTML = '';
            document.getElementById('message').textContent = 'Vorschau konnte nicht erzeugt werden.';
            post({type:'error', message:'Vorschau konnte nicht erzeugt werden: ' + e.message});
          }
        }

        function setPrintCleanMode(enabled) {
          if (enabled) document.documentElement.classList.add('print-clean');
          else document.documentElement.classList.remove('print-clean');
        }

        function renderAllPagesForPrint(b64) {
          if (!toolkit) throw new Error('Notensatzmodul ist noch nicht bereit.');
          const xml = decodeBase64Utf8(b64);
          toolkit.setOptions({ pageWidth: 1800, pageHeight: 2450, scale: 32, footer: "none" });
          const ok = toolkit.loadData(xml);
          if (ok === false) throw new Error('MusicXML konnte nicht gelesen werden.');
          const count = Math.max(1, toolkit.getPageCount());
          let html = '';
          for (let p=1; p<=count; p++) {
            const svg = toolkit.renderToSVG(p, false);
            if (!svg) throw new Error('Seite ' + p + ' konnte nicht gerendert werden.');
            html += '<div class="print-page">' + svg + '</div>';
          }
          document.getElementById('message').textContent = '';
          document.getElementById('notation').innerHTML = html;
          return count;
        }

        function rendererReady() {
          try {
            toolkit = new verovio.toolkit();
            post({type:'ready'});
          } catch(e) {
            post({type:'error', message:'Verovio konnte nicht gestartet werden: ' + e.message});
          }
        }

        function loadRenderer() {
          const s = document.createElement('script');
          s.src = 'https://www.verovio.org/javascript/latest/verovio-toolkit-wasm.js';
          s.onload = function() {
            try {
              if (verovio.module.calledRun || verovio.module.runtimeInitialized) rendererReady();
              else verovio.module.onRuntimeInitialized = rendererReady;
            } catch(e) {
              post({type:'error', message:'Notensatzmodul konnte nicht initialisiert werden.'});
            }
          };
          s.onerror = function() {
            post({type:'error', message:'Notensatzmodul konnte nicht geladen werden. Internetverbindung prüfen.'});
          };
          document.head.appendChild(s);
        }
      </script>
    </head>
    <body onload="loadRenderer()">
      <div id="message">Notensatzmodul wird geladen …</div>
      <div id="page"><div id="notation"></div></div>
    </body>
    </html>
    """#
}


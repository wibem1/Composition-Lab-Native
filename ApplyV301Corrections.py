from pathlib import Path

# Composition Lab Native 3.0.1
# - composition ideas explicitly carry the current musical frame (bars, meter,
#   tempo, key, instrumentation) without becoming a bar-by-bar construction plan
# - remove redundant read-only impulse/status text below the editable idea
# - diagnostic export bypasses the repeatedly unreliable NSSavePanel and writes
#   atomically to ~/Downloads with a unique timestamped filename

m = Path('Sources/MainViewController.swift')
s = m.read_text(encoding='utf-8')

# 1) MusicChat concept instruction: musical frame is part of the idea.
old = '''        - compositionIdea ist ein musikalischer Gedanke/Impuls, kein technischer Bauplan: höchstens drei kurze Sätze, charakteristisch und offen genug für kompositorische Freiheit.\n'''
new = '''        - compositionIdea ist ein musikalischer Gedanke/Impuls, kein technischer Bauplan. Stelle die aktuellen Eckdaten knapp voran: Takte · Taktart · Tempo in BPM · Tonart · Besetzung. Danach höchstens drei kurze Sätze zur musikalischen Identität und Entwicklungsrichtung.\n        - Übernimm dafür die oben eingetragenen Rahmenbedingungen ausdrücklich; lasse Tempo oder Tonart nicht weg, wenn sie vorhanden sind.\n        - Vermeide unnötige taktgenaue Regieanweisungen wie einen fest vorgeschriebenen Höhepunkt in Takt 5, sofern der Nutzer das nicht ausdrücklich verlangt. Lass kompositorische Freiheit.\n'''
if old not in s:
    raise SystemExit('V3.0.1: MusicChat idea instruction anchor not found')
s = s.replace(old, new, 1)

# 2) Compose-button idea generation gets the same concise, useful format.
old = '''            Formuliere nur einen kurzen musikalischen Gedanken/Impuls in höchstens drei kurzen Sätzen.\n            Kein detaillierter Ablauf und kein technischer Bauplan. Noch keine Partitur erzeugen.\n'''
new = '''            Formuliere eine kurze, musikalisch brauchbare Kompositionsidee.\n            Stelle zuerst die aktuellen Eckdaten knapp voran: Takte · Taktart · Tempo in BPM · Tonart · Besetzung.\n            Übernimm die im Auftrag vorhandenen Werte ausdrücklich; Tempo und Tonart dürfen nicht fehlen, wenn sie angegeben sind.\n            Danach höchstens drei kurze Sätze zu musikalischer Identität, Material und Entwicklungsrichtung.\n            Kein detaillierter Takt-für-Takt-Ablauf und kein technischer Bauplan. Keine unnötig festgelegten Höhepunkte in bestimmten Takten, sofern der Nutzer das nicht verlangt. Noch keine Partitur erzeugen.\n'''
if old not in s:
    raise SystemExit('V3.0.1: compose idea instruction anchor not found')
s = s.replace(old, new, 1)

# 3) Remove the redundant lower-right status/impulse display from the V6.4 Main
# layout. The editable conceptView is the single authoritative composition idea.
# This is intentionally surgical: remove arranged subviews whose static label is
# "Notizen / musikalischer Impuls" plus the adjacent resultLabel block when V6.4
# created that duplicate panel. Keep resultLabel itself alive for internal status.
# ApplyV64Layout uses these exact snippets after all earlier patches.
for snippet in [
    '        ideaStack.addArrangedSubview(NSTextField(labelWithString: "Notizen / musikalischer Impuls"))\n',
    '        rightStack.addArrangedSubview(NSTextField(labelWithString: "Notizen / musikalischer Impuls"))\n'
]:
    s = s.replace(snippet, '')

# Hide resultLabel in Main if it is still added directly under the idea panel.
# Player/score state remains intact; only the duplicate prose block disappears.
for snippet in [
    '        ideaStack.addArrangedSubview(resultLabel)\n',
    '        rightStack.addArrangedSubview(resultLabel)\n'
]:
    s = s.replace(snippet, '')

# 4) Deterministic diagnostic export to Downloads. No NSSavePanel.
start = s.find('    @objc private func saveDiagnosticPressed() {\n')
end = s.find('    private func safeFilename(_ s:String)->String {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V3.0.1: saveDiagnosticPressed block not found')

save = r'''    @objc private func saveDiagnosticPressed() {
        guard let diagnostic = lastDiagnostic else {
            status("Noch keine Diagnosedaten vorhanden.", good: false)
            NSSound.beep()
            return
        }

        do {
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

'''
s = s[:start] + save + s[end:]

# Version diagnostic payloads produced by V3 core.
s = s.replace('"interfaceVersion": "3.0.0"', '"interfaceVersion": "3.0.1"')

m.write_text(s, encoding='utf-8')
print('Applied Composition Lab Native 3.0.1 corrections: useful idea frame, single idea editor, deterministic Downloads diagnostic export.')

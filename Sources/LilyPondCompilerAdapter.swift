import Foundation
import CryptoKit
import Darwin

struct NativeLilyPondOutput {
    let midi: Data
    let pages: [String]
    let log: String
}

/// macOS process adapter only. All source policy lives in CompositionCore.
/// A serial queue owns the cache. Compilation never blocks AppKit's main thread.
final class NativeLilyPondCompiler {
    private let queue = DispatchQueue(label: "CompositionLab.LilyPond", qos: .userInitiated)
    private let root: URL
    init(root: URL) { self.root = root }
    func compile(_ source: String, completion: @escaping (Result<NativeLilyPondOutput, Error>) -> Void) {
        queue.async { completion(Result { try self.compileSynchronously(source) }) }
    }
    private func compileSynchronously(_ source: String) throws -> NativeLilyPondOutput {
        let prepared = try LilyPondSource.prepare(source)
        let hash = SHA256.hash(data: Data(("2.26.0-point-and-click-v1\n" + prepared).utf8)).map { String(format: "%02x", $0) }.joined()
        let final = root.appendingPathComponent(hash, isDirectory: true)
        let fm = FileManager.default
        if fm.fileExists(atPath: final.appendingPathComponent("complete").path) { return try read(final) }
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        guard let resource = Bundle.main.resourceURL else { throw APIError.badResponse("App-Ressourcen fehlen.") }
        let executable = resource.appendingPathComponent("LilyPond-" + architecture + "/bin/lilypond")
        guard fm.isExecutableFile(atPath: executable.path) else { throw APIError.badResponse("Der mitgelieferte LilyPond-Notensatz fehlt. Bitte die vollständige App verwenden.") }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let work = root.appendingPathComponent(".work-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        try Data(prepared.utf8).write(to: work.appendingPathComponent("source.ly"))
        let logURL = work.appendingPathComponent("compile.log")
        fm.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }
        let process = Process()
        process.executableURL = executable; process.currentDirectoryURL = work
        process.arguments = ["--svg", "-dpoint-and-click", "--loglevel=WARNING", "--output=score", "source.ly"]
        // Log to a file, so a full pipe cannot deadlock a long engraving job.
        process.standardOutput = log; process.standardError = log
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        try process.run()
        if done.wait(timeout: .now() + 120) == .timedOut {
            process.terminate()
            if done.wait(timeout: .now() + 2) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            throw APIError.badResponse("Zeitlimit des lokalen Notensatzes erreicht. Die letzte gültige Fassung bleibt erhalten.")
        }
        guard process.terminationStatus == 0 else {
            let message = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            throw APIError.badResponse("LilyPond konnte die Originalkomposition nicht setzen.\n" + String(message.prefix(5000)))
        }
        let result = try read(work)
        try Data("2.26.0".utf8).write(to: work.appendingPathComponent("complete"))
        if fm.fileExists(atPath: final.path) { try fm.removeItem(at: final) }
        try fm.moveItem(at: work, to: final)
        return result
    }
    private func read(_ directory: URL) throws -> NativeLilyPondOutput {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let midis = files.filter { ["mid", "midi"].contains($0.pathExtension) }
        guard midis.count == 1 else { throw APIError.badResponse("LilyPond muss genau eine vollständige MIDI-Datei erzeugen.") }
        let midi = try Data(contentsOf: midis[0])
        guard midi.count >= 14, String(data: midi.prefix(4), encoding: .ascii) == "MThd" else { throw APIError.badResponse("LilyPond hat kein gültiges MIDI erzeugt.") }
        let pages = try files.filter { $0.pathExtension == "svg" }.sorted {
            $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedAscending
        }.map { try String(contentsOf: $0, encoding: .utf8) }
        guard !pages.isEmpty, pages.allSatisfy({ $0.contains("<svg") }) else { throw APIError.badResponse("LilyPond hat keine vollständige Notenausgabe erzeugt.") }
        return NativeLilyPondOutput(midi: midi, pages: pages, log: try String(contentsOf: directory.appendingPathComponent("compile.log"), encoding: .utf8))
    }
}

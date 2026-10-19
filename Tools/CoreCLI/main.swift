import Foundation
import CompositionCore

// File conversion harness, not the Windows graphical application.
do {
    let args = Array(CommandLine.arguments.dropFirst())
    if args == ["service"] {
        // All service operations use the same error envelope. A validation
        // failure is a structured domain error, not a crashed runtime.
        do { try BridgeService.run() }
        catch { BridgeService.send(["ok": false, "error": error.localizedDescription]) }
    } else if args == ["--version"] {
        print("Composition Lab Core \(CoreServices.version)")
    } else if args.count == 3 {
        let input = URL(fileURLWithPath: args[1])
        let output = URL(fileURLWithPath: args[2])
        guard input.standardizedFileURL != output.standardizedFileURL else {
            throw NSError(domain: "CoreCLI", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Ein- und Ausgabedatei müssen verschieden sein."])
        }
        let data = try Data(contentsOf: input)
        let result: Data
        switch args[0] {
        case "score-to-midi": result = try CoreServices.midi(scoreJSON: data)
        case "score-to-musicxml": result = try CoreServices.musicXML(scoreJSON: data)
        case "midi-to-score": result = try CoreServices.importMIDI(data, title: input.deletingPathExtension().lastPathComponent)
        case "musicxml-to-score": result = try CoreServices.importMusicXML(data, title: input.deletingPathExtension().lastPathComponent)
        default: throw NSError(domain: "CoreCLI", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Unbekannter Befehl."])
        }
        // Explicitly refuse to overwrite an existing user's file.
        try result.write(to: output, options: .withoutOverwriting)
        print(output.path)
    } else {
        throw NSError(domain: "CoreCLI", code: 3, userInfo: [NSLocalizedDescriptionKey:
            "Aufruf: composition-lab-core --version | <score-to-midi|score-to-musicxml|midi-to-score|musicxml-to-score> <Eingabe> <neue Ausgabe>"])
    }
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}

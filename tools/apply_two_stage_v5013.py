from pathlib import Path
p=Path('Sources/Models.swift'); s=p.read_text(); s=s.replace('static let engineBuild = 14','static let engineBuild = 15')
a=s.index('    static func conceptPrompt(_ assignment: String) -> String {'); b=s.index('\n    static let technical =',a)
new='''    static func conceptPrompt(_ assignment: String) -> String {
        """
        Komponiere das verlangte Stück musikalisch frei und eigenständig. Konzentriere dich ausschließlich auf musikalische Gestalt, Verlauf, Stimmen, Rhythmus, Harmonik, Artikulation und Charakter. Denke noch NICHT an MIDI-Codierung, Beat-Werte, JSON oder ein technisches Ausgabeformat.

        AUFTRAG:
        \\(assignment)

        Schreibe einen vollständigen, konkret ausnotierbaren musikalischen Entwurf, aus dem anschließend eine andere technische Instanz die MIDI-Daten erzeugen kann. Gib in der ersten Zeile lediglich einen kurzen passenden Werktitel als „Titel: …“ an. Mache keine Erläuterung über deine Arbeitsweise.
        """
    }

    static let translationRule = """
    Du bist jetzt ausschließlich Notations- und MIDI-Übersetzer. Übertrage den bereits fertigen musikalischen Entwurf so vollständig und werkgetreu wie möglich in das nachfolgend verlangte JSON-Format. Komponiere NICHT neu, vereinfache NICHT, regularisiere NICHT den Rhythmus und ersetze keine ungewöhnlichen musikalischen Entscheidungen durch Standards. Bewahre insbesondere rhythmische Vielfalt, Pausen, Stimmführung, Phrasierung, Artikulation und Dynamik des Entwurfs.
    """
'''
p.write_text(s[:a]+new+s[b:])
p=Path('Sources/MainViewController.swift'); s=p.read_text()
s=s.replace('\\(ComposerPrompts.technical)\n\n                AUFTRAG:\n                \\(prompt)\n\n                DEIN KONZEPT:', '\\(ComposerPrompts.translationRule)\n\n                \\(ComposerPrompts.technical)\n\n                URSPRÜNGLICHER AUFTRAG:\n                \\(prompt)\n\n                FERTIGER MUSIKALISCHER ENTWURF:')
s=s.replace('\\(ComposerPrompts.technical)\n\n                AUFTRAG:\n                \\(assignment)\n\n                DEIN KONZEPT:', '\\(ComposerPrompts.translationRule)\n\n                \\(ComposerPrompts.technical)\n\n                URSPRÜNGLICHER AUFTRAG:\n                \\(assignment)\n\n                FERTIGER MUSIKALISCHER ENTWURF:')
s=s.replace('view.window?.title = "Composition Lab · Projekt: \\(projectName) · V5.0.12"','view.window?.title = "Composition Lab · Projekt: \\(projectName) · V5.0.13"')
s=s.replace('"engineBuild": ComposerPrompts.engineBuild,','"engineBuild": ComposerPrompts.engineBuild,\n                                    "compositionArchitecture": "two-stage-free-draft-then-faithful-translation",')
p.write_text(s)

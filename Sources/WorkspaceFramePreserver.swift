import Cocoa

/// Sicherheitsversion: Der frühere Runtime-Hook (Method Swizzling) wurde entfernt,
/// weil er beim Wechsel auf den Notensatz zu einem Absturz führen konnte.
///
/// Die Methode bleibt absichtlich als No-op bestehen, damit AppDelegate.swift
/// unverändert kompilieren kann. Die Fenstergrößen-Korrektur wird später direkt
/// und ohne Runtime-Manipulation im MainViewController umgesetzt.
enum WorkspaceFramePreserver {
    @MainActor
    static func install() {
        // Absichtlich leer.
    }
}

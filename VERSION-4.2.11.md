# Composition Lab Native 4.2.11 — Issue #10

Common version for native AppKit/WebKit on Mac and WinForms/WebView2 on Windows; shared musical engine retained.

- Octave repair persists corrected LilyPond source together with MIDI/score, while preserving the original and validating octave-only changes.
- Drag selection captures real pointers, accepts exact SVG targets, handles movement/release on the document, and tolerates synthetic events without an active pointer.
- Native Mac regression now selects the complete visible passage and hands the source span to the editor. Windows additionally exercises trusted Chromium mouse input and records its geometry and result.
- Both platforms restore window size and position; Mac clamps disconnected-monitor coordinates to the active screen and rejects non-finite origins.

Publication requires successful shared and native jobs for the exact release commit. CI evidence is recorded in Issue #10. No user test is substituted for this gate.

Native regression reports are supplied as `Native-Test-Results.zip`. Mac tests exercise the real AppKit/WebKit application offline, including a synthetic three-bar pointer sequence. Windows tests additionally inject trusted Chromium mouse input; both the original build and the extracted package must pass. Provider calls in octave repair tests are controlled offline responses, with the real engraver, shared validation, score and source persistence.

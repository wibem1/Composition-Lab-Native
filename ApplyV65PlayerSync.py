from pathlib import Path
p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Ensure the compact Main tempo field remains interactive after the V6 layout replacement.
old = '''        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))\n        playerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true\n        row.addArrangedSubview(playerTempoField)\n        playerVolume.widthAnchor.constraint(equalToConstant: 90).isActive = true\n'''
new = '''        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))\n        playerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true\n        playerTempoField.target = self\n        playerTempoField.action = #selector(playerTempoChanged)\n        row.addArrangedSubview(playerTempoField)\n        playerVolume.widthAnchor.constraint(equalToConstant: 90).isActive = true\n        playerVolume.target = self\n        playerVolume.action = #selector(playerVolumeChanged)\n'''
if old in s:
    s = s.replace(old, new, 1)
elif 'playerTempoField.action = #selector(playerTempoChanged)' not in s:
    raise SystemExit('V6.5 player sync: Main tempo marker not found')

old = '''    @objc private func playerLoopChanged() {\n        let active = (playerLoopButton.state == .on)\n        midiPlayer.loopEnabled = active\n        playerLoopButton.title = active ? "↻ Loop AN" : "↻ Loop"\n        playerLoopButton.contentTintColor = active ? .systemGreen : nil\n    }\n'''
new = '''    @objc private func playerLoopChanged() {\n        let active = (playerLoopButton.state == .on)\n        midiPlayer.loopEnabled = active\n        playerLoopButton.title = active ? "↻ Loop AN" : "↻ Loop"\n        playerLoopButton.contentTintColor = active ? .systemGreen : nil\n        notationPlayerLoopButton.state = playerLoopButton.state\n        notationPlayerLoopButton.title = playerLoopButton.title\n        notationPlayerLoopButton.contentTintColor = playerLoopButton.contentTintColor\n    }\n'''
if old in s:
    s = s.replace(old, new, 1)

old = '''    @objc private func playerTempoChanged() {\n        reloadMainPlayerForPlaybackSettings(errorPrefix: "Player-Tempo konnte nicht geändert werden")\n    }\n\n    @objc private func playerVolumeChanged() {\n        reloadMainPlayerForPlaybackSettings(errorPrefix: "Player-Lautstärke konnte nicht geändert werden")\n'''
new = '''    @objc private func playerTempoChanged() {\n        notationPlayerTempoField.stringValue = playerTempoField.stringValue\n        reloadMainPlayerForPlaybackSettings(errorPrefix: "Player-Tempo konnte nicht geändert werden")\n    }\n\n    @objc private func playerVolumeChanged() {\n        notationPlayerVolume.doubleValue = playerVolume.doubleValue\n        reloadMainPlayerForPlaybackSettings(errorPrefix: "Player-Lautstärke konnte nicht geändert werden")\n'''
if old in s:
    s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.5 Main/Noten player synchronization.')

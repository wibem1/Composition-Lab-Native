from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Main player: V6.5.1 rebuilt the bottom bar after the player-sync patch,
# so restore an explicit, labelled and wired volume control there.
old = '''        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        playerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        row.addArrangedSubview(playerTempoField)
        playerVolume.widthAnchor.constraint(equalToConstant: 90).isActive = true
        row.addArrangedSubview(playerVolume)
'''
new = '''        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        playerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        playerTempoField.target = self
        playerTempoField.action = #selector(playerTempoChanged)
        row.addArrangedSubview(playerTempoField)

        row.addArrangedSubview(NSTextField(labelWithString: "Lautstärke"))
        playerVolume.widthAnchor.constraint(equalToConstant: 120).isActive = true
        playerVolume.target = self
        playerVolume.action = #selector(playerVolumeChanged)
        playerVolume.isContinuous = true
        row.addArrangedSubview(playerVolume)
'''
if old not in s:
    raise SystemExit('V6.5.2: Main volume-control marker not found')
s = s.replace(old, new, 1)

# Notation player: make the already mirrored slider unmistakably visible and
# give it the same width/label as Main.
old = '''        notationPlayerVolume.doubleValue = playerVolume.doubleValue
        notationPlayerVolume.widthAnchor.constraint(equalToConstant: 90).isActive = true
        notationPlayerVolume.target = self
        notationPlayerVolume.action = #selector(v65NotationVolumeChanged)
        row.addArrangedSubview(notationPlayerVolume)
'''
new = '''        row.addArrangedSubview(NSTextField(labelWithString: "Lautstärke"))
        notationPlayerVolume.doubleValue = playerVolume.doubleValue
        notationPlayerVolume.widthAnchor.constraint(equalToConstant: 120).isActive = true
        notationPlayerVolume.target = self
        notationPlayerVolume.action = #selector(v65NotationVolumeChanged)
        notationPlayerVolume.isContinuous = true
        row.addArrangedSubview(notationPlayerVolume)
'''
if old not in s:
    raise SystemExit('V6.5.2: Noten volume-control marker not found')
s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.5.2: visible, labelled and functional volume sliders on Main and Noten.')

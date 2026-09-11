from pathlib import Path

# Composition Lab Native 3.0.4
# One authoritative musical text state on Main: the editable composition idea.
# Remove the redundant "Notizen / musikalischer Impuls" block and let the idea
# editor use the freed vertical space.

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Remove the old fixed 140 pt idea editor height and replace it with a flexible,
# much larger editor. Keep it scrollable and vertically stretchable.
old_variants = [
    'conceptView.isEditable = true; conceptView.isSelectable = true; conceptView.font = .systemFont(ofSize: 13); let ideaScroll = textScroll(conceptView, minHeight: 120); ideaScroll.heightAnchor.constraint(equalToConstant: 140).isActive = true; isv.addArrangedSubview(ideaScroll); ideaScroll.widthAnchor.constraint(equalTo: isv.widthAnchor).isActive = true\n',
    'conceptView.isEditable = false; conceptView.isSelectable = true; conceptView.font = .systemFont(ofSize: 13); let ideaScroll = textScroll(conceptView, minHeight: 120); ideaScroll.heightAnchor.constraint(equalToConstant: 140).isActive = true; isv.addArrangedSubview(ideaScroll); ideaScroll.widthAnchor.constraint(equalTo: isv.widthAnchor).isActive = true\n'
]
new_editor = '''conceptView.isEditable = true; conceptView.isSelectable = true; conceptView.font = .systemFont(ofSize: 13); let ideaScroll = textScroll(conceptView, minHeight: 260); ideaScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 285).isActive = true; ideaScroll.setContentHuggingPriority(.defaultLow, for: .vertical); ideaScroll.setContentCompressionResistancePriority(.defaultLow, for: .vertical); isv.addArrangedSubview(ideaScroll); ideaScroll.widthAnchor.constraint(equalTo: isv.widthAnchor).isActive = true\n'''
replaced = False
for old in old_variants:
    if old in s:
        s = s.replace(old, new_editor, 1)
        replaced = True
        break
if not replaced:
    raise SystemExit('V3.0.4: idea editor layout anchor not found')

# Remove the complete redundant lower block from the old V6.4 layout.
old_block = '''        let noteLabel = NSTextField(labelWithString: "Notizen / musikalischer Impuls"); noteLabel.textColor = .secondaryLabelColor; isv.addArrangedSubview(noteLabel); resultLabel.maximumNumberOfLines = 5; resultLabel.lineBreakMode = .byWordWrapping; resultLabel.font = .systemFont(ofSize: 12); isv.addArrangedSubview(resultLabel); resultLabel.widthAnchor.constraint(equalTo: isv.widthAnchor).isActive = true\n'''
if old_block not in s:
    raise SystemExit('V3.0.4: redundant impulse block not found')
s = s.replace(old_block, '', 1)

# The idea panel should actively use the same vertical area as MusicChat.
anchor = '        row.addArrangedSubview(chat); row.addArrangedSubview(idea); chat.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.66, constant: -7).isActive = true; idea.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.34, constant: -7).isActive = true; chat.heightAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true; idea.heightAnchor.constraint(equalTo: chat.heightAnchor).isActive = true\n'
if anchor not in s:
    raise SystemExit('V3.0.4: work area height anchor not found')
# Existing equal-height constraint is already correct; leave it intact.

p.write_text(s, encoding='utf-8')
print('Applied 3.0.4: removed redundant impulse field and enlarged the editable composition idea.')

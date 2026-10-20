using System.Runtime.InteropServices;

namespace CompositionLab;

internal sealed partial class MainForm
{
    Task ShowMidiOutput()
    {
        using var dialog = new Form { Text = "MIDI-Ausgabe", Width = 480, Height = 210, StartPosition = FormStartPosition.CenterParent, FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false };
        var label = new Label { Text = "System-Synthesizer oder direkten MIDI-Ausgang wählen:", Dock = DockStyle.Top, Height = 38, Padding = new Padding(10) };
        var output = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Dock = DockStyle.Top };
        output.Items.Add("Windows-Standardausgang");
        var devices = MidiPlayer.OutputDevices();
        foreach (string device in devices) output.Items.Add(device);
        output.SelectedIndex = Math.Clamp(player.OutputDevice + 1, 0, output.Items.Count - 1);
        var accept = new Button { Text = "Übernehmen", Dock = DockStyle.Bottom, Height = 36, DialogResult = DialogResult.OK };
        dialog.Controls.Add(output); dialog.Controls.Add(label); dialog.Controls.Add(accept); dialog.AcceptButton = accept;
        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            int previous = player.OutputDevice;
            try
            {
                player.Close(); player.OutputDevice = output.SelectedIndex - 1;
                SaveLocalState(); SetStatus("MIDI-Ausgabe: " + output.Text);
            }
            catch { player.OutputDevice = previous; throw; }
        }
        return Task.CompletedTask;
    }
}

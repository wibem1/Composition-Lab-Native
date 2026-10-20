using System.Runtime.InteropServices;
using System.Text;

namespace CompositionLab;

internal sealed class MidiPlayer : IDisposable
{
    readonly string alias = "clab" + Guid.NewGuid().ToString("N");
    string? file;
    public bool Loaded => file != null;
    public int OutputDevice { get; set; } = -1;
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct MidiOutCaps
    {
        public ushort manufacturer, product;
        public uint version;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string name;
        public ushort technology, voices, notes, channelMask;
        public uint support;
    }
    [DllImport("winmm.dll")] static extern uint midiOutGetNumDevs();
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)] static extern uint midiOutGetDevCaps(UIntPtr device, out MidiOutCaps caps, uint size);
    public static string[] OutputDevices()
    {
        var names = new List<string>();
        for (uint i = 0; i < midiOutGetNumDevs(); i++)
        {
            uint error = midiOutGetDevCaps((UIntPtr)i, out var caps, (uint)Marshal.SizeOf<MidiOutCaps>());
            names.Add(error == 0 ? caps.name : "MIDI-Ausgang " + (i + 1));
        }
        return names.ToArray();
    }
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    static extern uint mciSendString(string command, StringBuilder? result, int size, IntPtr callback);
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    static extern bool mciGetErrorString(uint error, StringBuilder text, int size);
    string Send(string command)
    {
        var output = new StringBuilder(512);
        var error = mciSendString(command, output, output.Capacity, IntPtr.Zero);
        if (error != 0)
        {
            var message = new StringBuilder(512); mciGetErrorString(error, message, message.Capacity);
            throw new InvalidOperationException("MIDI-Wiedergabe: " + message);
        }
        return output.ToString();
    }
    public void Load(byte[] data)
    {
        Close();
        var path = Path.Combine(Path.GetTempPath(), "clab-v4-" + Guid.NewGuid().ToString("N") + ".mid");
        File.WriteAllBytes(path, data);
        try
        {
            Send($"open \"{path}\" type sequencer alias {alias}");
            file = path;
            Send($"set {alias} time format milliseconds");
            if (OutputDevice >= 0) Send($"set {alias} port {OutputDevice}");
        }
        catch { mciSendString($"close {alias}", null, 0, IntPtr.Zero); File.Delete(path); file = null; throw; }
    }
    public string Mode => Loaded ? Send($"status {alias} mode") : "stopped";
    public void Seek(double fraction) { if (Loaded) { bool playing = Mode == "playing"; int position = (int)(Length * Math.Clamp(fraction, 0, 1)); Send($"seek {alias} to {position}"); if (playing) Send($"play {alias} from {position}"); } }
    public void Play() { if (Loaded) Send($"play {alias}"); }
    public void Pause() { if (Loaded) Send($"pause {alias}"); }
    public void Stop() { if (Loaded) { Send($"stop {alias}"); Send($"seek {alias} to start"); } }
    public int Position => Loaded && int.TryParse(Send($"status {alias} position"), out int n) ? n : 0;
    public int Length => Loaded && int.TryParse(Send($"status {alias} length"), out int n) ? n : 0;
    public void Close()
    {
        if (file == null) return;
        mciSendString($"close {alias}", null, 0, IntPtr.Zero);
        try { File.Delete(file); } catch (IOException) { }
        file = null;
    }
    public void Dispose() => Close();
}

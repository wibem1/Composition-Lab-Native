using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;

namespace CompositionLab;

internal sealed class SecretStore
{
    readonly string path;
    public SecretStore(string directory) { path = Path.Combine(directory, "keys.dpapi"); }
    public Dictionary<string, string> Load()
    {
        if (!File.Exists(path)) return [];
        var plain = Transform(File.ReadAllBytes(path), protect: false);
        try { return JsonSerializer.Deserialize<Dictionary<string, string>>(plain) ?? []; }
        finally { Array.Clear(plain); }
    }
    public void Save(Dictionary<string, string> keys)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var plain = JsonSerializer.SerializeToUtf8Bytes(keys);
        try { AtomicFile.WriteBytes(path, Transform(plain, protect: true)); }
        finally { Array.Clear(plain); }
    }
    [StructLayout(LayoutKind.Sequential)] struct Blob { public int Length; public IntPtr Data; }
    [DllImport("crypt32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CryptProtectData(ref Blob input, string? description, IntPtr entropy,
        IntPtr reserved, IntPtr prompt, int flags, out Blob output);
    [DllImport("crypt32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CryptUnprotectData(ref Blob input, IntPtr description, IntPtr entropy,
        IntPtr reserved, IntPtr prompt, int flags, out Blob output);
    [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr pointer);
    static byte[] Transform(byte[] bytes, bool protect)
    {
        var input = new Blob { Length = bytes.Length, Data = Marshal.AllocHGlobal(bytes.Length) };
        Blob output = default;
        try
        {
            Marshal.Copy(bytes, 0, input.Data, bytes.Length);
            bool ok = protect ? CryptProtectData(ref input, "Composition Lab 4.0", IntPtr.Zero,
                        IntPtr.Zero, IntPtr.Zero, 1, out output)
                : CryptUnprotectData(ref input, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, 1, out output);
            if (!ok) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            var result = new byte[output.Length];
            Marshal.Copy(output.Data, result, 0, output.Length);
            return result;
        }
        finally
        {
            for (int i = 0; i < input.Length; i++) Marshal.WriteByte(input.Data, i, 0);
            Marshal.FreeHGlobal(input.Data);
            if (output.Data != IntPtr.Zero) LocalFree(output.Data);
        }
    }
}

internal static class AtomicFile
{
    public static void WriteBytes(string path, byte[] bytes)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        var temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try { File.WriteAllBytes(temp, bytes); File.Move(temp, path, overwrite: true); }
        finally { if (File.Exists(temp)) File.Delete(temp); }
    }
    public static void WriteText(string path, string text) => WriteBytes(path, Encoding.UTF8.GetBytes(text));
}

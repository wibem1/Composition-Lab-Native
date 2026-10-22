using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed partial class MainForm
{
    bool windowPlacementRestored;
    string PlacementFile => Path.Combine(dataDirectory, "window-placement.json");

    void RestoreWindowPlacement(bool isolatedTest = false)
    {
        if ((testMode && !isolatedTest) || !File.Exists(PlacementFile)) return;
        try
        {
            var state = JsonNode.Parse(File.ReadAllText(PlacementFile))?.AsObject();
            if (state is null) return;
            int x = state["x"]?.GetValue<int>() ?? 0;
            int y = state["y"]?.GetValue<int>() ?? 0;
            int w = state["width"]?.GetValue<int>() ?? 0;
            int h = state["height"]?.GetValue<int>() ?? 0;
            if (w < 640 || h < 480 || w > 16000 || h > 16000) return;
            var saved = new Rectangle(x, y, w, h);
            var screen = Screen.AllScreens.FirstOrDefault(s => Rectangle.Intersect(s.WorkingArea, saved).Width >= 60 &&
                Rectangle.Intersect(s.WorkingArea, saved).Height >= 40);
            if (screen is null) return; // disconnected monitor: use centered initial window
            var a = screen.WorkingArea;
            w = Math.Min(w, a.Width);
            h = Math.Min(h, a.Height);
            MinimumSize = new Size(Math.Min(MinimumSize.Width, a.Width), Math.Min(MinimumSize.Height, a.Height));
            StartPosition = FormStartPosition.Manual;
            Bounds = new Rectangle(Math.Clamp(x, a.Left, a.Right - w), Math.Clamp(y, a.Top, a.Bottom - h), w, h);
            windowPlacementRestored = true;
            if (state["maximized"]?.GetValue<bool>() == true) WindowState = FormWindowState.Maximized;
        }
        catch
        {
            // Invalid state must never prevent launching the program.
        }
    }

    void SaveWindowPlacement(bool isolatedTest = false)
    {
        if ((testMode && !isolatedTest) || WindowState == FormWindowState.Minimized) return;
        var rect = WindowState == FormWindowState.Normal ? Bounds : RestoreBounds;
        if (rect.Width < 640 || rect.Height < 480) return;
        var state = new JsonObject {
            ["x"] = rect.X, ["y"] = rect.Y, ["width"] = rect.Width, ["height"] = rect.Height,
            ["maximized"] = WindowState == FormWindowState.Maximized
        };
        try { AtomicFile.WriteText(PlacementFile, state.ToJsonString()); }
        catch (Exception e) { SetStatus("Fensterposition konnte nicht gespeichert werden: " + e.Message, true); }
    }
    void TestWindowPlacement(string output)
    {
        if (!testMode) throw new InvalidOperationException("Window test requires isolated storage.");
        var original = Bounds;
        var area = Screen.FromControl(this).WorkingArea;
        try {
            Bounds = new Rectangle(area.Left+10,area.Top+10,Math.Min(1000,area.Width-20),Math.Min(720,area.Height-20));
            SaveWindowPlacement(isolatedTest:true);
            var expected = Bounds;
            Bounds = new Rectangle(area.Left+25,area.Top+25,expected.Width,expected.Height);
            RestoreWindowPlacement(isolatedTest:true);
            if(Bounds!=expected)throw new Exception("Saved window geometry was not restored.");
            string saved=File.ReadAllText(PlacementFile);
            WindowState=FormWindowState.Minimized;
            SaveWindowPlacement(isolatedTest:true);
            if(File.ReadAllText(PlacementFile)!=saved)throw new Exception("Minimized window overwrites normal geometry.");
            WindowState=FormWindowState.Normal;
            File.WriteAllText(PlacementFile,"invalid json");
            RestoreWindowPlacement(isolatedTest:true); // corrupt settings cannot block startup
            File.WriteAllText(Path.Combine(output,"Window-Placement.json"),new JsonObject {
                ["passed"]=true,["roundtrip"]=true,["minimizedPreservesNormal"]=true,["corruptStateTolerated"]=true
            }.ToJsonString());
        } finally { WindowState=FormWindowState.Normal; Bounds=original; }
    }

}

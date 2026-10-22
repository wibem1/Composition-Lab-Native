using System.Text.Json.Nodes;

namespace CompositionLab;

internal sealed partial class MainForm
{
    bool windowPlacementRestored;
    string PlacementFile => Path.Combine(dataDirectory, "window-placement.json");

    void RestoreWindowPlacement()
    {
        if (testMode || !File.Exists(PlacementFile)) return;
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

    void SaveWindowPlacement()
    {
        if (testMode || WindowState == FormWindowState.Minimized) return;
        var rect = WindowState == FormWindowState.Normal ? Bounds : RestoreBounds;
        if (rect.Width < 640 || rect.Height < 480) return;
        var state = new JsonObject {
            ["x"] = rect.X, ["y"] = rect.Y, ["width"] = rect.Width, ["height"] = rect.Height,
            ["maximized"] = WindowState == FormWindowState.Maximized
        };
        try { AtomicFile.WriteText(PlacementFile, state.ToJsonString()); }
        catch (Exception e) { SetStatus("Fensterposition konnte nicht gespeichert werden: " + e.Message, true); }
    }
}

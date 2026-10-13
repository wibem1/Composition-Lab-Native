using System.Drawing.Drawing2D;

namespace CompositionLab;

internal static class StudioTheme
{
    public static readonly Color Canvas = Color.FromArgb(239, 243, 245);
    public static readonly Color Ink = Color.FromArgb(29, 45, 58);
    public static readonly Color Muted = Color.FromArgb(96, 113, 126);
    public static readonly Color Navy = Color.FromArgb(25, 43, 57);
    public static readonly Color Accent = Color.FromArgb(17, 112, 115);
    public static readonly Color AccentSoft = Color.FromArgb(228, 243, 241);
    public static readonly Color Line = Color.FromArgb(215, 225, 230);
    public static Color Behind(Control control)
    { for (Control? parent = control.Parent; parent != null; parent = parent.Parent) if (parent.BackColor.A == 255) return parent.BackColor; return Canvas; }
    public static GraphicsPath Round(RectangleF r, float radius)
    {
        var path = new GraphicsPath(); float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
        if (d <= 0) return path;
        path.AddArc(r.X, r.Y, d, d, 180, 90); path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure(); return path;
    }
}

// Keep the visual vocabulary in one Windows adapter; core and documents are unchanged.
internal sealed class StudioSurface : Panel
{
    public StudioSurface()
    { DoubleBuffered = true; BackColor = Color.White; Padding = new Padding(14); ResizeRedraw = true; }
    protected override void OnPaintBackground(PaintEventArgs e)
    {
        e.Graphics.Clear(StudioTheme.Behind(this)); e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using var path = StudioTheme.Round(new RectangleF(0, 0, Width, Height), 10 * DeviceDpi / 96f);
        using var brush = new SolidBrush(BackColor); e.Graphics.FillPath(brush, path);
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e); e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using var outline = StudioTheme.Round(new RectangleF(0.5f, 0.5f, Width - 1, Height - 1), 10 * DeviceDpi / 96f);
        using var pen = new Pen(StudioTheme.Line); e.Graphics.DrawPath(pen, outline);
    }
}

internal class StudioButton : Button
{
    bool hover;
    public bool Primary { get; set; }
    public bool Selected { get; set; }
    public StudioButton()
    {
        FlatStyle = FlatStyle.Flat; FlatAppearance.BorderSize = 0; UseVisualStyleBackColor = false;
        Padding = new Padding(10, 3, 10, 3); Margin = new Padding(3); AutoSize = true;
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    }
    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnPaint(PaintEventArgs e)
    {
        if (SystemInformation.HighContrast) { base.OnPaint(e); return; }
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        e.Graphics.Clear(StudioTheme.Behind(this));
        Color fill = !Enabled ? StudioTheme.Canvas : Primary ? StudioTheme.Accent : Selected ? StudioTheme.AccentSoft : hover ? Color.FromArgb(243, 247, 248) : Color.White;
        using var path = StudioTheme.Round(new RectangleF(0.5f, 0.5f, Width - 1, Height - 1), 7 * DeviceDpi / 96f);
        using var brush = new SolidBrush(fill); e.Graphics.FillPath(brush, path);
        using var border = new Pen(Selected || Focused ? StudioTheme.Accent : Primary ? fill : StudioTheme.Line); e.Graphics.DrawPath(border, path);
        var color = !Enabled ? StudioTheme.Muted : Primary ? Color.White : Selected ? StudioTheme.Accent : StudioTheme.Ink;
        TextRenderer.DrawText(e.Graphics, Text, Font, ClientRectangle, color, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        if (Focused && ShowFocusCues) ControlPaint.DrawFocusRectangle(e.Graphics, Rectangle.Inflate(ClientRectangle, -5, -5), color, fill);
    }
}

internal sealed class PieceCard : StudioButton
{
    public int Number { get; init; }
    public string PieceTitle { get; set; } = "Freier Platz";
    public bool Occupied { get; set; }
    protected override void OnPaint(PaintEventArgs e)
    {
        if (SystemInformation.HighContrast) { base.OnPaint(e); return; }
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        e.Graphics.Clear(StudioTheme.Behind(this));
        float scale = DeviceDpi / 96f;
        using var path = StudioTheme.Round(new RectangleF(0.5f, 0.5f, Width - 1, Height - 1), 8 * scale);
        Color fill = Selected ? StudioTheme.AccentSoft : Color.FromArgb(248, 250, 251);
        using var brush = new SolidBrush(fill); e.Graphics.FillPath(brush, path);
        using var border = new Pen(Selected || Focused ? StudioTheme.Accent : StudioTheme.Line, Selected ? 2 : 1); e.Graphics.DrawPath(border, path);
        int pad = (int)(8 * scale), badge = (int)(21 * scale);
        using var badgeBrush = new SolidBrush(Selected ? StudioTheme.Accent : Color.FromArgb(226, 234, 237));
        e.Graphics.FillEllipse(badgeBrush, pad, Math.Max(pad, (Height - badge) / 2), badge, badge);
        using var small = new Font("Segoe UI", 8.5f, FontStyle.Bold);
        TextRenderer.DrawText(e.Graphics, Number.ToString("00"), small, new Rectangle(pad, Math.Max(pad, (Height - badge) / 2), badge, badge), Selected ? Color.White : StudioTheme.Muted,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        var titleBounds = new Rectangle(pad + badge + (int)(8 * scale), pad, Math.Max(1, Width - pad * 2 - badge - (int)(8 * scale)), Math.Max(1, Height - pad * 2));
        TextRenderer.DrawText(e.Graphics, PieceTitle, Font, titleBounds, Occupied ? StudioTheme.Ink : StudioTheme.Muted,
            TextFormatFlags.WordBreak | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix | TextFormatFlags.VerticalCenter);
        if (Focused && ShowFocusCues) ControlPaint.DrawFocusRectangle(e.Graphics, Rectangle.Inflate(ClientRectangle, -5, -5));
    }
}

internal sealed class WorkspaceHost : Panel
{
    readonly List<Control> pages = [];
    int selected;
    public event EventHandler? SelectedIndexChanged;
    public int SelectedIndex
    {
        get => selected;
        set
        {
            if (value < 0 || value >= pages.Count || value == selected) return;
            selected = value;
            for (int i = 0; i < pages.Count; i++) pages[i].Visible = i == selected;
            pages[selected].BringToFront(); SelectedIndexChanged?.Invoke(this, EventArgs.Empty);
        }
    }
    public void AddPage(Control page)
    { page.Dock = DockStyle.Fill; pages.Add(page); Controls.Add(page); page.Visible = pages.Count == 1; }
}

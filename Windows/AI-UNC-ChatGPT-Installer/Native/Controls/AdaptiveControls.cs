using System.Drawing;

namespace AIUNCChatGPTInstaller.Controls;

internal sealed class MeasuredButton : Button
{
    public MeasuredButton()
    {
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        UseVisualStyleBackColor = true;
        TextAlign = ContentAlignment.MiddleCenter;
    }

    public override Size GetPreferredSize(Size proposedSize)
    {
        var preferred = base.GetPreferredSize(proposedSize);
        var text = TextRenderer.MeasureText(
            Text,
            Font,
            Size.Empty,
            TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine);
        var horizontalPadding = Math.Max(24, (int)Math.Ceiling(text.Height * 1.4D));
        var verticalPadding = Math.Max(14, (int)Math.Ceiling(text.Height * 0.8D));
        var required = new Size(
            text.Width + horizontalPadding,
            text.Height + verticalPadding);
        return new Size(
            Math.Max(preferred.Width, required.Width),
            Math.Max(preferred.Height, required.Height));
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        RefreshMinimumSize();
    }

    protected override void OnDpiChangedAfterParent(EventArgs e)
    {
        base.OnDpiChangedAfterParent(e);
        RefreshMinimumSize();
    }

    protected override void OnFontChanged(EventArgs e)
    {
        base.OnFontChanged(e);
        RefreshMinimumSize();
    }

    protected override void OnTextChanged(EventArgs e)
    {
        base.OnTextChanged(e);
        RefreshMinimumSize();
    }

    private void RefreshMinimumSize()
    {
        if (Disposing || IsDisposed)
        {
            return;
        }

        MinimumSize = Size.Empty;
        MinimumSize = GetPreferredSize(Size.Empty);
        Parent?.PerformLayout(this, nameof(MinimumSize));
    }
}

internal sealed class MeasuredCheckBox : CheckBox
{
    public MeasuredCheckBox()
    {
        AutoSize = true;
        TextAlign = ContentAlignment.MiddleLeft;
    }

    public override Size GetPreferredSize(Size proposedSize)
    {
        var preferred = base.GetPreferredSize(proposedSize);
        var text = TextRenderer.MeasureText(
            Text,
            Font,
            Size.Empty,
            TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine);
        var verticalPadding = Math.Max(6, (int)Math.Ceiling(text.Height * 0.35D));
        return new Size(
            Math.Max(preferred.Width, text.Width + Math.Max(24, text.Height)),
            Math.Max(preferred.Height, text.Height + verticalPadding));
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        RefreshMinimumSize();
    }

    protected override void OnDpiChangedAfterParent(EventArgs e)
    {
        base.OnDpiChangedAfterParent(e);
        RefreshMinimumSize();
    }

    protected override void OnFontChanged(EventArgs e)
    {
        base.OnFontChanged(e);
        RefreshMinimumSize();
    }

    protected override void OnTextChanged(EventArgs e)
    {
        base.OnTextChanged(e);
        RefreshMinimumSize();
    }

    private void RefreshMinimumSize()
    {
        if (Disposing || IsDisposed)
        {
            return;
        }

        MinimumSize = Size.Empty;
        MinimumSize = GetPreferredSize(Size.Empty);
        Parent?.PerformLayout(this, nameof(MinimumSize));
    }
}

internal sealed class WrappingLabel : Label
{
    public WrappingLabel()
    {
        AutoSize = true;
        UseCompatibleTextRendering = false;
    }

    public override Size GetPreferredSize(Size proposedSize)
    {
        var availableWidth = MaximumSize.Width > 0
            ? MaximumSize.Width
            : proposedSize.Width;
        if (availableWidth <= 0 || availableWidth == int.MaxValue)
        {
            availableWidth = ScaleLogical(360);
        }

        var measured = TextRenderer.MeasureText(
            Text,
            Font,
            new Size(availableWidth, int.MaxValue),
            TextFormatFlags.NoPrefix |
            TextFormatFlags.WordBreak |
            TextFormatFlags.TextBoxControl);
        var singleLine = TextRenderer.MeasureText(
            "Ag",
            Font,
            Size.Empty,
            TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine);
        return new Size(
            Math.Min(availableWidth, measured.Width + 2),
            measured.Height + Math.Max(4, (int)Math.Ceiling(singleLine.Height * 0.3D)));
    }

    private int ScaleLogical(int value) =>
        (int)Math.Ceiling(value * Math.Max(DeviceDpi, 96) / 96D);
}

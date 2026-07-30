using AIUNCChatGPTInstaller.Controls;

namespace AIUNCChatGPTInstaller.Services;

internal static class UiLayoutAuditor
{
    public static IReadOnlyList<string> FindClippedText(Control root)
    {
        var issues = new List<string>();
        Inspect(root, issues);
        return issues;
    }

    private static void Inspect(Control parent, List<string> issues)
    {
        foreach (Control control in parent.Controls)
        {
            if (!control.Visible)
            {
                continue;
            }

            switch (control)
            {
                case MeasuredButton button:
                    CheckPreferredSize(button, button.GetPreferredSize(Size.Empty), issues);
                    break;
                case MeasuredCheckBox checkBox:
                    CheckPreferredSize(checkBox, checkBox.GetPreferredSize(Size.Empty), issues);
                    break;
                case ComboBox comboBox:
                    CheckComboBox(comboBox, issues);
                    break;
                case TabControl tabControl:
                    CheckTabHeaders(tabControl, issues);
                    break;
                case TextBox textBox when !textBox.Multiline:
                    if (textBox.Height < textBox.PreferredHeight)
                    {
                        issues.Add(
                            $"{ControlName(textBox)} height {textBox.Height}px is below its preferred {textBox.PreferredHeight}px.");
                    }
                    break;
                case WrappingLabel wrappingLabel:
                    var preferred = wrappingLabel.GetPreferredSize(
                        new Size(Math.Max(wrappingLabel.Width, 1), int.MaxValue));
                    if (wrappingLabel.Height < preferred.Height)
                    {
                        issues.Add(
                            $"{ControlName(wrappingLabel)} height {wrappingLabel.Height}px is below its wrapped preferred height {preferred.Height}px.");
                    }
                    break;
                case Label label when label.AutoSize && label is not WrappingLabel:
                    CheckPreferredSize(label, label.GetPreferredSize(Size.Empty), issues);
                    break;
            }

            Inspect(control, issues);
        }
    }

    private static void CheckComboBox(ComboBox comboBox, List<string> issues)
    {
        var text = comboBox.SelectedItem?.ToString() ?? comboBox.Text;
        var measured = TextRenderer.MeasureText(
            text,
            comboBox.Font,
            Size.Empty,
            TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine);
        var requiredWidth = measured.Width + Scale(comboBox, 34);
        var requiredHeight = measured.Height + Scale(comboBox, 4);
        if (comboBox.ClientSize.Width < requiredWidth ||
            comboBox.ClientSize.Height < requiredHeight)
        {
            issues.Add(
                $"{ControlName(comboBox)} is {comboBox.ClientSize.Width}x{comboBox.ClientSize.Height}px; selected text requires at least {requiredWidth}x{requiredHeight}px.");
        }
    }

    private static void CheckTabHeaders(TabControl tabControl, List<string> issues)
    {
        for (var index = 0; index < tabControl.TabPages.Count; index++)
        {
            var tabPage = tabControl.TabPages[index];
            var bounds = tabControl.GetTabRect(index);
            var measured = TextRenderer.MeasureText(
                tabPage.Text,
                tabControl.Font,
                Size.Empty,
                TextFormatFlags.NoPrefix | TextFormatFlags.SingleLine);
            var requiredWidth = measured.Width + Scale(tabControl, 18);
            var requiredHeight = measured.Height + Scale(tabControl, 8);
            if (bounds.Width < requiredWidth || bounds.Height < requiredHeight)
            {
                issues.Add(
                    $"Tab \"{tabPage.Text}\" is {bounds.Width}x{bounds.Height}px; text requires at least {requiredWidth}x{requiredHeight}px.");
            }
        }
    }

    private static void CheckPreferredSize(
        Control control,
        Size preferred,
        List<string> issues)
    {
        if (control.Width < preferred.Width || control.Height < preferred.Height)
        {
            issues.Add(
                $"{ControlName(control)} is {control.Width}x{control.Height}px; preferred size is {preferred.Width}x{preferred.Height}px.");
        }
    }

    private static int Scale(Control control, int value) =>
        (int)Math.Ceiling(value * Math.Max(control.DeviceDpi, 96) / 96D);

    private static string ControlName(Control control) =>
        string.IsNullOrWhiteSpace(control.AccessibleName)
            ? $"{control.GetType().Name} \"{control.Text}\""
            : control.AccessibleName;
}

namespace AIUNCChatGPTInstaller;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            var auditArgument = args.FirstOrDefault(argument =>
                argument.StartsWith("--layout-audit-report=", StringComparison.OrdinalIgnoreCase));
            if (auditArgument is not null)
            {
                return RunLayoutAudit(auditArgument["--layout-audit-report=".Length..]);
            }

            using var form = new MainForm();
            Application.Run(form);
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"AI @ UNC ChatGPT Installer could not start.\r\n\r\n{ex.Message}",
                "Startup Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }
    }

    private static int RunLayoutAudit(string reportPath)
    {
        var report = new List<string>
        {
            "AI @ UNC ChatGPT Installer Windows Layout Audit",
            $"Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}",
            string.Empty
        };
        var failed = false;
        foreach (var scale in new[] { 1F, 1.25F, 1.5F, 1.75F, 2F })
        {
            using var form = new MainForm(
                runStartupDetection: false,
                baseFontSize: 9F * scale);
            form.ClientSize = new Size(
                (int)Math.Ceiling(980 * scale),
                (int)Math.Ceiling(820 * scale));
            form.Show();
            Application.DoEvents();
            var issues = form.AuditLayout();
            report.Add(
                $"Scale {scale:0.##}: {(issues.Count == 0 ? "PASS" : $"FAIL ({issues.Count})")}");
            foreach (var issue in issues)
            {
                report.Add($"  {issue}");
            }

            report.Add(string.Empty);
            failed |= issues.Count > 0;
            form.Close();
            Application.DoEvents();
        }

        var fullPath = Path.GetFullPath(reportPath);
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath) ?? Environment.CurrentDirectory);
        File.WriteAllLines(fullPath, report);
        return failed ? 2 : 0;
    }
}

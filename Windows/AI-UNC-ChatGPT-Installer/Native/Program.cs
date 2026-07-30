namespace AIUNCChatGPTInstaller;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            using var form = new MainForm();
            Application.Run(form);
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"AI @ UNC ChatGPT Installer could not start.\r\n\r\n{ex.Message}",
                "Startup Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}

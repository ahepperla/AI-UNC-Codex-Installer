namespace AIUNCChatGPTInstaller.Services;

internal sealed class LogService
{
    private readonly AppPaths _paths;
    private readonly object _sync = new();

    public LogService(AppPaths paths)
    {
        _paths = paths;
    }

    public event Action<string>? MessageWritten;

    public void Write(string message)
    {
        var line = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}";
        lock (_sync)
        {
            Directory.CreateDirectory(_paths.SupportDirectory);
            File.AppendAllText(_paths.LogPath, line + Environment.NewLine);
        }

        MessageWritten?.Invoke(line);
    }
}

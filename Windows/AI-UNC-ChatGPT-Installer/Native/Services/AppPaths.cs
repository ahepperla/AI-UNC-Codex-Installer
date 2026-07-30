namespace AIUNCChatGPTInstaller.Services;

internal sealed class AppPaths
{
    public const string EnvironmentKey = "UNC_AZURE_API_KEY";
    public const string CodexHomeEnvironmentKey = "CODEX_HOME";

    public AppPaths()
    {
        UserProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        Documents = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        if (string.IsNullOrWhiteSpace(Documents))
        {
            Documents = Path.Combine(UserProfile, "Documents");
        }

        var configuredHome = Environment.GetEnvironmentVariable(CodexHomeEnvironmentKey, EnvironmentVariableTarget.Process);
        if (string.IsNullOrWhiteSpace(configuredHome) && OperatingSystem.IsWindows())
        {
            configuredHome = Environment.GetEnvironmentVariable(CodexHomeEnvironmentKey, EnvironmentVariableTarget.User);
        }

        CodexHomeSource = string.IsNullOrWhiteSpace(configuredHome) ? "default" : CodexHomeEnvironmentKey;
        CodexHome = string.IsNullOrWhiteSpace(configuredHome)
            ? Path.Combine(UserProfile, ".codex")
            : NormalizePath(Environment.ExpandEnvironmentVariables(configuredHome.Trim()));

        Environment.SetEnvironmentVariable(CodexHomeEnvironmentKey, CodexHome, EnvironmentVariableTarget.Process);
        SupportDirectory = Path.Combine(CodexHome, "unc");
        ConfigPath = Path.Combine(CodexHome, "config.toml");
        LogPath = Path.Combine(SupportDirectory, "windows-installer.log");
        ReceiptPath = Path.Combine(SupportDirectory, "setup-receipt.txt");
        WorkspaceSettingPath = Path.Combine(SupportDirectory, "workspace-path.txt");
        ModelCatalogPath = Path.Combine(SupportDirectory, "model-catalog.json");
    }

    public string UserProfile { get; }
    public string Documents { get; }
    public string CodexHome { get; }
    public string CodexHomeSource { get; }
    public string SupportDirectory { get; }
    public string ConfigPath { get; }
    public string LogPath { get; }
    public string ReceiptPath { get; }
    public string WorkspaceSettingPath { get; }
    public string ModelCatalogPath { get; }

    public string LegacyWorkspace => Path.Combine(Documents, "Codex");
    public string PreferredWorkspace => Path.Combine(Documents, "ChatGPT");

    public string GetWorkspacePath()
    {
        if (File.Exists(WorkspaceSettingPath))
        {
            var saved = File.ReadAllText(WorkspaceSettingPath).Trim();
            if (!string.IsNullOrWhiteSpace(saved))
            {
                return NormalizeWorkspace(saved);
            }
        }

        RemoveStaleEmptyChildWorkspace();
        return Directory.Exists(LegacyWorkspace) ? LegacyWorkspace : PreferredWorkspace;
    }

    public void SaveWorkspacePath(string path)
    {
        FileUtilities.WriteAllTextAtomic(WorkspaceSettingPath, NormalizeWorkspace(path) + Environment.NewLine);
    }

    public void ResetWorkspacePath()
    {
        if (File.Exists(WorkspaceSettingPath))
        {
            File.Delete(WorkspaceSettingPath);
        }
    }

    private string NormalizeWorkspace(string path)
    {
        var expanded = NormalizePath(Environment.ExpandEnvironmentVariables(path));
        var staleChild = NormalizePath(Path.Combine(LegacyWorkspace, "ChatGPT"));
        return string.Equals(expanded.TrimEnd(Path.DirectorySeparatorChar), staleChild.TrimEnd(Path.DirectorySeparatorChar), StringComparison.OrdinalIgnoreCase)
            ? LegacyWorkspace
            : expanded;
    }

    private void RemoveStaleEmptyChildWorkspace()
    {
        var staleChild = Path.Combine(LegacyWorkspace, "ChatGPT");
        if (Directory.Exists(staleChild) && !Directory.EnumerateFileSystemEntries(staleChild).Any())
        {
            Directory.Delete(staleChild);
        }
    }

    private string NormalizePath(string path)
    {
        if (!Path.IsPathRooted(path))
        {
            path = Path.Combine(UserProfile, path);
        }

        return Path.GetFullPath(path);
    }
}

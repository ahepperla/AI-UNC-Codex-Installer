namespace AIUNCChatGPTInstaller.Models;

internal sealed record DetectionResult(
    string? CliPath,
    string? CliVersion,
    string? DesktopAppName,
    string? DesktopAppId,
    bool DesktopInstalled,
    string? DesktopPackageName,
    string? DesktopPackageVersion)
{
    public bool Installed => DesktopInstalled || !string.IsNullOrWhiteSpace(CliPath);
}

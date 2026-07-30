using Microsoft.Win32;
using System.Runtime.InteropServices;

namespace AIUNCChatGPTInstaller.Services;

internal sealed record DesktopAppInfo(
    string? DisplayName,
    string? AppUserModelId,
    bool PackageInstalled,
    string? PackageName,
    string? PackageVersion);

internal static class DesktopAppLocator
{
    private const string PackagePrefix = "OpenAI.Codex_";
    private const string PackageRegistryPath =
        @"Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages";

    public static DesktopAppInfo Detect()
    {
        var startApp = FindStartApp();
        var package = FindRegisteredPackage();
        return new DesktopAppInfo(
            startApp.Name ?? package.Name,
            startApp.AppId,
            package.Installed || startApp.AppId is not null,
            package.Name,
            package.Version);
    }

    private static (string? Name, string? AppId) FindStartApp()
    {
        object? shell = null;
        object? folder = null;
        object? items = null;
        try
        {
            var shellType = Type.GetTypeFromProgID("Shell.Application");
            if (shellType is null)
            {
                return (null, null);
            }

            shell = Activator.CreateInstance(shellType);
            dynamic dynamicShell = shell!;
            folder = dynamicShell.NameSpace("shell:AppsFolder");
            if (folder is null)
            {
                return (null, null);
            }

            dynamic dynamicFolder = folder;
            items = dynamicFolder.Items();
            foreach (var rawItem in (System.Collections.IEnumerable)items)
            {
                object? item = rawItem;
                try
                {
                    dynamic dynamicItem = item!;
                    string appId = Convert.ToString(dynamicItem.Path) ?? string.Empty;
                    if (!appId.StartsWith(PackagePrefix, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    string name = Convert.ToString(dynamicItem.Name) ?? "ChatGPT";
                    return (name, string.IsNullOrWhiteSpace(appId) ? null : appId);
                }
                finally
                {
                    ReleaseComObject(item);
                }
            }
        }
        catch
        {
            return (null, null);
        }
        finally
        {
            ReleaseComObject(items);
            ReleaseComObject(folder);
            ReleaseComObject(shell);
        }

        return (null, null);
    }

    private static (bool Installed, string? Name, string? Version) FindRegisteredPackage()
    {
        try
        {
            using var packages = Registry.CurrentUser.OpenSubKey(PackageRegistryPath);
            var packageName = packages?.GetSubKeyNames()
                .Where(name => name.StartsWith(PackagePrefix, StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(name => name, StringComparer.OrdinalIgnoreCase)
                .FirstOrDefault();

            if (packageName is null)
            {
                return (false, null, null);
            }

            var parts = packageName.Split('_');
            var version = parts.Length > 1 ? parts[1] : null;
            return (true, "OpenAI.Codex", version);
        }
        catch
        {
            return (false, null, null);
        }
    }

    private static void ReleaseComObject(object? value)
    {
        if (value is not null && Marshal.IsComObject(value))
        {
            _ = Marshal.FinalReleaseComObject(value);
        }
    }
}

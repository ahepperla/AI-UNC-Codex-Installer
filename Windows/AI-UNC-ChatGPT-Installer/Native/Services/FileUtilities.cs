using System.Text;

namespace AIUNCChatGPTInstaller.Services;

internal static class FileUtilities
{
    private static readonly UTF8Encoding Utf8WithoutBom = new(false);

    public static void WriteAllTextAtomic(string path, string value)
    {
        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var temporaryPath = Path.Combine(
            directory ?? Path.GetTempPath(),
            $".{Path.GetFileName(path)}.tmp.{Guid.NewGuid():N}");

        try
        {
            File.WriteAllText(temporaryPath, value, Utf8WithoutBom);
            File.Move(temporaryPath, path, true);
        }
        finally
        {
            TryDeleteFile(temporaryPath);
        }
    }

    public static void CopyAtomic(string source, string destination)
    {
        var directory = Path.GetDirectoryName(destination);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var temporaryPath = Path.Combine(
            directory ?? Path.GetTempPath(),
            $".{Path.GetFileName(destination)}.tmp.{Guid.NewGuid():N}");

        try
        {
            File.Copy(source, temporaryPath, true);
            File.Move(temporaryPath, destination, true);
        }
        finally
        {
            TryDeleteFile(temporaryPath);
        }
    }

    public static string UniqueTimestampedPath(string directory, string prefix)
    {
        Directory.CreateDirectory(directory);
        var baseName = $"{prefix}.{DateTime.Now:yyyyMMdd_HHmmss}";
        var candidate = Path.Combine(directory, baseName);
        var suffix = 1;
        while (File.Exists(candidate) || Directory.Exists(candidate))
        {
            candidate = Path.Combine(directory, $"{baseName}.{suffix++}");
        }

        return candidate;
    }

    public static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
            // Best-effort cleanup.
        }
    }

    public static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path))
            {
                Directory.Delete(path, true);
            }
        }
        catch
        {
            // Best-effort cleanup.
        }
    }
}

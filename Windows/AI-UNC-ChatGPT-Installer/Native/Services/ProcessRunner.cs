using System.Diagnostics;
using AIUNCChatGPTInstaller.Models;

namespace AIUNCChatGPTInstaller.Services;

internal sealed class ProcessRunner
{
    private readonly LogService _log;

    public ProcessRunner(LogService log)
    {
        _log = log;
    }

    public async Task<ProcessResult> RunAsync(
        string filePath,
        IEnumerable<string>? arguments = null,
        IReadOnlyDictionary<string, string>? environment = null,
        CancellationToken cancellationToken = default)
    {
        var (executable, effectiveArguments) = WrapScript(filePath, arguments ?? []);
        _log.Write($"Running: {executable} {string.Join(" ", effectiveArguments.Select(QuoteForLog))}".Trim());

        var startInfo = new ProcessStartInfo
        {
            FileName = executable,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };

        foreach (var argument in effectiveArguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        if (environment is not null)
        {
            foreach (var item in environment)
            {
                startInfo.Environment[item.Key] = item.Value;
            }
        }

        using var process = new Process { StartInfo = startInfo };
        process.Start();
        var standardOutputTask = process.StandardOutput.ReadToEndAsync();
        var standardErrorTask = process.StandardError.ReadToEndAsync();
        try
        {
            await process.WaitForExitAsync(cancellationToken);
        }
        catch (OperationCanceledException)
        {
            TryKill(process);
            throw;
        }

        var standardOutput = await standardOutputTask;
        var standardError = await standardErrorTask;
        var result = new ProcessResult(process.ExitCode, standardOutput.Trim(), standardError.Trim());
        if (!string.IsNullOrWhiteSpace(result.Output))
        {
            _log.Write(result.Output);
        }

        return result;
    }

    public Process StartInteractive(
        string filePath,
        IEnumerable<string>? arguments = null)
    {
        _log.Write($"Running interactive installer: {filePath}");
        var startInfo = new ProcessStartInfo
        {
            FileName = filePath,
            UseShellExecute = true,
            WorkingDirectory = Path.GetDirectoryName(filePath) ?? Environment.CurrentDirectory
        };

        foreach (var argument in arguments ?? [])
        {
            startInfo.ArgumentList.Add(argument);
        }

        var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException($"Could not start {filePath}.");
        _log.Write($"Interactive installer started with process ID {process.Id}.");
        return process;
    }

    public static string? FindOnPath(params string[] names)
    {
        var pathEntries = (Environment.GetEnvironmentVariable("PATH") ?? string.Empty)
            .Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        foreach (var name in names)
        {
            if (Path.IsPathRooted(name) && File.Exists(name))
            {
                return name;
            }

            foreach (var directory in pathEntries)
            {
                var candidate = Path.Combine(directory.Trim('"'), name);
                if (File.Exists(candidate))
                {
                    return candidate;
                }
            }
        }

        return null;
    }

    private static (string Executable, string[] Arguments) WrapScript(string filePath, IEnumerable<string> arguments)
    {
        var extension = Path.GetExtension(filePath);
        if (extension.Equals(".ps1", StringComparison.OrdinalIgnoreCase))
        {
            return ("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", filePath, .. arguments]);
        }

        if (extension.Equals(".cmd", StringComparison.OrdinalIgnoreCase) ||
            extension.Equals(".bat", StringComparison.OrdinalIgnoreCase))
        {
            return (Environment.GetEnvironmentVariable("ComSpec") ?? "cmd.exe", ["/d", "/c", filePath, .. arguments]);
        }

        return (filePath, [.. arguments]);
    }

    private static string QuoteForLog(string value) =>
        value.Any(char.IsWhiteSpace) ? $"\"{value.Replace("\"", "\\\"")}\"" : value;

    private static void TryKill(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
            }
        }
        catch
        {
            // Best-effort cancellation.
        }
    }
}

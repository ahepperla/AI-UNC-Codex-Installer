using System.Diagnostics;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using AIUNCChatGPTInstaller.Models;

namespace AIUNCChatGPTInstaller.Services;

internal sealed partial class InstallerService : IDisposable
{
    public const string InstallerVersion = "2026.07.29.5";
    public const string InstallerBuildDate = "2026-07-29";
    public const string EndpointBaseUrl = "https://azureaiapi.cloud.unc.edu/openai/v1";
    public const string ResponsesUrl = EndpointBaseUrl + "/responses";
    public const string ChatGPTDownloadUrl = "https://chatgpt.com/download/";
    public const string CodexDownloadUrl = "https://openai.com/codex/";
    public const string ChatGPTStoreProductId = "9PLM9XGG6VKS";
    public const string ChatGPTWebInstallerUrl =
        "https://get.microsoft.com/installer/download/9PLM9XGG6VKS?cid=website_cta_psi";
    public const string CodexInstallerUrl = "https://chatgpt.com/codex/install.ps1";

    private readonly AppPaths _paths;
    private readonly LogService _log;
    private readonly ProcessRunner _processRunner;
    private readonly HttpClient _httpClient;

    public InstallerService(AppPaths paths, LogService log)
    {
        _paths = paths;
        _log = log;
        _processRunner = new ProcessRunner(log);
        _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(120)
        };
        _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd(
            $"AI-UNC-ChatGPT-Installer/{InstallerVersion}");
    }

    public async Task<DetectionResult> DetectAsync(CancellationToken cancellationToken = default)
    {
        var cliPath = FindCliPath();
        var cliVersion = await GetCliVersionAsync(cliPath, cancellationToken);
        var desktop = OperatingSystem.IsWindows()
            ? DesktopAppLocator.Detect()
            : new DesktopAppInfo(null, null, false, null, null);

        return new DetectionResult(
            cliPath,
            cliVersion,
            desktop.DisplayName,
            desktop.AppUserModelId,
            desktop.PackageInstalled,
            desktop.PackageName,
            desktop.PackageVersion);
    }

    public async Task WriteConfigAsync(
        string apiKey,
        ModelOption model,
        string? reasoningEffort,
        bool usePlaintextConfig,
        CancellationToken cancellationToken = default,
        bool backupExisting = true)
    {
        if (backupExisting)
        {
            BackupConfig();
        }

        var catalogWritten = await WriteModelCatalogAsync(cancellationToken);
        var lines = new List<string>
        {
            $"model = \"{TomlEscape(model.Deployment)}\"",
            "model_provider = \"azure\""
        };

        if (!string.IsNullOrWhiteSpace(reasoningEffort))
        {
            lines.Add($"model_reasoning_effort = \"{TomlEscape(reasoningEffort)}\"");
        }

        if (catalogWritten)
        {
            lines.Add($"model_catalog_json = \"{TomlEscape(_paths.ModelCatalogPath)}\"");
        }

        lines.Add(string.Empty);
        lines.Add("[model_providers.azure]");
        lines.Add("name = \"Azure OpenAI\"");
        lines.Add($"base_url = \"{EndpointBaseUrl}\"");

        if (usePlaintextConfig)
        {
            RemoveApiKey();
            lines.Add($"experimental_bearer_token = \"{TomlEscape(apiKey)}\"");
            _log.Write("Writing Codex config with plaintext bearer token fallback.");
        }
        else
        {
            SaveApiKey(apiKey);
            lines.Add($"env_key = \"{AppPaths.EnvironmentKey}\"");
            _log.Write("Writing Codex config with user environment variable authentication.");
        }

        lines.Add("wire_api = \"responses\"");
        FileUtilities.WriteAllTextAtomic(
            _paths.ConfigPath,
            string.Join(Environment.NewLine, lines) + Environment.NewLine);

        if (usePlaintextConfig)
        {
            RestrictFileToCurrentUser(_paths.ConfigPath);
        }

        _log.Write(
            $"Wrote Codex config at {_paths.ConfigPath} for {model.Deployment} with reasoning {reasoningEffort ?? "model default"}.");
    }

    public async Task<bool> TestEndpointAsync(
        string apiKey,
        ModelOption model,
        CancellationToken cancellationToken = default)
    {
        _log.Write($"Testing UNC Azure OpenAI endpoint with {model.Deployment}.");
        using var request = new HttpRequestMessage(HttpMethod.Post, ResponsesUrl);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Content = JsonContent.Create(new
        {
            model = model.Deployment,
            input = "Reply exactly: UNC Codex setup OK",
            store = false,
            background = false
        });

        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(TimeSpan.FromSeconds(30));
            using var response = await _httpClient.SendAsync(request, timeout.Token);
            var content = await response.Content.ReadAsStringAsync(timeout.Token);
            _log.Write($"Endpoint returned HTTP {(int)response.StatusCode}.");
            if (!response.IsSuccessStatusCode)
            {
                _log.Write($"Connection test failed: HTTP {(int)response.StatusCode}.");
                return false;
            }

            if (!content.Contains("UNC Codex setup OK", StringComparison.Ordinal))
            {
                _log.Write("Endpoint responded, but the expected confirmation text was not found.");
                return false;
            }

            _log.Write("Connection test succeeded.");
            return true;
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            _log.Write("Connection test failed: the UNC endpoint timed out.");
            return false;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _log.Write($"Connection test failed: {ex.Message}");
            return false;
        }
    }

    public async Task<InstallResult> InstallAppsAsync(
        bool force,
        CancellationToken cancellationToken = default)
    {
        var detection = await DetectAsync(cancellationToken);
        var desktopInstalled = detection.DesktopInstalled;
        if (desktopInstalled && !force)
        {
            _log.Write("ChatGPT Desktop is already installed.");
        }
        else
        {
            desktopInstalled = await InstallDesktopWithWebInstallerAsync(cancellationToken);
            if (!desktopInstalled)
            {
                desktopInstalled = await InstallDesktopWithWingetAsync(cancellationToken);
            }

            detection = await DetectAsync(cancellationToken);
            desktopInstalled = desktopInstalled || detection.DesktopInstalled;
        }

        var cliInstalled = !string.IsNullOrWhiteSpace(detection.CliPath);
        if (!cliInstalled)
        {
            cliInstalled = await InstallCliAsync(cancellationToken);
        }
        else
        {
            _log.Write("Codex CLI is already installed; skipping the standalone CLI installer.");
        }

        if (!desktopInstalled)
        {
            _log.Write("ChatGPT Desktop installation did not finish. Opening the official OpenAI download page.");
            OpenUrl(ChatGPTDownloadUrl);
        }

        if (!cliInstalled)
        {
            OpenUrl(CodexDownloadUrl);
        }

        return new InstallResult(desktopInstalled, cliInstalled);
    }

    public async Task<bool> InstallCliAsync(CancellationToken cancellationToken = default)
    {
        var existing = FindCliPath();
        if (!string.IsNullOrWhiteSpace(existing))
        {
            _log.Write($"Codex CLI is already installed at {existing}.");
            return true;
        }

        var installerPath = Path.Combine(
            Path.GetTempPath(),
            $"codex-install-{Guid.NewGuid():N}.ps1");
        try
        {
            _log.Write("Downloading OpenAI's official Codex CLI installer.");
            await DownloadFileAsync(CodexInstallerUrl, installerPath, cancellationToken);
            var result = await _processRunner.RunAsync(
                installerPath,
                environment: new Dictionary<string, string>
                {
                    ["CODEX_NON_INTERACTIVE"] = "1",
                    ["CI"] = "1"
                },
                cancellationToken: cancellationToken);
            if (!result.Succeeded)
            {
                _log.Write("The Codex CLI installer returned a nonzero exit code.");
            }

            var localBin = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs", "OpenAI", "Codex", "bin");
            if (Directory.Exists(localBin))
            {
                var currentPath = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
                if (!currentPath.Split(Path.PathSeparator).Contains(localBin, StringComparer.OrdinalIgnoreCase))
                {
                    Environment.SetEnvironmentVariable("PATH", $"{localBin}{Path.PathSeparator}{currentPath}");
                }
            }

            return await WaitForCliAsync(TimeSpan.FromSeconds(45), cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _log.Write($"Codex CLI installation failed: {ex.Message}");
            return false;
        }
        finally
        {
            FileUtilities.TryDeleteFile(installerPath);
        }
    }

    public string? GetAvailableApiKey()
    {
        var environmentValue = OperatingSystem.IsWindows()
            ? Environment.GetEnvironmentVariable(AppPaths.EnvironmentKey, EnvironmentVariableTarget.User)
            : Environment.GetEnvironmentVariable(AppPaths.EnvironmentKey);
        if (!string.IsNullOrWhiteSpace(environmentValue))
        {
            return environmentValue.Trim();
        }

        if (!File.Exists(_paths.ConfigPath))
        {
            return null;
        }

        try
        {
            var match = PlaintextTokenRegex().Match(File.ReadAllText(_paths.ConfigPath));
            return match.Success ? TomlUnescape(match.Groups[1].Value) : null;
        }
        catch (Exception ex)
        {
            _log.Write($"Could not read plaintext bearer token from config: {ex.Message}");
            return null;
        }
    }

    public void OpenDesktop(DetectionResult detection)
    {
        if (string.IsNullOrWhiteSpace(detection.DesktopAppId))
        {
            throw new InvalidOperationException(
                "ChatGPT Desktop is installed, but its Start menu registration is not ready yet. Wait a moment and click Detect again.");
        }

        _log.Write($"Opening ChatGPT desktop app: {detection.DesktopAppName}");
        Process.Start(new ProcessStartInfo
        {
            FileName = "explorer.exe",
            UseShellExecute = true,
            Arguments = $"shell:AppsFolder\\{detection.DesktopAppId}"
        });
    }

    public void OpenCli(DetectionResult detection)
    {
        if (string.IsNullOrWhiteSpace(detection.CliPath))
        {
            throw new InvalidOperationException("Codex CLI was not detected.");
        }

        var workspace = EnsureWorkspace();
        var key = GetAvailableApiKey();
        if (!string.IsNullOrWhiteSpace(key))
        {
            Environment.SetEnvironmentVariable(
                AppPaths.EnvironmentKey,
                key,
                EnvironmentVariableTarget.Process);
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = "powershell.exe",
            WorkingDirectory = workspace,
            UseShellExecute = true,
            ArgumentList =
            {
                "-NoExit",
                "-NoProfile",
                "-Command",
                $"& {PowerShellQuote(detection.CliPath)}"
            }
        });
    }

    public void OpenWorkspace()
    {
        var workspace = EnsureWorkspace();
        Process.Start(new ProcessStartInfo
        {
            FileName = "explorer.exe",
            Arguments = workspace,
            UseShellExecute = true
        });
    }

    public void SetWorkspace(string path)
    {
        _paths.SaveWorkspacePath(path);
        _log.Write($"Project parent set to {_paths.GetWorkspacePath()}.");
    }

    public void ResetWorkspace()
    {
        _paths.ResetWorkspacePath();
        _log.Write($"Project parent reset to {_paths.GetWorkspacePath()}.");
    }

    public void SaveReceipt(bool endpointSucceeded, DetectionResult detection)
    {
        var workspace = _paths.GetWorkspacePath();
        var lines = new[]
        {
            "AI @ UNC ChatGPT Installer Setup Receipt",
            $"Installer version: {InstallerVersion}",
            $"Installer build date: {InstallerBuildDate}",
            $"Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}",
            string.Empty,
            "What happened:",
            $"- Fresh config written: {_paths.ConfigPath}",
            $"- Endpoint test: {(endpointSucceeded ? "succeeded" : "failed or not run")}",
            $"- ChatGPT Desktop: {detection.DesktopAppName ?? "not detected"}",
            $"- Codex CLI: {detection.CliPath ?? "not detected"}",
            $"- Project parent: {workspace}",
            string.Empty,
            $"Windows user: {Environment.UserName}",
            $"Computer: {Environment.MachineName}",
            $"Codex home: {_paths.CodexHome}",
            $"Codex home source: {_paths.CodexHomeSource}",
            $"Model: {GetConfiguredValue("model") ?? "unknown"}",
            $"Reasoning effort: {GetConfiguredValue("model_reasoning_effort") ?? "model default"}",
            $"Desktop package: {detection.DesktopPackageName ?? "not detected"} {detection.DesktopPackageVersion}".TrimEnd(),
            $"Codex version: {detection.CliVersion ?? "unknown"}"
        };
        FileUtilities.WriteAllTextAtomic(
            _paths.ReceiptPath,
            string.Join(Environment.NewLine, lines) + Environment.NewLine);
        _log.Write($"Saved setup receipt at {_paths.ReceiptPath}.");
    }

    public string SaveSupportReport(DetectionResult detection)
    {
        var desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        var reportPath = Path.Combine(desktop, "AI-UNC-ChatGPT-Installer-Support-Report.txt");
        var logTail = File.Exists(_paths.LogPath)
            ? File.ReadLines(_paths.LogPath).TakeLast(120)
            : ["No log file found."];
        var lines = new List<string>
        {
            "AI @ UNC ChatGPT Installer Support Report",
            $"Installer version: {InstallerVersion}",
            $"Installer build date: {InstallerBuildDate}",
            $"Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}",
            $"Windows user: {Environment.UserName}",
            $"Computer: {Environment.MachineName}",
            $"OS: {Environment.OSVersion.VersionString}",
            $"Process architecture: {System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture}",
            $"Codex installed: {(detection.Installed ? "yes" : "no")}",
            $"Codex CLI path: {detection.CliPath ?? "not found"}",
            $"ChatGPT desktop app: {detection.DesktopAppName ?? "not found"}",
            $"ChatGPT desktop package: {detection.DesktopPackageName ?? "not found"} {detection.DesktopPackageVersion}".TrimEnd(),
            $"Codex version: {detection.CliVersion ?? "unknown"}",
            $"Codex home: {_paths.CodexHome}",
            $"Codex home source: {_paths.CodexHomeSource}",
            $"Config path: {_paths.ConfigPath}",
            $"Project parent: {_paths.GetWorkspacePath()}",
            $"Model: {GetConfiguredValue("model") ?? "unknown"}",
            $"Reasoning effort: {GetConfiguredValue("model_reasoning_effort") ?? "model default"}",
            $"Config exists: {(File.Exists(_paths.ConfigPath) ? "yes" : "no")}",
            $"User environment variable set: {(HasUserEnvironmentApiKey() ? "yes" : "no")}",
            $"Plaintext config fallback present: {(HasPlaintextConfigToken() ? "yes" : "no")}",
            $"Log path: {_paths.LogPath}",
            string.Empty,
            "Recent installer log:"
        };
        lines.AddRange(logTail);
        FileUtilities.WriteAllTextAtomic(
            reportPath,
            string.Join(Environment.NewLine, lines) + Environment.NewLine);
        _log.Write($"Saved support report at {reportPath}.");
        return reportPath;
    }

    public void ResetConfiguration()
    {
        RemoveApiKey();
        Directory.CreateDirectory(_paths.CodexHome);
        var latestBackup = Directory.EnumerateFiles(_paths.CodexHome, "config.toml.backup.*")
            .OrderByDescending(File.GetLastWriteTimeUtc)
            .FirstOrDefault();

        if (latestBackup is not null)
        {
            if (File.Exists(_paths.ConfigPath))
            {
                File.Copy(
                    _paths.ConfigPath,
                    FileUtilities.UniqueTimestampedPath(_paths.CodexHome, "config.toml.reset-backup"),
                    true);
            }

            FileUtilities.CopyAtomic(latestBackup, _paths.ConfigPath);
            _log.Write($"Restored Codex config from {latestBackup}.");
        }
        else if (File.Exists(_paths.ConfigPath))
        {
            var removedPath = FileUtilities.UniqueTimestampedPath(_paths.CodexHome, "config.toml.removed");
            File.Move(_paths.ConfigPath, removedPath);
            _log.Write($"No config backup was available. Moved current config to {removedPath}.");
        }
        else
        {
            _log.Write("No Codex config was present.");
        }
    }

    public async Task UninstallDesktopAsync(CancellationToken cancellationToken = default)
    {
        var detection = await DetectAsync(cancellationToken);
        if (!detection.DesktopInstalled)
        {
            _log.Write("ChatGPT Desktop was not detected.");
            return;
        }

        var winget = ProcessRunner.FindOnPath("winget.exe");
        if (winget is not null)
        {
            var result = await _processRunner.RunAsync(
                winget,
                ["uninstall", "--id", ChatGPTStoreProductId, "--source", "msstore", "--exact", "--accept-source-agreements"],
                cancellationToken: cancellationToken);
            if (result.Succeeded &&
                await WaitForDesktopStateAsync(false, TimeSpan.FromSeconds(30), cancellationToken))
            {
                _log.Write("ChatGPT Desktop is no longer detected.");
                return;
            }
        }

        _log.Write("Automatic desktop uninstall did not finish. Opening Installed Apps.");
        OpenUrl("ms-settings:appsfeatures");
    }

    public async Task UninstallCliAsync(CancellationToken cancellationToken = default)
    {
        var cliPath = FindCliPath();
        if (cliPath is null)
        {
            _log.Write("Codex CLI was not detected.");
            return;
        }

        var localRoot = Path.GetFullPath(Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs", "OpenAI", "Codex"));
        var fullCliPath = Path.GetFullPath(cliPath);
        var safeLocalBins = new[]
        {
            Path.GetFullPath(Path.Combine(_paths.UserProfile, ".local", "bin", "codex")),
            Path.GetFullPath(Path.Combine(_paths.UserProfile, ".local", "bin", "codex.exe"))
        };

        if (fullCliPath.StartsWith(localRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
        {
            await Task.Run(() => Directory.Delete(localRoot, true), cancellationToken);
            _log.Write($"Removed Codex CLI folder at {localRoot}.");
        }
        else if (safeLocalBins.Contains(fullCliPath, StringComparer.OrdinalIgnoreCase))
        {
            File.Delete(fullCliPath);
            _log.Write($"Removed Codex CLI at {fullCliPath}.");
        }
        else
        {
            throw new InvalidOperationException(
                $"Codex CLI was found at {fullCliPath}, which is not a known standalone install path. Use its package manager to uninstall it.");
        }
    }

    public async Task<string> UninstallAllAsync(CancellationToken cancellationToken = default)
    {
        var notes = new List<string>();
        try
        {
            await UninstallDesktopAsync(cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            notes.Add($"ChatGPT Desktop: {ex.Message}");
            _log.Write($"Desktop uninstall did not finish: {ex.Message}");
        }

        try
        {
            await UninstallCliAsync(cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            notes.Add($"Codex CLI: {ex.Message}");
            _log.Write($"CLI uninstall did not finish: {ex.Message}");
        }

        RemoveApiKey();
        var configMessage = RestoreOrRemoveConfigForUninstall();
        FileUtilities.TryDeleteDirectory(_paths.SupportDirectory);
        notes.Insert(0, configMessage);
        return string.Join(Environment.NewLine, notes);
    }

    public void OpenUrl(string url)
    {
        Process.Start(new ProcessStartInfo { FileName = url, UseShellExecute = true });
    }

    public void Dispose()
    {
        _httpClient.Dispose();
    }

    private async Task<bool> InstallDesktopWithWebInstallerAsync(CancellationToken cancellationToken)
    {
        var installerPath = Path.Combine(
            Path.GetTempPath(),
            $"chatgpt-windows-installer-{Guid.NewGuid():N}.exe");
        try
        {
            _log.Write("Downloading OpenAI's official Microsoft web installer for ChatGPT Desktop.");
            await DownloadFileAsync(ChatGPTWebInstallerUrl, installerPath, cancellationToken);
            if (new FileInfo(installerPath).Length < 10_240)
            {
                throw new InvalidDataException("The downloaded ChatGPT installer was unexpectedly small.");
            }

            var signer = AuthenticodeVerifier.VerifyMicrosoftSignedFile(installerPath);
            _log.Write($"Verified ChatGPT web installer signer: {signer}");
            using var installerProcess = _processRunner.StartInteractive(installerPath);
            if (await WaitForDesktopStateAsync(true, TimeSpan.FromMinutes(2), cancellationToken))
            {
                _log.Write(
                    "The OpenAI.Codex Windows package is installed. Continuing without waiting for the Microsoft installer window to close.");
                return true;
            }

            var installerState = installerProcess.HasExited
                ? $"exited with code {installerProcess.ExitCode}"
                : "was still running";
            _log.Write(
                $"The web installer {installerState}, but the OpenAI.Codex package was not detected.");
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _log.Write($"ChatGPT web installer failed: {ex.Message}");
        }
        finally
        {
            FileUtilities.TryDeleteFile(installerPath);
        }

        return false;
    }

    private async Task<bool> InstallDesktopWithWingetAsync(CancellationToken cancellationToken)
    {
        var winget = ProcessRunner.FindOnPath("winget.exe");
        if (winget is null)
        {
            _log.Write("winget was not found.");
            return false;
        }

        _log.Write($"Trying ChatGPT Desktop with official Store product ID {ChatGPTStoreProductId}.");
        var result = await _processRunner.RunAsync(
            winget,
            [
                "install",
                "--id", ChatGPTStoreProductId,
                "--source", "msstore",
                "--exact",
                "--accept-package-agreements",
                "--accept-source-agreements"
            ],
            cancellationToken: cancellationToken);
        _log.Write($"winget ChatGPT install exit code: {result.ExitCode}");
        var timeout = result.Succeeded ? TimeSpan.FromSeconds(90) : TimeSpan.FromSeconds(20);
        return await WaitForDesktopStateAsync(true, timeout, cancellationToken);
    }

    private async Task<bool> WriteModelCatalogAsync(CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(_paths.SupportDirectory);
        var cliPath = FindCliPath();
        if (cliPath is null)
        {
            _log.Write("Codex CLI was not found, so the model picker restriction was skipped.");
            return false;
        }

        var temporaryHome = Path.Combine(Path.GetTempPath(), $"ai-unc-codex-home-{Guid.NewGuid():N}");
        try
        {
            Directory.CreateDirectory(temporaryHome);
            var result = await _processRunner.RunAsync(
                cliPath,
                ["debug", "models"],
                new Dictionary<string, string> { ["CODEX_HOME"] = temporaryHome },
                cancellationToken);
            if (!result.Succeeded || string.IsNullOrWhiteSpace(result.StandardOutput))
            {
                _log.Write("Codex did not return a model catalog, so the picker restriction was skipped.");
                return false;
            }

            var catalog = JsonNode.Parse(result.StandardOutput)?.AsObject();
            var models = catalog?["models"]?.AsArray();
            if (catalog is null || models is null)
            {
                _log.Write("Codex model catalog did not include a models list.");
                return false;
            }

            var current = new Dictionary<string, JsonObject>(StringComparer.Ordinal);
            foreach (var item in models)
            {
                if (item is JsonObject model && model["slug"]?.GetValue<string>() is { Length: > 0 } slug)
                {
                    current.TryAdd(slug, model);
                }
            }

            JsonObject? template = current.GetValueOrDefault("gpt-5.5") ??
                                   models.OfType<JsonObject>().FirstOrDefault();
            var filtered = new JsonArray();
            foreach (var option in ModelCatalog.Options)
            {
                JsonObject? model = null;
                var synthesized = false;
                if (current.TryGetValue(option.Deployment, out var source))
                {
                    model = source.DeepClone().AsObject();
                }
                else if (option.Deployment.StartsWith("gpt-5.6-", StringComparison.Ordinal) && template is not null)
                {
                    model = template.DeepClone().AsObject();
                    synthesized = true;
                }

                if (model is null)
                {
                    continue;
                }

                model["slug"] = option.Deployment;
                model["display_name"] = option.Label;
                model["description"] = option.Description;
                model["priority"] = filtered.Count;
                if (synthesized || model["supported_reasoning_levels"] is null)
                {
                    SetReasoningProperties(model, option);
                }
                else if (option.DefaultReasoning is not null)
                {
                    model["default_reasoning_level"] = option.DefaultReasoning;
                }

                if (synthesized)
                {
                    model.Remove("availability_nux");
                    model.Remove("upgrade");
                }

                if (model["default_reasoning_level"] is null ||
                    model["supported_reasoning_levels"] is not JsonArray)
                {
                    _log.Write(
                        $"Skipping {option.Deployment} because the current Codex catalog does not describe its reasoning levels.");
                    continue;
                }

                filtered.Add(model);
            }

            var containsDefault = filtered
                .OfType<JsonObject>()
                .Any(model =>
                    string.Equals(
                        model["slug"]?.GetValue<string>(),
                        ModelCatalog.DefaultModel,
                        StringComparison.Ordinal));
            if (filtered.Count == 0 || !containsDefault)
            {
                _log.Write("Filtered model catalog did not contain the default model, so the picker restriction was skipped.");
                return false;
            }

            catalog["fetched_at"] = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ");
            catalog["models"] = filtered;
            catalog["source"] = "AI @ UNC ChatGPT Installer filtered from Codex catalog";
            var json = catalog.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) + Environment.NewLine;
            FileUtilities.WriteAllTextAtomic(_paths.ModelCatalogPath, json);
            _log.Write($"Wrote UNC model catalog at {_paths.ModelCatalogPath}.");
            return true;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _log.Write($"Could not write model catalog, so the picker restriction was skipped: {ex.Message}");
            return false;
        }
        finally
        {
            FileUtilities.TryDeleteDirectory(temporaryHome);
        }
    }

    private static void SetReasoningProperties(JsonObject model, ModelOption option)
    {
        if (option.CatalogReasoning.Length == 0)
        {
            return;
        }

        var levels = new JsonArray();
        foreach (var effort in option.CatalogReasoning)
        {
            levels.Add(new JsonObject
            {
                ["effort"] = effort,
                ["description"] = ModelCatalog.ReasoningDescription(effort).TrimEnd('.')
            });
        }

        model["default_reasoning_level"] = option.DefaultReasoning;
        model["supported_reasoning_levels"] = levels;
    }

    private void BackupConfig()
    {
        Directory.CreateDirectory(_paths.CodexHome);
        if (!File.Exists(_paths.ConfigPath))
        {
            _log.Write("No existing Codex config was found.");
            return;
        }

        var backupPath = FileUtilities.UniqueTimestampedPath(_paths.CodexHome, "config.toml.backup");
        File.Copy(_paths.ConfigPath, backupPath, true);
        _log.Write($"Backed up existing Codex config to {backupPath}.");
    }

    private void SaveApiKey(string apiKey)
    {
        if (OperatingSystem.IsWindows())
        {
            Environment.SetEnvironmentVariable(AppPaths.EnvironmentKey, apiKey, EnvironmentVariableTarget.User);
        }
        Environment.SetEnvironmentVariable(AppPaths.EnvironmentKey, apiKey, EnvironmentVariableTarget.Process);
        NativeMethods.BroadcastEnvironmentChange();
        _log.Write($"{AppPaths.EnvironmentKey} was saved as a user environment variable.");
    }

    private void RemoveApiKey()
    {
        if (OperatingSystem.IsWindows())
        {
            Environment.SetEnvironmentVariable(AppPaths.EnvironmentKey, null, EnvironmentVariableTarget.User);
        }
        Environment.SetEnvironmentVariable(AppPaths.EnvironmentKey, null, EnvironmentVariableTarget.Process);
        NativeMethods.BroadcastEnvironmentChange();
        _log.Write($"{AppPaths.EnvironmentKey} was removed from the user environment.");
    }

    private static bool HasUserEnvironmentApiKey() =>
        OperatingSystem.IsWindows() &&
        !string.IsNullOrWhiteSpace(
            Environment.GetEnvironmentVariable(
                AppPaths.EnvironmentKey,
                EnvironmentVariableTarget.User));

    private bool HasPlaintextConfigToken()
    {
        if (!File.Exists(_paths.ConfigPath))
        {
            return false;
        }

        try
        {
            return PlaintextTokenRegex().IsMatch(File.ReadAllText(_paths.ConfigPath));
        }
        catch
        {
            return false;
        }
    }

    private string? FindCliPath()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var candidates = new[]
        {
            ProcessRunner.FindOnPath("codex.exe", "codex.cmd", "codex"),
            Path.Combine(localAppData, "Programs", "OpenAI", "Codex", "bin", "codex.exe"),
            Path.Combine(localAppData, "Programs", "OpenAI", "Codex", "bin", "codex.cmd"),
            Path.Combine(localAppData, "Microsoft", "WindowsApps", "codex.exe"),
            Path.Combine(_paths.UserProfile, ".local", "bin", "codex.exe"),
            Path.Combine(_paths.UserProfile, ".local", "bin", "codex")
        };
        return candidates.FirstOrDefault(candidate =>
            !string.IsNullOrWhiteSpace(candidate) && File.Exists(candidate));
    }

    private async Task<string?> GetCliVersionAsync(string? cliPath, CancellationToken cancellationToken)
    {
        if (cliPath is null)
        {
            return null;
        }

        foreach (var arguments in new[] { new[] { "--version" }, ["version"], ["-V"] })
        {
            try
            {
                var result = await _processRunner.RunAsync(cliPath, arguments, cancellationToken: cancellationToken);
                var firstLine = result.StandardOutput
                    .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                    .FirstOrDefault();
                if (result.Succeeded && firstLine is not null)
                {
                    return firstLine;
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch
            {
                // Try the next version form.
            }
        }

        return null;
    }

    private async Task DownloadFileAsync(string url, string destination, CancellationToken cancellationToken)
    {
        using var response = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();
        await using var source = await response.Content.ReadAsStreamAsync(cancellationToken);
        await using var target = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        await source.CopyToAsync(target, cancellationToken);
    }

    private async Task<bool> WaitForDesktopStateAsync(
        bool installed,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        var deadline = DateTime.UtcNow + timeout;
        do
        {
            if (DesktopAppLocator.Detect().PackageInstalled == installed)
            {
                return true;
            }

            await Task.Delay(TimeSpan.FromSeconds(2), cancellationToken);
        } while (DateTime.UtcNow < deadline);

        return DesktopAppLocator.Detect().PackageInstalled == installed;
    }

    private async Task<bool> WaitForCliAsync(TimeSpan timeout, CancellationToken cancellationToken)
    {
        var deadline = DateTime.UtcNow + timeout;
        do
        {
            if (FindCliPath() is not null)
            {
                return true;
            }
            await Task.Delay(TimeSpan.FromSeconds(2), cancellationToken);
        } while (DateTime.UtcNow < deadline);

        return FindCliPath() is not null;
    }

    private string EnsureWorkspace()
    {
        var workspace = _paths.GetWorkspacePath();
        Directory.CreateDirectory(workspace);
        return workspace;
    }

    private string RestoreOrRemoveConfigForUninstall()
    {
        Directory.CreateDirectory(_paths.CodexHome);
        var originalBackup = Directory.EnumerateFiles(_paths.CodexHome, "config.toml.backup.*")
            .OrderBy(File.GetLastWriteTimeUtc)
            .FirstOrDefault();
        if (originalBackup is not null)
        {
            FileUtilities.CopyAtomic(originalBackup, _paths.ConfigPath);
            return $"Restored Codex config from {Path.GetFileName(originalBackup)}.";
        }

        if (File.Exists(_paths.ConfigPath))
        {
            var removedPath = FileUtilities.UniqueTimestampedPath(_paths.CodexHome, "config.toml.removed");
            File.Move(_paths.ConfigPath, removedPath);
            return $"Moved current config to {removedPath}.";
        }

        return "No Codex config was present.";
    }

    private string? GetConfiguredValue(string name)
    {
        if (!File.Exists(_paths.ConfigPath))
        {
            return null;
        }

        var pattern = $@"(?m)^\s*{Regex.Escape(name)}\s*=\s*""([^""]+)""";
        var match = Regex.Match(File.ReadAllText(_paths.ConfigPath), pattern);
        return match.Success ? match.Groups[1].Value : null;
    }

    private static void RestrictFileToCurrentUser(string path)
    {
        if (!OperatingSystem.IsWindows())
        {
            return;
        }

        var currentUser = WindowsIdentity.GetCurrent().User
            ?? throw new InvalidOperationException("Could not determine the current Windows user.");
        var security = new FileSecurity();
        security.SetOwner(currentUser);
        security.SetAccessRuleProtection(true, false);
        security.AddAccessRule(new FileSystemAccessRule(
            currentUser,
            FileSystemRights.FullControl,
            AccessControlType.Allow));
        new FileInfo(path).SetAccessControl(security);
    }

    private static string TomlEscape(string value) =>
        value.Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("\"", "\\\"", StringComparison.Ordinal)
            .Replace("\r", string.Empty, StringComparison.Ordinal)
            .Replace("\n", "\\n", StringComparison.Ordinal);

    private static string TomlUnescape(string value) =>
        value.Replace("\\n", "\n", StringComparison.Ordinal)
            .Replace("\\\"", "\"", StringComparison.Ordinal)
            .Replace("\\\\", "\\", StringComparison.Ordinal);

    private static string PowerShellQuote(string value) => $"'{value.Replace("'", "''", StringComparison.Ordinal)}'";

    [GeneratedRegex(@"(?m)^\s*experimental_bearer_token\s*=\s*""((?:\\.|[^""])*)""")]
    private static partial Regex PlaintextTokenRegex();
}

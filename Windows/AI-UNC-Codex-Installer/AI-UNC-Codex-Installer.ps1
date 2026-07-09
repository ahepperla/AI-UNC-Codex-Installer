#requires -version 5.1
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:AppName = 'AI @ UNC Codex Installer'
$script:EnvKey = 'UNC_AZURE_API_KEY'
$script:DefaultModel = 'gpt-5.5'
$script:ModelOptions = @(
    [pscustomobject]@{ Deployment = 'gpt-5.5'; Label = 'gpt-5.5 Recommended'; Reasoning = @('minimal', 'low', 'medium', 'high', 'xhigh'); DefaultReasoning = 'medium' },
    [pscustomobject]@{ Deployment = 'gpt-5.4'; Label = 'gpt-5.4'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-5.4-mini'; Label = 'gpt-5.4-mini'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-5.4-nano'; Label = 'gpt-5.4-nano'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-5.3-codex'; Label = 'gpt-5.3-codex'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-5.2'; Label = 'gpt-5.2'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-5.1'; Label = 'gpt-5.1'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-5'; Label = 'gpt-5'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-5-mini'; Label = 'gpt-5-mini'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-5-nano'; Label = 'gpt-5-nano'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-4.1'; Label = 'gpt-4.1'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-4.1-mini'; Label = 'gpt-4.1-mini'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-4.1-nano'; Label = 'gpt-4.1-nano'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-4o'; Label = 'gpt-4o'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'gpt-4o-mini'; Label = 'gpt-4o-mini'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'o1'; Label = 'o1'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'o1-preview'; Label = 'o1-preview'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'o1-mini'; Label = 'o1-mini'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'o3-mini'; Label = 'o3-mini'; Reasoning = @(); DefaultReasoning = $null },
    [pscustomobject]@{ Deployment = 'chat'; Label = 'chat (gpt-4.1-mini)'; Reasoning = @(); DefaultReasoning = $null }
)
$script:Model = $script:DefaultModel
$script:ModelDisplayMap = @{}
foreach ($modelOption in $script:ModelOptions) {
    $script:ModelDisplayMap[$modelOption.Label] = $modelOption
}
$script:ReasoningEffortOptions = @('minimal', 'low', 'medium', 'high', 'xhigh')
$script:DefaultReasoningEffort = 'medium'
$script:EndpointBaseUrl = 'https://azureaiapi.cloud.unc.edu/openai/v1'
$script:ResponsesUrl = 'https://azureaiapi.cloud.unc.edu/openai/v1/responses'
$script:CodexDownloadUrl = 'https://openai.com/codex/'
$script:CodexWindowsStoreUrl = 'https://get.microsoft.com/installer/download/9PLM9XGG6VKS?cid=website_cta_psi'
$script:StandaloneInstallerUrl = 'https://chatgpt.com/codex/install.ps1'
$script:CodexHomeEnvironmentVariable = 'CODEX_HOME'
$script:DefaultCodexHome = Join-Path $env:USERPROFILE '.codex'
$script:CodexHomeSource = 'default'
$script:CodexHome = $script:DefaultCodexHome
$codexHomeFromEnvironment = [Environment]::GetEnvironmentVariable($script:CodexHomeEnvironmentVariable, 'Process')
if (-not $codexHomeFromEnvironment -or $codexHomeFromEnvironment.Trim().Length -eq 0) {
    $codexHomeFromEnvironment = [Environment]::GetEnvironmentVariable($script:CodexHomeEnvironmentVariable, 'User')
}
if ($codexHomeFromEnvironment -and $codexHomeFromEnvironment.Trim().Length -gt 0) {
    $expandedCodexHome = [Environment]::ExpandEnvironmentVariables($codexHomeFromEnvironment.Trim())
    if (-not [System.IO.Path]::IsPathRooted($expandedCodexHome)) {
        $expandedCodexHome = Join-Path $env:USERPROFILE $expandedCodexHome
    }
    $script:CodexHome = [System.IO.Path]::GetFullPath($expandedCodexHome)
    $script:CodexHomeSource = $script:CodexHomeEnvironmentVariable
}
$env:CODEX_HOME = $script:CodexHome
$script:SupportDirectory = Join-Path $script:CodexHome 'unc'
$script:ConfigPath = Join-Path $script:CodexHome 'config.toml'
$script:LogPath = Join-Path $script:SupportDirectory 'windows-installer.log'
$script:ReceiptPath = Join-Path $script:SupportDirectory 'setup-receipt.txt'
$script:WorkspaceSettingPath = Join-Path $script:SupportDirectory 'workspace-path.txt'
$script:WorkspacePath = $null

$script:Form = $null
$script:LogBox = $null
$script:KeyTextBox = $null
$script:RecommendationWorkspacePathLabel = $null
$script:WorkspacePathLabel = $null
$script:PlaintextConfigCheckBox = $null
$script:ModelComboBox = $null
$script:ReasoningEffortComboBox = $null
$script:LaunchAfterSetupCheckBox = $null
$script:CodexStatusLabel = $null
$script:OpenDesktopButton = $null
$script:OpenCliButton = $null
$script:InstallButton = $null
$script:AdvancedGroupBox = $null
$script:AdvancedToggleButton = $null
$script:LogLabel = $null
$script:ActionButtons = @()

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-DefaultCodexWorkspacePath {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    if (-not $documents -or $documents.Trim().Length -eq 0) {
        $documents = Join-Path $env:USERPROFILE 'Documents'
    }

    return Join-Path $documents 'Codex'
}

function Get-CodexWorkspacePath {
    try {
        if (Test-Path -LiteralPath $script:WorkspaceSettingPath) {
            $saved = (Get-Content -Path $script:WorkspaceSettingPath -Raw -ErrorAction Stop).Trim()
            if ($saved.Length -gt 0) {
                return [Environment]::ExpandEnvironmentVariables($saved)
            }
        }
    } catch {
        # Fall back to the default workspace if the saved setting cannot be read.
    }

    return Get-DefaultCodexWorkspacePath
}

function Set-CodexWorkspacePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    Ensure-Directory -Path $script:SupportDirectory
    Set-Content -Path $script:WorkspaceSettingPath -Value $expanded -Encoding UTF8
    $script:WorkspacePath = $expanded
    Update-WorkspaceDisplay
    Write-Log "Codex workspace set to $script:WorkspacePath."
}

function Reset-CodexWorkspacePath {
    if (Test-Path -LiteralPath $script:WorkspaceSettingPath) {
        Remove-Item -LiteralPath $script:WorkspaceSettingPath -Force
    }

    $script:WorkspacePath = Get-CodexWorkspacePath
    Update-WorkspaceDisplay
    Write-Log "Codex workspace reset to $script:WorkspacePath."
}

function Ensure-CodexWorkspace {
    $script:WorkspacePath = Get-CodexWorkspacePath
    Ensure-Directory -Path $script:WorkspacePath
    Update-WorkspaceDisplay
    Write-Log "Codex workspace ready at $script:WorkspacePath."
    return $script:WorkspacePath
}

function Update-WorkspaceDisplay {
    $path = if ($script:WorkspacePath) { $script:WorkspacePath } else { Get-CodexWorkspacePath }

    if ($script:RecommendationWorkspacePathLabel -ne $null) {
        $script:RecommendationWorkspacePathLabel.Text = $path
    }

    if ($script:WorkspacePathLabel -ne $null) {
        $script:WorkspacePathLabel.Text = $path
    }
}

function Choose-CodexWorkspace {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the folder Codex should use as its workspace.'
    $dialog.ShowNewFolderButton = $true

    $currentPath = if ($script:WorkspacePath) { $script:WorkspacePath } else { Get-CodexWorkspacePath }
    if (Test-Path -LiteralPath $currentPath) {
        $dialog.SelectedPath = $currentPath
    } else {
        $dialog.SelectedPath = Split-Path -Parent $currentPath
    }

    if ($dialog.ShowDialog($script:Form) -eq [System.Windows.Forms.DialogResult]::OK) {
        Set-CodexWorkspacePath -Path $dialog.SelectedPath
        Ensure-CodexWorkspace | Out-Null
    }
}

function Open-CodexWorkspace {
    $workspace = Ensure-CodexWorkspace
    Start-Process explorer.exe -ArgumentList ('"{0}"' -f $workspace)
}

function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message)

    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message

    if ($script:LogBox -ne $null) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
        $script:LogBox.SelectionStart = $script:LogBox.TextLength
        $script:LogBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    try {
        Ensure-Directory -Path $script:SupportDirectory
        Add-Content -Path $script:LogPath -Value $line -Encoding UTF8
    } catch {
        # Logging must never interrupt setup.
    }
}

function Show-Info {
    param([Parameter(Mandatory = $true)][string]$Message)
    [System.Windows.Forms.MessageBox]::Show($Message, $script:AppName, 'OK', 'Information') | Out-Null
}

function Show-Warning {
    param([Parameter(Mandatory = $true)][string]$Message)
    [System.Windows.Forms.MessageBox]::Show($Message, $script:AppName, 'OK', 'Warning') | Out-Null
}

function Confirm-Action {
    param([Parameter(Mandatory = $true)][string]$Message)
    $result = [System.Windows.Forms.MessageBox]::Show($Message, $script:AppName, 'YesNo', 'Question')
    return $result -eq [System.Windows.Forms.DialogResult]::Yes
}

function Confirm-CodexInstallDuration {
    $message = "Installing Codex can take several minutes.`r`n`r`nThe installer may use winget, Microsoft Store, or the standalone CLI installer. Keep AI @ UNC Codex Installer open until the log says setup is complete or a download page opens.`r`n`r`nStart Codex install now?"
    return Confirm-Action -Message $message
}

function Get-ModelOptionByDeployment {
    param([Parameter(Mandatory = $true)][string]$Deployment)

    foreach ($modelOption in $script:ModelOptions) {
        if ($modelOption.Deployment -eq $Deployment) {
            return $modelOption
        }
    }

    return $script:ModelOptions[0]
}

function Get-SelectedModelOption {
    if ($script:ModelComboBox -ne $null -and $script:ModelComboBox.SelectedItem) {
        $label = [string]$script:ModelComboBox.SelectedItem
        if ($script:ModelDisplayMap.ContainsKey($label)) {
            return $script:ModelDisplayMap[$label]
        }
    }

    return Get-ModelOptionByDeployment -Deployment $script:DefaultModel
}

function Get-SelectedModelDeployment {
    return (Get-SelectedModelOption).Deployment
}

function Update-ReasoningOptionsForSelectedModel {
    if ($script:ReasoningEffortComboBox -eq $null) {
        return
    }

    $modelOption = Get-SelectedModelOption
    $script:ReasoningEffortComboBox.Items.Clear()

    if ($modelOption.Reasoning.Count -gt 0) {
        foreach ($effort in $modelOption.Reasoning) {
            [void]$script:ReasoningEffortComboBox.Items.Add($effort)
        }
        $defaultEffort = if ($modelOption.DefaultReasoning) { $modelOption.DefaultReasoning } else { $modelOption.Reasoning[0] }
        $script:ReasoningEffortComboBox.SelectedItem = $defaultEffort
        $script:ReasoningEffortComboBox.Enabled = $true
    } else {
        [void]$script:ReasoningEffortComboBox.Items.Add('model default')
        $script:ReasoningEffortComboBox.SelectedItem = 'model default'
        $script:ReasoningEffortComboBox.Enabled = $false
    }
}

function Get-SelectedReasoningEffort {
    $modelOption = Get-SelectedModelOption
    if ($modelOption.Reasoning.Count -eq 0) {
        return $null
    }

    if ($script:ReasoningEffortComboBox -ne $null -and $script:ReasoningEffortComboBox.SelectedItem) {
        $value = [string]$script:ReasoningEffortComboBox.SelectedItem
        if ($modelOption.Reasoning -contains $value) {
            return $value
        }
    }

    return $modelOption.DefaultReasoning
}

function Get-ConfiguredModel {
    try {
        if (Test-Path -LiteralPath $script:ConfigPath) {
            $content = Get-Content -Path $script:ConfigPath -Raw -ErrorAction Stop
            $match = [regex]::Match($content, '(?m)^\s*model\s*=\s*"([^"]+)"')
            if ($match.Success) {
                return $match.Groups[1].Value
            }
        }
    } catch {
        # Fall back to the selected/default model if config cannot be read.
    }

    return Get-SelectedModelDeployment
}

function Get-ConfiguredReasoningEffort {
    try {
        if (Test-Path -LiteralPath $script:ConfigPath) {
            $content = Get-Content -Path $script:ConfigPath -Raw -ErrorAction Stop
            $match = [regex]::Match($content, '(?m)^\s*model_reasoning_effort\s*=\s*"([^"]+)"')
            if ($match.Success) {
                return $match.Groups[1].Value
            }
        }
    } catch {
        # Fall back to the selected/default effort if config cannot be read.
    }

    $selected = Get-SelectedReasoningEffort
    if ($selected) {
        return $selected
    }

    return 'model default'
}

function Invoke-GuiAction {
    param([Parameter(Mandatory = $true)][scriptblock]$Action)

    foreach ($button in $script:ActionButtons) {
        $button.Enabled = $false
    }
    $script:Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    try {
        & $Action
    } catch {
        $message = $_.Exception.Message
        Write-Log "ERROR: $message"
        Show-Warning -Message $message
    } finally {
        $script:Form.Cursor = [System.Windows.Forms.Cursors]::Default
        foreach ($button in $script:ActionButtons) {
            $button.Enabled = $true
        }
    }
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    Write-Log ("Running: {0} {1}" -f $FilePath, ($Arguments -join ' '))

    $escapedArguments = foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            '"' + $argument.Replace('"', '\"') + '"'
        } else {
            $argument
        }
    }

    $escapedFilePath = if ($FilePath -match '[\s"]') {
        '"' + $FilePath.Replace('"', '\"') + '"'
    } else {
        $FilePath
    }

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    if ($extension -eq '.cmd' -or $extension -eq '.bat') {
        $processInfo.FileName = $env:ComSpec
        $processInfo.Arguments = ('/d /c {0} {1}' -f $escapedFilePath, ($escapedArguments -join ' ')).Trim()
    } elseif ($extension -eq '.ps1') {
        $processInfo.FileName = 'powershell.exe'
        $processInfo.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File {0} {1}' -f $escapedFilePath, ($escapedArguments -join ' ')).Trim()
    } else {
        $processInfo.FileName = $FilePath
        $processInfo.Arguments = ($escapedArguments -join ' ')
    }
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $output = ($standardOutput + [Environment]::NewLine + $standardError).Trim()
    $exitCode = $process.ExitCode
    $trimmed = $output.Trim()
    if ($trimmed.Length -gt 0) {
        Write-Log $trimmed
    }

    return [pscustomobject]@{
        ExitCode = [int]$exitCode
        Output = $output
        Succeeded = ([int]$exitCode -eq 0)
    }
}

function Get-CodexCliPath {
    $paths = New-Object System.Collections.Generic.List[string]

    foreach ($name in @('codex.exe', 'codex.cmd', 'codex.ps1', 'codex')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command -ne $null -and $command.Source) {
            $paths.Add($command.Source)
        }
    }

    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ($localAppData) {
        $paths.Add((Join-Path $localAppData 'Programs\OpenAI\Codex\bin\codex.exe'))
        $paths.Add((Join-Path $localAppData 'Programs\OpenAI\Codex\bin\codex.cmd'))
        $paths.Add((Join-Path $localAppData 'Microsoft\WindowsApps\codex.exe'))
    }

    foreach ($path in ($paths | Select-Object -Unique)) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }

    return $null
}

function Get-CodexVersion {
    param([string]$CliPath)

    if (-not $CliPath) {
        return $null
    }

    foreach ($args in @(@('--version'), @('version'), @('-V'))) {
        try {
            $result = Invoke-ExternalCommand -FilePath $CliPath -Arguments $args
            $firstLine = (($result.Output -split "`r?`n") | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First 1)
            if ($result.Succeeded -and $firstLine) {
                return $firstLine.Trim()
            }
        } catch {
            Write-Log "Could not read Codex version with arguments '$($args -join ' ')'."
        }
    }

    return $null
}

function Get-CodexStartApp {
    try {
        return Get-StartApps | Where-Object { $_.Name -like '*Codex*' } | Select-Object -First 1
    } catch {
        return $null
    }
}

function Get-CodexDetection {
    $cliPath = Get-CodexCliPath
    $app = Get-CodexStartApp
    $version = Get-CodexVersion -CliPath $cliPath

    return [pscustomobject]@{
        CliPath = $cliPath
        DesktopAppName = $(if ($app) { $app.Name } else { $null })
        DesktopAppId = $(if ($app) { $app.AppID } else { $null })
        Version = $version
        Installed = (($cliPath -ne $null) -or ($app -ne $null))
    }
}

function Get-CodexDetectionStatusText {
    param([Parameter(Mandatory = $false)][object]$Detection)

    if ($Detection -eq $null -or -not $Detection.Installed) {
        return 'Codex status: not detected yet.'
    }

    $parts = @()
    if ($Detection.DesktopAppName) {
        $parts += 'Desktop app detected'
    }
    if ($Detection.CliPath) {
        $parts += 'CLI detected'
    }

    if ($parts.Count -eq 0) {
        return 'Codex status: not detected yet.'
    }

    return ('Codex status: {0}.' -f ($parts -join '; '))
}

function Update-CodexActionButtons {
    param([Parameter(Mandatory = $false)][object]$Detection)

    if ($Detection -eq $null) {
        $Detection = Get-CodexDetection
    }

    $hasDesktop = ($Detection -ne $null -and $Detection.DesktopAppId)
    $hasCli = ($Detection -ne $null -and $Detection.CliPath)

    if ($script:CodexStatusLabel -ne $null) {
        $script:CodexStatusLabel.Text = Get-CodexDetectionStatusText -Detection $Detection
    }

    if ($script:OpenDesktopButton -ne $null) {
        $script:OpenDesktopButton.Visible = [bool]$hasDesktop
        $script:OpenDesktopButton.Enabled = [bool]$hasDesktop
    }

    if ($script:OpenCliButton -ne $null) {
        $script:OpenCliButton.Visible = [bool]$hasCli
        $script:OpenCliButton.Enabled = [bool]$hasCli
    }

    if ($script:InstallButton -ne $null) {
        if ($Detection -ne $null -and $Detection.Installed) {
            $script:InstallButton.Text = 'Reinstall Codex'
        } else {
            $script:InstallButton.Text = 'Install Codex'
        }
    }
}

function Show-CodexDetection {
    $detection = Get-CodexDetection
    Write-Log 'Codex detection results:'
    Write-Log ('  Installed: {0}' -f $(if ($detection.Installed) { 'yes' } else { 'no' }))
    Write-Log ('  CLI path: {0}' -f $(if ($detection.CliPath) { $detection.CliPath } else { 'not found' }))
    Write-Log ('  Desktop app: {0}' -f $(if ($detection.DesktopAppName) { $detection.DesktopAppName } else { 'not found' }))
    Write-Log ('  Version: {0}' -f $(if ($detection.Version) { $detection.Version } else { 'unknown' }))
    Update-CodexActionButtons -Detection $detection
    return $detection
}

function Install-Codex {
    param([bool]$Force = $false)

    $detection = Get-CodexDetection
    if ($detection.Installed -and -not $Force) {
        Write-Log 'Codex is already installed.'
        return $true
    }

    if ($detection.Installed -and $Force) {
        Write-Log 'Codex is already installed. Running the installer again because reinstall was requested.'
    }

    $winget = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
    if ($winget -ne $null) {
        Write-Log 'Attempting Codex install with winget.'
        $wingetResult = Invoke-ExternalCommand -FilePath $winget.Source -Arguments @(
            'install',
            'Codex',
            '-s',
            'msstore',
            '--accept-package-agreements',
            '--accept-source-agreements'
        )

        $detection = Get-CodexDetection
        if ($wingetResult.Succeeded -or $detection.Installed) {
            Write-Log 'Codex installation is available after winget.'
            return $true
        }

        Write-Log 'winget did not complete Codex installation by name. Trying Microsoft Store product ID.'
        $wingetStoreIdResult = Invoke-ExternalCommand -FilePath $winget.Source -Arguments @(
            'install',
            '--id',
            '9PLM9XGG6VKS',
            '-s',
            'msstore',
            '--accept-package-agreements',
            '--accept-source-agreements'
        )

        $detection = Get-CodexDetection
        if ($wingetStoreIdResult.Succeeded -or $detection.Installed) {
            Write-Log 'Codex installation is available after winget Store product ID install.'
            return $true
        }

        Write-Log 'winget did not complete Codex installation.'
    } else {
        Write-Log 'winget was not found. Trying the standalone CLI installer.'
    }

    try {
        Write-Log 'Attempting standalone Codex CLI installer.'
        $previousNonInteractive = $env:CODEX_NON_INTERACTIVE
        $env:CODEX_NON_INTERACTIVE = '1'
        try {
            $installer = Invoke-WebRequest -Uri $script:StandaloneInstallerUrl -UseBasicParsing -TimeoutSec 60
            Invoke-Expression $installer.Content
        } finally {
            $env:CODEX_NON_INTERACTIVE = $previousNonInteractive
        }

        $localBin = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\OpenAI\Codex\bin'
        if (Test-Path -LiteralPath $localBin) {
            $env:Path = "$localBin;$env:Path"
        }

        $detection = Get-CodexDetection
        if ($detection.Installed) {
            Write-Log 'Codex installation is available after standalone installer.'
            return $true
        }
    } catch {
        Write-Log ('Standalone installer failed: {0}' -f $_.Exception.Message)
    }

    Write-Log 'Automatic installation did not finish. Opening Codex download page.'
    Start-Process $script:CodexDownloadUrl
    Start-Process $script:CodexWindowsStoreUrl
    return $false
}

function Install-CodexWithWarning {
    param([bool]$Force = $false)

    $detection = Get-CodexDetection
    if ($detection.Installed -and -not $Force) {
        return (Install-Codex)
    }

    if (-not (Confirm-CodexInstallDuration)) {
        Write-Log 'Codex install cancelled before starting.'
        return $null
    }

    Write-Log 'Codex install may take several minutes. Keep this installer open.'
    return (Install-Codex -Force $Force)
}

function Backup-CodexConfig {
    Ensure-Directory -Path $script:CodexHome

    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        Write-Log 'No existing Codex config was found.'
        return $null
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupPath = Join-Path $script:CodexHome "config.toml.backup.$stamp"
    Copy-Item -LiteralPath $script:ConfigPath -Destination $backupPath -Force
    Write-Log "Backed up existing Codex config to $backupPath."
    return $backupPath
}

function ConvertTo-TomlString {
    param([Parameter(Mandatory = $true)][string]$Value)

    return $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", '\n')
}

function ConvertFrom-TomlString {
    param([Parameter(Mandatory = $true)][string]$Value)

    return $Value.Replace('\n', "`n").Replace('\"', '"').Replace('\\', '\')
}

function ConvertTo-PowerShellSingleQuotedString {
    param([Parameter(Mandatory = $true)][string]$Value)

    return "'" + $Value.Replace("'", "''") + "'"
}

function Broadcast-EnvironmentChanged {
    if (-not ('UncCodexNativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class UncCodexNativeMethods
{
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        UInt32 Msg,
        UIntPtr wParam,
        string lParam,
        UInt32 fuFlags,
        UInt32 uTimeout,
        out UIntPtr lpdwResult);
}
'@
    }

    try {
        $result = [UIntPtr]::Zero
        [UncCodexNativeMethods]::SendMessageTimeout(
            [IntPtr]0xffff,
            0x001A,
            [UIntPtr]::Zero,
            'Environment',
            0x0002,
            5000,
            [ref]$result
        ) | Out-Null
        Write-Log 'Broadcasted Windows environment variable change.'
    } catch {
        Write-Log ('Could not broadcast environment change: {0}' -f $_.Exception.Message)
    }
}

function Save-ApiKeyToUserEnvironment {
    param([Parameter(Mandatory = $true)][string]$ApiKey)

    [Environment]::SetEnvironmentVariable($script:EnvKey, $ApiKey, 'User')
    Set-Item -Path "Env:\$($script:EnvKey)" -Value $ApiKey
    Broadcast-EnvironmentChanged
    Write-Log ('{0} was saved as a user environment variable.' -f $script:EnvKey)
}

function Write-CodexConfig {
    param(
        [Parameter(Mandatory = $true)][string]$ApiKey,
        [Parameter(Mandatory = $true)][bool]$UsePlaintextConfig
    )

    Backup-CodexConfig | Out-Null
    $selectedModel = Get-SelectedModelDeployment
    $script:Model = $selectedModel
    $quotedModel = ConvertTo-TomlString -Value $selectedModel
    $reasoningEffort = Get-SelectedReasoningEffort
    $configLines = @(
        ('model = "{0}"' -f $quotedModel),
        'model_provider = "azure"'
    )

    if ($reasoningEffort) {
        $configLines += ('model_reasoning_effort = "{0}"' -f (ConvertTo-TomlString -Value $reasoningEffort))
    }

    $configLines += ''
    $configLines += '[model_providers.azure]'
    $configLines += 'name = "Azure OpenAI"'
    $configLines += ('base_url = "{0}"' -f (ConvertTo-TomlString -Value $script:EndpointBaseUrl))

    if ($UsePlaintextConfig) {
        $quotedKey = ConvertTo-TomlString -Value $ApiKey
        $configLines += ('experimental_bearer_token = "{0}"' -f $quotedKey)
        Write-Log 'Writing Codex config with plaintext bearer token fallback.'
    } else {
        Save-ApiKeyToUserEnvironment -ApiKey $ApiKey
        $configLines += ('env_key = "{0}"' -f (ConvertTo-TomlString -Value $script:EnvKey))
        Write-Log 'Writing Codex config with environment variable authentication.'
    }

    $configLines += 'wire_api = "responses"'
    $content = ($configLines -join [Environment]::NewLine) + [Environment]::NewLine

    Ensure-Directory -Path $script:CodexHome
    Set-Content -Path $script:ConfigPath -Value $content -Encoding UTF8
    $reasoningLabel = if ($reasoningEffort) { $reasoningEffort } else { 'model default' }
    Write-Log "Wrote Codex config at $script:ConfigPath for $selectedModel with reasoning $reasoningLabel."
}

function Get-CurrentApiKey {
    if ($script:KeyTextBox -ne $null) {
        $typed = $script:KeyTextBox.Text.Trim()
        if ($typed.Length -gt 0) {
            return $typed
        }
    }

    $envValue = [Environment]::GetEnvironmentVariable($script:EnvKey, 'User')
    if ($envValue -and $envValue.Trim().Length -gt 0) {
        return $envValue.Trim()
    }

    $plaintextConfigValue = Get-PlaintextBearerTokenFromConfig
    if ($plaintextConfigValue -and $plaintextConfigValue.Trim().Length -gt 0) {
        return $plaintextConfigValue.Trim()
    }

    return $null
}

function Get-PlaintextBearerTokenFromConfig {
    try {
        if (Test-Path -LiteralPath $script:ConfigPath) {
            $content = Get-Content -Path $script:ConfigPath -Raw -ErrorAction Stop
            $match = [regex]::Match($content, '(?m)^\s*experimental_bearer_token\s*=\s*"((?:\\.|[^"])*)"')
            if ($match.Success) {
                return ConvertFrom-TomlString -Value $match.Groups[1].Value
            }
        }
    } catch {
        Write-Log ('Could not read plaintext bearer token from config: {0}' -f $_.Exception.Message)
    }

    return $null
}

function Clear-ApiKeyInput {
    if ($script:KeyTextBox -ne $null) {
        $script:KeyTextBox.Clear()
    }
}

function Test-UncEndpoint {
    param([Parameter(Mandatory = $true)][string]$ApiKey)

    $selectedModel = Get-SelectedModelDeployment
    Write-Log "Testing UNC Azure OpenAI endpoint with $selectedModel."

    $payload = @{
        model = $selectedModel
        input = 'Reply exactly: UNC Codex setup OK'
        store = $false
        background = $false
    } | ConvertTo-Json -Compress

    try {
        $response = Invoke-WebRequest `
            -Uri $script:ResponsesUrl `
            -Method Post `
            -Headers @{ Authorization = "Bearer $ApiKey" } `
            -ContentType 'application/json' `
            -Body $payload `
            -TimeoutSec 30 `
            -UseBasicParsing

        $content = [string]$response.Content
        Write-Log ('Endpoint returned HTTP {0}.' -f [int]$response.StatusCode)

        if ($content -notlike '*UNC Codex setup OK*') {
            Write-Log 'Endpoint responded, but the expected confirmation text was not found.'
            return $false
        }

        Write-Log 'Connection test succeeded.'
        return $true
    } catch {
        $message = $_.Exception.Message
        if ($_.Exception.Response -ne $null) {
            try {
                $statusCode = [int]$_.Exception.Response.StatusCode
                $message = "HTTP $statusCode from endpoint."
            } catch {
                # Keep original message.
            }
        }

        Write-Log "Connection test failed: $message"
        return $false
    }
}

function Save-SetupReceipt {
    param(
        [Parameter(Mandatory = $true)][bool]$EndpointSucceeded,
        [Parameter(Mandatory = $false)][object]$Detection
    )

    Ensure-Directory -Path $script:SupportDirectory
    $configuredModel = Get-ConfiguredModel
    $reasoningEffort = Get-ConfiguredReasoningEffort

    $lines = @(
        'AI @ UNC Codex Installer Setup Receipt',
        ('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
        ('Windows user: {0}' -f $env:USERNAME),
        ('Computer: {0}' -f $env:COMPUTERNAME),
        ('Codex home: {0}' -f $script:CodexHome),
        ('Codex home source: {0}' -f $script:CodexHomeSource),
        ('Config path: {0}' -f $script:ConfigPath),
        ('Codex workspace: {0}' -f $(if ($script:WorkspacePath) { $script:WorkspacePath } else { Get-CodexWorkspacePath })),
        ('Model: {0}' -f $configuredModel),
        ('Reasoning effort: {0}' -f $reasoningEffort),
        ('Environment key: {0}' -f $script:EnvKey),
        ('Endpoint test: {0}' -f $(if ($EndpointSucceeded) { 'succeeded' } else { 'failed or not run' })),
        ('Codex CLI path: {0}' -f $(if ($Detection -and $Detection.CliPath) { $Detection.CliPath } else { 'not found' })),
        ('Codex desktop app: {0}' -f $(if ($Detection -and $Detection.DesktopAppName) { $Detection.DesktopAppName } else { 'not found' })),
        ('Codex version: {0}' -f $(if ($Detection -and $Detection.Version) { $Detection.Version } else { 'unknown' }))
    )

    Set-Content -Path $script:ReceiptPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
    Write-Log "Saved setup receipt at $script:ReceiptPath."
}

function Start-CodexDesktop {
    param([Parameter(Mandatory = $true)][object]$Detection)

    $workspace = Ensure-CodexWorkspace
    Write-Log ('Opening Codex desktop app: {0}' -f $Detection.DesktopAppName)
    Write-Log "Codex workspace is $workspace. Choose that folder in Codex if prompted."
    Start-Process explorer.exe -ArgumentList ('shell:AppsFolder\{0}' -f $Detection.DesktopAppId)
}

function Start-CodexCli {
    param([Parameter(Mandatory = $true)][object]$Detection)

    $workspace = Ensure-CodexWorkspace
    Write-Log "Opening Codex CLI in a new PowerShell window at $workspace."
    $codexHomeValue = ConvertTo-PowerShellSingleQuotedString -Value $script:CodexHome
    $cliPathValue = ConvertTo-PowerShellSingleQuotedString -Value $Detection.CliPath
    $command = '$env:CODEX_HOME = {0}; & {1}' -f $codexHomeValue, $cliPathValue
    Start-Process powershell.exe -WorkingDirectory $workspace -ArgumentList @('-NoExit', '-Command', $command)
}

function Open-CodexDesktop {
    $detection = Get-CodexDetection
    Update-CodexActionButtons -Detection $detection

    if (-not $detection.DesktopAppId) {
        Write-Log 'Codex desktop app was not detected.'
        Show-Warning -Message 'Codex Desktop was not detected on this computer.'
        return
    }

    Start-CodexDesktop -Detection $detection
}

function Open-CodexCli {
    $detection = Get-CodexDetection
    Update-CodexActionButtons -Detection $detection

    if (-not $detection.CliPath) {
        Write-Log 'Codex CLI was not detected.'
        Show-Warning -Message 'Codex CLI was not detected on this computer.'
        return
    }

    Start-CodexCli -Detection $detection
}

function Launch-Codex {
    $detection = Get-CodexDetection
    Update-CodexActionButtons -Detection $detection

    if ($detection.DesktopAppId) {
        Start-CodexDesktop -Detection $detection
        return
    }

    if ($detection.CliPath) {
        Start-CodexCli -Detection $detection
        return
    }

    Write-Log 'Open Codex skipped because Codex Desktop and Codex CLI were not detected.'
}

function Save-SupportReport {
    Ensure-Directory -Path $script:SupportDirectory
    $detection = Get-CodexDetection
    $envSet = [Environment]::GetEnvironmentVariable($script:EnvKey, 'User')
    $configExists = Test-Path -LiteralPath $script:ConfigPath
    $configuredModel = Get-ConfiguredModel
    $reasoningEffort = Get-ConfiguredReasoningEffort
    $reportPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AI-UNC-Codex-Installer-Support-Report.txt'

    $lines = @(
        'AI @ UNC Codex Installer Support Report',
        ('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
        ('Windows user: {0}' -f $env:USERNAME),
        ('Computer: {0}' -f $env:COMPUTERNAME),
        ('OS: {0}' -f ([Environment]::OSVersion.VersionString)),
        ('Codex installed: {0}' -f $(if ($detection.Installed) { 'yes' } else { 'no' })),
        ('Codex CLI path: {0}' -f $(if ($detection.CliPath) { $detection.CliPath } else { 'not found' })),
        ('Codex desktop app: {0}' -f $(if ($detection.DesktopAppName) { $detection.DesktopAppName } else { 'not found' })),
        ('Codex version: {0}' -f $(if ($detection.Version) { $detection.Version } else { 'unknown' })),
        ('Codex home: {0}' -f $script:CodexHome),
        ('Codex home source: {0}' -f $script:CodexHomeSource),
        ('Config path: {0}' -f $script:ConfigPath),
        ('Codex workspace: {0}' -f $(if ($script:WorkspacePath) { $script:WorkspacePath } else { Get-CodexWorkspacePath })),
        ('Model: {0}' -f $configuredModel),
        ('Reasoning effort: {0}' -f $reasoningEffort),
        ('Config exists: {0}' -f $(if ($configExists) { 'yes' } else { 'no' })),
        ('User environment variable set: {0}' -f $(if ($envSet) { 'yes' } else { 'no' })),
        ('Log path: {0}' -f $script:LogPath),
        '',
        'Recent installer log:',
        $(if (Test-Path -LiteralPath $script:LogPath) { Get-Content -Path $script:LogPath -Tail 80 | Out-String } else { 'No log file found.' })
    )

    Set-Content -Path $reportPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
    Write-Log "Saved support report at $reportPath."
    Show-Info -Message "Support report saved to:`n$reportPath"
}

function Reset-Changes {
    if (-not (Confirm-Action -Message 'Reset UNC Codex changes for this Windows user? This removes UNC_AZURE_API_KEY and restores the newest config backup when available.')) {
        return
    }

    [Environment]::SetEnvironmentVariable($script:EnvKey, $null, 'User')
    Remove-Item -Path "Env:\$($script:EnvKey)" -ErrorAction SilentlyContinue
    Broadcast-EnvironmentChanged
    Write-Log ('{0} was removed from the user environment.' -f $script:EnvKey)

    Ensure-Directory -Path $script:CodexHome
    $latestBackup = Get-ChildItem -LiteralPath $script:CodexHome -Filter 'config.toml.backup.*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestBackup -ne $null) {
        if (Test-Path -LiteralPath $script:ConfigPath) {
            $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $resetBackup = Join-Path $script:CodexHome "config.toml.reset-backup.$stamp"
            Copy-Item -LiteralPath $script:ConfigPath -Destination $resetBackup -Force
            Write-Log "Backed up current config to $resetBackup."
        }

        Copy-Item -LiteralPath $latestBackup.FullName -Destination $script:ConfigPath -Force
        Write-Log "Restored Codex config from $($latestBackup.FullName)."
    } elseif (Test-Path -LiteralPath $script:ConfigPath) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $removedPath = Join-Path $script:CodexHome "config.toml.removed.$stamp"
        Move-Item -LiteralPath $script:ConfigPath -Destination $removedPath -Force
        Write-Log "No config backup was available. Moved current config to $removedPath."
    } else {
        Write-Log 'No Codex config was present.'
    }

    Show-Info -Message 'Reset complete.'
}

function Run-FullSetup {
    $apiKey = Get-CurrentApiKey
    if (-not $apiKey) {
        throw 'Paste the UNC Azure OpenAI API key before running setup.'
    }

    Write-Log 'Starting recommended setup.'
    Ensure-CodexWorkspace | Out-Null

    Write-CodexConfig -ApiKey $apiKey -UsePlaintextConfig $script:PlaintextConfigCheckBox.Checked
    Clear-ApiKeyInput

    $endpointSucceeded = Test-UncEndpoint -ApiKey $apiKey
    $detection = Get-CodexDetection
    Update-CodexActionButtons -Detection $detection
    Save-SetupReceipt -EndpointSucceeded $endpointSucceeded -Detection $detection

    if (-not $endpointSucceeded) {
        Show-Warning -Message 'Setup wrote the config, but the endpoint test failed. Check the API key or save a support report.'
        return
    }

    Write-Log 'UNC config and endpoint test are complete.'
    $installed = Install-CodexWithWarning
    if ($null -eq $installed) {
        Write-Log 'Codex install skipped. UNC configuration is complete.'
        Show-Info -Message 'UNC configuration is complete. Codex install was skipped. Use Install Codex or Download under Advanced Options when ready.'
        return
    }

    $detection = Get-CodexDetection
    Update-CodexActionButtons -Detection $detection
    Save-SetupReceipt -EndpointSucceeded $endpointSucceeded -Detection $detection

    if (-not $installed) {
        Show-Info -Message 'UNC configuration is complete. Automatic Codex install did not finish, so the official download page was opened.'
        return
    }

    Write-Log 'Setup complete.'
    if ($script:LaunchAfterSetupCheckBox.Checked) {
        Launch-Codex
    }
    Show-Info -Message 'Setup complete. Codex is configured for the UNC endpoint.'
}

function Configure-Only {
    $apiKey = Get-CurrentApiKey
    if (-not $apiKey) {
        throw 'Paste the UNC Azure OpenAI API key before configuring Codex.'
    }

    Ensure-CodexWorkspace | Out-Null
    Write-CodexConfig -ApiKey $apiKey -UsePlaintextConfig $script:PlaintextConfigCheckBox.Checked
    Clear-ApiKeyInput
    $detection = Get-CodexDetection
    Update-CodexActionButtons -Detection $detection
    Save-SetupReceipt -EndpointSucceeded $false -Detection $detection
    Show-Info -Message 'Codex config was written. Use Test Connection to verify the endpoint.'
}

function Test-ConnectionFromGui {
    $apiKey = Get-CurrentApiKey
    if (-not $apiKey) {
        throw 'Paste the UNC Azure OpenAI API key or run setup first.'
    }

    $ok = Test-UncEndpoint -ApiKey $apiKey
    if ($ok) {
        Show-Info -Message 'Connection test succeeded.'
    } else {
        Show-Warning -Message 'Connection test failed. Check the log and API key.'
    }
}

function Open-DownloadPage {
    Write-Log 'Opening Codex download page.'
    Start-Process $script:CodexDownloadUrl
    Start-Process $script:CodexWindowsStoreUrl
}

function New-Button {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height,
        [System.Windows.Forms.Control]$Parent = $script:Form,
        [bool]$RegisterAction = $true
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.UseVisualStyleBackColor = $true
    $Parent.Controls.Add($button)
    if ($RegisterAction) {
        $script:ActionButtons += $button
    }
    return $button
}

function Set-AdvancedVisible {
    param([Parameter(Mandatory = $true)][bool]$Visible)

    $script:AdvancedGroupBox.Visible = $Visible

    if ($Visible) {
        $script:AdvancedToggleButton.Text = 'Hide Advanced Options'
        $script:LogLabel.Location = New-Object System.Drawing.Point(22, 545)
        $script:LogBox.Location = New-Object System.Drawing.Point(22, 570)
        $script:LogBox.Size = New-Object System.Drawing.Size(780, 98)
    } else {
        $script:AdvancedToggleButton.Text = 'Show Advanced Options'
        $script:LogLabel.Location = New-Object System.Drawing.Point(22, 407)
        $script:LogBox.Location = New-Object System.Drawing.Point(22, 432)
        $script:LogBox.Size = New-Object System.Drawing.Size(780, 236)
    }
}

function Build-Gui {
    $script:WorkspacePath = Get-CodexWorkspacePath

    $script:Form = New-Object System.Windows.Forms.Form
    $script:Form.Text = 'AI @ UNC Codex Installer for Windows'
    $script:Form.Size = New-Object System.Drawing.Size(840, 760)
    $script:Form.MinimumSize = New-Object System.Drawing.Size(840, 760)
    $script:Form.StartPosition = 'CenterScreen'
    $script:Form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'AI @ UNC Codex Installer'
    $title.Location = New-Object System.Drawing.Point(20, 15)
    $title.Size = New-Object System.Drawing.Size(780, 30)
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $script:Form.Controls.Add($title)

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = 'For most users: paste the API key, then click Run Recommended Setup.'
    $subtitle.Location = New-Object System.Drawing.Point(22, 48)
    $subtitle.Size = New-Object System.Drawing.Size(780, 24)
    $subtitle.ForeColor = [System.Drawing.Color]::DimGray
    $script:Form.Controls.Add($subtitle)

    $exit = New-Button -Text 'Exit' -X 728 -Y 18 -Width 74 -Height 28 -RegisterAction $false
    $exit.Add_Click({ $script:Form.Close() })

    $keyLabel = New-Object System.Windows.Forms.Label
    $keyLabel.Text = 'UNC Azure OpenAI API key'
    $keyLabel.Location = New-Object System.Drawing.Point(22, 88)
    $keyLabel.Size = New-Object System.Drawing.Size(250, 22)
    $script:Form.Controls.Add($keyLabel)

    $script:KeyTextBox = New-Object System.Windows.Forms.TextBox
    $script:KeyTextBox.Location = New-Object System.Drawing.Point(22, 113)
    $script:KeyTextBox.Size = New-Object System.Drawing.Size(595, 26)
    $script:KeyTextBox.PasswordChar = '*'
    $script:Form.Controls.Add($script:KeyTextBox)

    $showKey = New-Object System.Windows.Forms.CheckBox
    $showKey.Text = 'Show'
    $showKey.Location = New-Object System.Drawing.Point(630, 115)
    $showKey.Size = New-Object System.Drawing.Size(75, 24)
    $showKey.Add_CheckedChanged({
        if ($showKey.Checked) {
            $script:KeyTextBox.PasswordChar = [char]0
        } else {
            $script:KeyTextBox.PasswordChar = '*'
        }
    })
    $script:Form.Controls.Add($showKey)

    $recommendationBox = New-Object System.Windows.Forms.GroupBox
    $recommendationBox.Text = 'Recommended setup'
    $recommendationBox.Location = New-Object System.Drawing.Point(22, 150)
    $recommendationBox.Size = New-Object System.Drawing.Size(780, 205)
    $script:Form.Controls.Add($recommendationBox)

    $recommendationText = New-Object System.Windows.Forms.Label
    $recommendationText.Text = 'Saves the UNC API key, writes the recommended config, tests the endpoint, then offers Codex install or open actions.'
    $recommendationText.Location = New-Object System.Drawing.Point(16, 25)
    $recommendationText.Size = New-Object System.Drawing.Size(520, 42)
    $recommendationText.ForeColor = [System.Drawing.Color]::DimGray
    $recommendationBox.Controls.Add($recommendationText)

    $modelLabel = New-Object System.Windows.Forms.Label
    $modelLabel.Text = 'Model:'
    $modelLabel.Location = New-Object System.Drawing.Point(16, 76)
    $modelLabel.Size = New-Object System.Drawing.Size(74, 22)
    $recommendationBox.Controls.Add($modelLabel)

    $script:ModelComboBox = New-Object System.Windows.Forms.ComboBox
    $script:ModelComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $script:ModelComboBox.Location = New-Object System.Drawing.Point(92, 73)
    $script:ModelComboBox.Size = New-Object System.Drawing.Size(208, 24)
    foreach ($modelOption in $script:ModelOptions) {
        [void]$script:ModelComboBox.Items.Add($modelOption.Label)
    }
    $script:ModelComboBox.SelectedItem = (Get-ModelOptionByDeployment -Deployment $script:DefaultModel).Label
    $script:ModelComboBox.Add_SelectedIndexChanged({
        Update-ReasoningOptionsForSelectedModel
    })
    $recommendationBox.Controls.Add($script:ModelComboBox)

    $reasoningLabel = New-Object System.Windows.Forms.Label
    $reasoningLabel.Text = 'Reasoning:'
    $reasoningLabel.Location = New-Object System.Drawing.Point(318, 76)
    $reasoningLabel.Size = New-Object System.Drawing.Size(74, 22)
    $recommendationBox.Controls.Add($reasoningLabel)

    $script:ReasoningEffortComboBox = New-Object System.Windows.Forms.ComboBox
    $script:ReasoningEffortComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $script:ReasoningEffortComboBox.Location = New-Object System.Drawing.Point(396, 73)
    $script:ReasoningEffortComboBox.Size = New-Object System.Drawing.Size(132, 24)
    $recommendationBox.Controls.Add($script:ReasoningEffortComboBox)
    Update-ReasoningOptionsForSelectedModel

    $workspaceCaption = New-Object System.Windows.Forms.Label
    $workspaceCaption.Text = 'Workspace:'
    $workspaceCaption.Location = New-Object System.Drawing.Point(16, 110)
    $workspaceCaption.Size = New-Object System.Drawing.Size(78, 22)
    $recommendationBox.Controls.Add($workspaceCaption)

    $script:RecommendationWorkspacePathLabel = New-Object System.Windows.Forms.Label
    $script:RecommendationWorkspacePathLabel.Location = New-Object System.Drawing.Point(92, 110)
    $script:RecommendationWorkspacePathLabel.Size = New-Object System.Drawing.Size(435, 22)
    $script:RecommendationWorkspacePathLabel.ForeColor = [System.Drawing.Color]::DimGray
    $script:RecommendationWorkspacePathLabel.AutoEllipsis = $true
    $recommendationBox.Controls.Add($script:RecommendationWorkspacePathLabel)
    Update-WorkspaceDisplay

    $script:LaunchAfterSetupCheckBox = New-Object System.Windows.Forms.CheckBox
    $script:LaunchAfterSetupCheckBox.Text = 'Open Codex after setup when detected'
    $script:LaunchAfterSetupCheckBox.Location = New-Object System.Drawing.Point(18, 140)
    $script:LaunchAfterSetupCheckBox.Size = New-Object System.Drawing.Size(258, 24)
    $script:LaunchAfterSetupCheckBox.Checked = $true
    $recommendationBox.Controls.Add($script:LaunchAfterSetupCheckBox)

    $script:CodexStatusLabel = New-Object System.Windows.Forms.Label
    $script:CodexStatusLabel.Text = 'Codex status: checking...'
    $script:CodexStatusLabel.Location = New-Object System.Drawing.Point(18, 170)
    $script:CodexStatusLabel.Size = New-Object System.Drawing.Size(520, 22)
    $script:CodexStatusLabel.ForeColor = [System.Drawing.Color]::DimGray
    $recommendationBox.Controls.Add($script:CodexStatusLabel)

    $fullSetup = New-Button -Text 'Run Recommended Setup' -X 555 -Y 27 -Width 205 -Height 50 -Parent $recommendationBox
    $fullSetup.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $fullSetup.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $fullSetup.ForeColor = [System.Drawing.Color]::White
    $fullSetup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $fullSetup.UseVisualStyleBackColor = $false
    $fullSetup.Add_Click({ Invoke-GuiAction { Run-FullSetup } })

    $script:OpenDesktopButton = New-Button -Text 'Open Codex Desktop' -X 555 -Y 95 -Width 205 -Height 28 -Parent $recommendationBox
    $script:OpenDesktopButton.Add_Click({ Invoke-GuiAction { Open-CodexDesktop } })

    $script:OpenCliButton = New-Button -Text 'Open Codex CLI' -X 555 -Y 132 -Width 205 -Height 28 -Parent $recommendationBox
    $script:OpenCliButton.Add_Click({ Invoke-GuiAction { Open-CodexCli } })

    $script:AdvancedToggleButton = New-Button -Text 'Show Advanced Options' -X 22 -Y 369 -Width 180 -Height 30 -RegisterAction $false
    $script:AdvancedToggleButton.Add_Click({
        Set-AdvancedVisible -Visible (-not $script:AdvancedGroupBox.Visible)
    })

    $script:AdvancedGroupBox = New-Object System.Windows.Forms.GroupBox
    $script:AdvancedGroupBox.Text = 'Advanced and troubleshooting'
    $script:AdvancedGroupBox.Location = New-Object System.Drawing.Point(22, 407)
    $script:AdvancedGroupBox.Size = New-Object System.Drawing.Size(780, 126)
    $script:AdvancedGroupBox.Visible = $false
    $script:Form.Controls.Add($script:AdvancedGroupBox)

    $script:PlaintextConfigCheckBox = New-Object System.Windows.Forms.CheckBox
    $script:PlaintextConfigCheckBox.Text = 'Write key directly in config.toml instead of using UNC_AZURE_API_KEY'
    $script:PlaintextConfigCheckBox.Location = New-Object System.Drawing.Point(16, 22)
    $script:PlaintextConfigCheckBox.Size = New-Object System.Drawing.Size(510, 24)
    $script:AdvancedGroupBox.Controls.Add($script:PlaintextConfigCheckBox)

    $advancedWorkspaceLabel = New-Object System.Windows.Forms.Label
    $advancedWorkspaceLabel.Text = 'Workspace:'
    $advancedWorkspaceLabel.Location = New-Object System.Drawing.Point(16, 52)
    $advancedWorkspaceLabel.Size = New-Object System.Drawing.Size(78, 22)
    $script:AdvancedGroupBox.Controls.Add($advancedWorkspaceLabel)

    $advancedWorkspacePath = New-Object System.Windows.Forms.Label
    $advancedWorkspacePath.Text = $script:WorkspacePath
    $advancedWorkspacePath.Location = New-Object System.Drawing.Point(92, 52)
    $advancedWorkspacePath.Size = New-Object System.Drawing.Size(430, 22)
    $advancedWorkspacePath.ForeColor = [System.Drawing.Color]::DimGray
    $advancedWorkspacePath.AutoEllipsis = $true
    $script:AdvancedGroupBox.Controls.Add($advancedWorkspacePath)
    $script:WorkspacePathLabel = $advancedWorkspacePath
    Update-WorkspaceDisplay

    $chooseWorkspace = New-Button -Text 'Choose' -X 532 -Y 48 -Width 70 -Height 26 -Parent $script:AdvancedGroupBox
    $chooseWorkspace.Add_Click({ Invoke-GuiAction { Choose-CodexWorkspace } })

    $defaultWorkspace = New-Button -Text 'Default' -X 610 -Y 48 -Width 70 -Height 26 -Parent $script:AdvancedGroupBox
    $defaultWorkspace.Add_Click({ Invoke-GuiAction { Reset-CodexWorkspacePath } })

    $openWorkspace = New-Button -Text 'Open' -X 688 -Y 48 -Width 70 -Height 26 -Parent $script:AdvancedGroupBox
    $openWorkspace.Add_Click({ Invoke-GuiAction { Open-CodexWorkspace } })

    $detect = New-Button -Text 'Detect' -X 16 -Y 86 -Width 100 -Height 28 -Parent $script:AdvancedGroupBox
    $detect.Add_Click({ Invoke-GuiAction { Show-CodexDetection | Out-Null } })

    $script:InstallButton = New-Button -Text 'Install Codex' -X 124 -Y 86 -Width 100 -Height 28 -Parent $script:AdvancedGroupBox
    $script:InstallButton.Add_Click({ Invoke-GuiAction { Install-CodexWithWarning -Force $true | Out-Null; Show-CodexDetection | Out-Null } })

    $configure = New-Button -Text 'Config Only' -X 232 -Y 86 -Width 100 -Height 28 -Parent $script:AdvancedGroupBox
    $configure.Add_Click({ Invoke-GuiAction { Configure-Only } })

    $test = New-Button -Text 'Test' -X 340 -Y 86 -Width 100 -Height 28 -Parent $script:AdvancedGroupBox
    $test.Add_Click({ Invoke-GuiAction { Test-ConnectionFromGui } })

    $download = New-Button -Text 'Download' -X 448 -Y 86 -Width 100 -Height 28 -Parent $script:AdvancedGroupBox
    $download.Add_Click({ Invoke-GuiAction { Open-DownloadPage } })

    $support = New-Button -Text 'Support Report' -X 556 -Y 86 -Width 100 -Height 28 -Parent $script:AdvancedGroupBox
    $support.Add_Click({ Invoke-GuiAction { Save-SupportReport } })

    $reset = New-Button -Text 'Reset' -X 664 -Y 86 -Width 100 -Height 28 -Parent $script:AdvancedGroupBox
    $reset.Add_Click({ Invoke-GuiAction { Reset-Changes } })

    $script:LogLabel = New-Object System.Windows.Forms.Label
    $script:LogLabel.Text = 'Setup log'
    $script:LogLabel.Location = New-Object System.Drawing.Point(22, 407)
    $script:LogLabel.Size = New-Object System.Drawing.Size(160, 22)
    $script:Form.Controls.Add($script:LogLabel)

    $script:LogBox = New-Object System.Windows.Forms.TextBox
    $script:LogBox.Location = New-Object System.Drawing.Point(22, 432)
    $script:LogBox.Size = New-Object System.Drawing.Size(780, 236)
    $script:LogBox.Multiline = $true
    $script:LogBox.ScrollBars = 'Vertical'
    $script:LogBox.ReadOnly = $true
    $script:LogBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $script:LogBox.BackColor = [System.Drawing.Color]::White
    $script:Form.Controls.Add($script:LogBox)

    $footer = New-Object System.Windows.Forms.Label
    $footer.Text = 'Tip: Existing config.toml is backed up first. CODEX_HOME is respected when set; otherwise config/support files use %USERPROFILE%\.codex.'
    $footer.Location = New-Object System.Drawing.Point(22, 688)
    $footer.Size = New-Object System.Drawing.Size(780, 24)
    $footer.ForeColor = [System.Drawing.Color]::DimGray
    $footer.AutoEllipsis = $true
    $script:Form.Controls.Add($footer)

    Set-AdvancedVisible -Visible $false
}

Build-Gui
Write-Log 'Ready. Paste the UNC Azure OpenAI API key, then click Run Recommended Setup.'
Write-Log "Codex home is $script:CodexHome ($script:CodexHomeSource)."
Show-CodexDetection | Out-Null
[System.Windows.Forms.Application]::Run($script:Form)

using System.Drawing;
using AIUNCChatGPTInstaller.Models;
using AIUNCChatGPTInstaller.Services;

namespace AIUNCChatGPTInstaller;

internal sealed class MainForm : Form
{
    private readonly AppPaths _paths = new();
    private readonly LogService _log;
    private readonly InstallerService _installer;
    private readonly List<Control> _actionControls = [];
    private readonly CancellationTokenSource _lifetime = new();

    private readonly TextBox _apiKeyTextBox = new();
    private readonly ComboBox _modelComboBox = new();
    private readonly ComboBox _reasoningComboBox = new();
    private readonly Label _modelHelpLabel = new();
    private readonly Label _reasoningHelpLabel = new();
    private readonly Label _workspaceLabel = new();
    private readonly Label _advancedWorkspaceLabel = new();
    private readonly Label _statusLabel = new();
    private readonly CheckBox _launchAfterSetupCheckBox = new();
    private readonly CheckBox _plaintextConfigCheckBox = new();
    private readonly Button _openDesktopButton = new();
    private readonly Button _openCliButton = new();
    private readonly Button _installButton = new();
    private readonly TabControl _modeTabs = new();
    private readonly RichTextBox _logBox = new();
    private readonly ToolTip _toolTip = new();

    private DetectionResult? _detection;
    private bool _busy;
    private bool _closeAfterCancel;

    public MainForm()
    {
        _log = new LogService(_paths);
        _installer = new InstallerService(_paths, _log);
        _log.MessageWritten += AppendLog;

        Text = "AI @ UNC ChatGPT Installer for Windows";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(840, 680);
        ClientSize = new Size(980, 820);
        AutoScaleDimensions = new SizeF(96F, 96F);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9F);
        BackColor = SystemColors.Window;

        Controls.Add(BuildRootLayout());
        AcceptButton = _actionControls.OfType<Button>()
            .FirstOrDefault(button => button.Text == "Run Recommended Setup");

        Load += async (_, _) => await RunActionAsync(RefreshDetectionAsync, showErrors: false);
        FormClosing += OnFormClosing;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _lifetime.Cancel();
            _lifetime.Dispose();
            _toolTip.Dispose();
            _installer.Dispose();
            _log.MessageWritten -= AppendLog;
        }
        base.Dispose(disposing);
    }

    private Control BuildRootLayout()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(18, 14, 18, 14),
            ColumnCount = 1,
            RowCount = 5,
            BackColor = SystemColors.Window
        };
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 348));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 26));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        root.Controls.Add(BuildHeader(), 0, 0);
        root.Controls.Add(BuildApiKeyRow(), 0, 1);
        root.Controls.Add(BuildModeTabs(), 0, 2);

        var logLabel = new Label
        {
            Text = "Setup log",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.BottomLeft,
            Font = new Font(Font, FontStyle.Bold)
        };
        root.Controls.Add(logLabel, 0, 3);

        _logBox.Dock = DockStyle.Fill;
        _logBox.ReadOnly = true;
        _logBox.DetectUrls = false;
        _logBox.BackColor = Color.FromArgb(248, 249, 250);
        _logBox.BorderStyle = BorderStyle.FixedSingle;
        _logBox.Font = new Font("Consolas", 9F);
        _logBox.WordWrap = false;
        root.Controls.Add(_logBox, 0, 4);

        return root;
    }

    private Control BuildHeader()
    {
        var panel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 2,
            Margin = Padding.Empty,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 86));
        panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 24));

        var title = new Label
        {
            Text = "AI @ UNC ChatGPT Installer",
            Dock = DockStyle.Fill,
            Font = new Font("Segoe UI", 15F, FontStyle.Bold),
            TextAlign = ContentAlignment.MiddleLeft
        };
        panel.Controls.Add(title, 0, 0);

        var subtitle = new Label
        {
            Text = $"Configure ChatGPT Desktop and Codex CLI for UNC. Version {InstallerService.InstallerVersion}.",
            Dock = DockStyle.Fill,
            ForeColor = SystemColors.GrayText,
            TextAlign = ContentAlignment.MiddleLeft
        };
        panel.Controls.Add(subtitle, 0, 1);

        var closeButton = CreateButton("Close", async () =>
        {
            await Task.CompletedTask;
            Close();
        }, registerAction: false);
        closeButton.Dock = DockStyle.Top;
        closeButton.Height = 30;
        panel.Controls.Add(closeButton, 1, 0);
        panel.SetRowSpan(closeButton, 2);
        return panel;
    }

    private Control BuildApiKeyRow()
    {
        var panel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 3,
            RowCount = 2,
            Margin = new Padding(0, 6, 0, 8),
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 118));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 8));
        panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 24));
        panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 32));

        panel.Controls.Add(new Label
        {
            Text = "UNC Azure OpenAI API key",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.BottomLeft,
            Font = new Font(Font, FontStyle.Bold)
        }, 0, 0);

        _apiKeyTextBox.Dock = DockStyle.Fill;
        _apiKeyTextBox.UseSystemPasswordChar = true;
        _apiKeyTextBox.AccessibleName = "UNC Azure OpenAI API key";
        panel.Controls.Add(_apiKeyTextBox, 0, 1);

        var showKey = new CheckBox
        {
            Text = "Show key",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            TextAlign = ContentAlignment.MiddleLeft
        };
        showKey.CheckedChanged += (_, _) => _apiKeyTextBox.UseSystemPasswordChar = !showKey.Checked;
        panel.Controls.Add(showKey, 1, 1);
        return panel;
    }

    private Control BuildModeTabs()
    {
        _modeTabs.Dock = DockStyle.Fill;
        _modeTabs.Margin = new Padding(0, 4, 0, 0);
        _modeTabs.Padding = new Point(14, 5);

        var setupPage = new TabPage("Setup")
        {
            BackColor = SystemColors.Window,
            Padding = new Padding(12, 10, 12, 10)
        };
        setupPage.Controls.Add(BuildRecommendedPanel());

        var advancedPage = new TabPage("Advanced Tools")
        {
            BackColor = SystemColors.Window,
            Padding = new Padding(12, 10, 12, 10)
        };
        advancedPage.Controls.Add(BuildAdvancedPanel());

        _modeTabs.TabPages.Add(setupPage);
        _modeTabs.TabPages.Add(advancedPage);
        return _modeTabs;
    }

    private Control BuildRecommendedPanel()
    {
        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 3,
            RowCount = 7,
            Margin = Padding.Empty
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 38));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 34));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 28));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 24));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 36));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 72));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        var description = new Label
        {
            Text = "Paste your API key, choose a model, and run setup. The UNC configuration is tested before ChatGPT opens.",
            Dock = DockStyle.Fill,
            ForeColor = SystemColors.GrayText,
            AutoEllipsis = false,
            TextAlign = ContentAlignment.TopLeft,
            Padding = new Padding(0, 4, 10, 0)
        };
        layout.Controls.Add(description, 0, 0);
        layout.SetColumnSpan(description, 2);

        layout.Controls.Add(BoldLabel("Model"), 0, 1);
        layout.Controls.Add(BoldLabel("Reasoning"), 1, 1);

        _modelComboBox.Dock = DockStyle.Fill;
        _modelComboBox.DropDownStyle = ComboBoxStyle.DropDownList;
        _modelComboBox.DataSource = ModelCatalog.Options.ToList();
        _modelComboBox.SelectedItem = ModelCatalog.Default;
        _modelComboBox.SelectedIndexChanged += (_, _) => UpdateReasoningOptions();
        layout.Controls.Add(_modelComboBox, 0, 2);

        _reasoningComboBox.Dock = DockStyle.Fill;
        _reasoningComboBox.DropDownStyle = ComboBoxStyle.DropDownList;
        _reasoningComboBox.SelectedIndexChanged += (_, _) => UpdateSelectionHelp();
        layout.Controls.Add(_reasoningComboBox, 1, 2);

        ConfigureHelpLabel(_modelHelpLabel);
        ConfigureHelpLabel(_reasoningHelpLabel);
        layout.Controls.Add(_modelHelpLabel, 0, 3);
        layout.Controls.Add(_reasoningHelpLabel, 1, 3);

        var primaryButton = CreateButton("Run Recommended Setup", RunRecommendedSetupAsync);
        primaryButton.Dock = DockStyle.Fill;
        primaryButton.Margin = new Padding(16, 2, 0, 6);
        primaryButton.Font = new Font(Font, FontStyle.Bold);
        primaryButton.BackColor = Color.FromArgb(0, 100, 180);
        primaryButton.ForeColor = Color.White;
        primaryButton.FlatStyle = FlatStyle.Flat;
        primaryButton.FlatAppearance.BorderSize = 0;
        layout.Controls.Add(primaryButton, 2, 0);
        layout.SetRowSpan(primaryButton, 2);

        _openDesktopButton.Text = "Open ChatGPT Desktop";
        StyleActionButton(_openDesktopButton);
        _openDesktopButton.Dock = DockStyle.Top;
        _openDesktopButton.Height = 34;
        _openDesktopButton.Margin = new Padding(16, 1, 0, 1);
        _openDesktopButton.Click += async (_, _) => await RunActionAsync(async () =>
        {
            _detection ??= await _installer.DetectAsync(_lifetime.Token);
            _installer.OpenDesktop(_detection);
        });
        _actionControls.Add(_openDesktopButton);
        layout.Controls.Add(_openDesktopButton, 2, 2);

        _openCliButton.Text = "Open Codex CLI";
        StyleActionButton(_openCliButton);
        _openCliButton.Dock = DockStyle.Top;
        _openCliButton.Height = 34;
        _openCliButton.Margin = new Padding(16, 1, 0, 1);
        _openCliButton.Click += async (_, _) => await RunActionAsync(async () =>
        {
            _detection ??= await _installer.DetectAsync(_lifetime.Token);
            _installer.OpenCli(_detection);
        });
        _actionControls.Add(_openCliButton);
        layout.Controls.Add(_openCliButton, 2, 3);

        var workspaceRow = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 1,
            Margin = Padding.Empty
        };
        workspaceRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));
        workspaceRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        workspaceRow.Controls.Add(new Label
        {
            Text = "Project parent:",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleLeft,
            Font = new Font(Font, FontStyle.Bold)
        }, 0, 0);

        _workspaceLabel.Dock = DockStyle.Fill;
        _workspaceLabel.ForeColor = SystemColors.GrayText;
        _workspaceLabel.TextAlign = ContentAlignment.MiddleLeft;
        _workspaceLabel.AutoEllipsis = true;
        workspaceRow.Controls.Add(_workspaceLabel, 1, 0);
        layout.Controls.Add(workspaceRow, 0, 4);
        layout.SetColumnSpan(workspaceRow, 3);

        _launchAfterSetupCheckBox.Text = "Open ChatGPT Desktop after setup";
        _launchAfterSetupCheckBox.Checked = true;
        _launchAfterSetupCheckBox.Dock = DockStyle.Fill;
        layout.Controls.Add(_launchAfterSetupCheckBox, 0, 5);
        layout.SetColumnSpan(_launchAfterSetupCheckBox, 2);

        _statusLabel.Dock = DockStyle.Fill;
        _statusLabel.ForeColor = SystemColors.GrayText;
        _statusLabel.Text = "Codex status: checking...";
        _statusLabel.TextAlign = ContentAlignment.MiddleLeft;
        layout.Controls.Add(_statusLabel, 0, 6);
        layout.SetColumnSpan(_statusLabel, 3);

        UpdateReasoningOptions();
        UpdateWorkspaceDisplay();
        return layout;
    }

    private Control BuildAdvancedPanel()
    {
        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 4,
            Margin = Padding.Empty
        };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 92));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        _plaintextConfigCheckBox.Text = "Store the API key directly in config.toml instead of using UNC_AZURE_API_KEY";
        _plaintextConfigCheckBox.Dock = DockStyle.Fill;
        _plaintextConfigCheckBox.AutoSize = false;
        _plaintextConfigCheckBox.Padding = new Padding(0, 2, 0, 2);
        _toolTip.SetToolTip(
            _plaintextConfigCheckBox,
            "Compatibility fallback only. The config file is restricted to the current Windows user.");
        layout.Controls.Add(_plaintextConfigCheckBox, 0, 0);

        var workspacePanel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 5,
            RowCount = 1,
            Margin = Padding.Empty
        };
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 106));
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 94));
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 94));
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 94));
        workspacePanel.Controls.Add(new Label
        {
            Text = "Project parent:",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleLeft
        }, 0, 0);
        _advancedWorkspaceLabel.Dock = DockStyle.Fill;
        _advancedWorkspaceLabel.ForeColor = SystemColors.GrayText;
        _advancedWorkspaceLabel.TextAlign = ContentAlignment.MiddleLeft;
        _advancedWorkspaceLabel.AutoEllipsis = true;
        workspacePanel.Controls.Add(_advancedWorkspaceLabel, 1, 0);
        AddWorkspaceCommand(workspacePanel, CreateButton("Choose", ChooseWorkspaceAsync), 2);
        AddWorkspaceCommand(workspacePanel, CreateButton("Default", ResetWorkspaceAsync), 3);
        AddWorkspaceCommand(workspacePanel, CreateButton("Open", OpenWorkspaceAsync), 4);
        layout.Controls.Add(workspacePanel, 0, 1);

        var commands = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 5,
            RowCount = 2,
            Margin = Padding.Empty,
            Padding = new Padding(0, 4, 0, 0)
        };
        for (var column = 0; column < commands.ColumnCount; column++)
        {
            commands.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 20));
        }
        commands.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
        commands.RowStyles.Add(new RowStyle(SizeType.Percent, 50));

        AddAdvancedCommand(commands, CreateButton("Detect", RefreshDetectionAsync), 0);
        _installButton.Text = "Install Apps";
        StyleActionButton(_installButton);
        _installButton.Click += async (_, _) => await RunActionAsync(() => InstallAppsAsync(true));
        _actionControls.Add(_installButton);
        AddAdvancedCommand(commands, _installButton, 1);
        AddAdvancedCommand(commands, CreateButton("Write Config", ConfigureOnlyAsync), 2);
        AddAdvancedCommand(commands, CreateButton("Test Connection", TestConnectionAsync), 3);
        AddAdvancedCommand(commands, CreateButton("Open Downloads", OpenDownloadsAsync), 4);
        AddAdvancedCommand(commands, CreateButton("Support Report", SaveSupportReportAsync), 5);
        AddAdvancedCommand(commands, CreateButton("Reset Config", ResetConfigurationAsync), 6);
        AddAdvancedCommand(commands, CreateButton("Uninstall Desktop", UninstallDesktopAsync), 7);
        AddAdvancedCommand(commands, CreateButton("Uninstall CLI", UninstallCliAsync), 8);
        AddAdvancedCommand(commands, CreateButton("Uninstall UNC Setup", UninstallAllAsync), 9);
        layout.Controls.Add(commands, 0, 2);
        return layout;
    }

    private async Task RunRecommendedSetupAsync()
    {
        var apiKey = GetApiKeyOrThrow();
        var model = SelectedModel;
        var reasoning = SelectedReasoning;
        _log.Write("Starting recommended setup.");
        _log.Write($"Project parent is {_paths.GetWorkspacePath()}.");

        await _installer.WriteConfigAsync(
            apiKey,
            model,
            reasoning,
            _plaintextConfigCheckBox.Checked,
            _lifetime.Token);
        _apiKeyTextBox.Clear();

        var endpointSucceeded = await _installer.TestEndpointAsync(apiKey, model, _lifetime.Token);
        _detection = await _installer.DetectAsync(_lifetime.Token);
        _installer.SaveReceipt(endpointSucceeded, _detection);
        UpdateDetectionUi(_detection);
        if (!endpointSucceeded)
        {
            MessageBox.Show(
                this,
                "The configuration was written, but the UNC endpoint test failed. Check the API key and setup log.",
                "Connection Test Failed",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
            return;
        }

        var installChoice = MessageBox.Show(
            this,
            "UNC configuration is complete and verified.\r\n\r\nInstall or update ChatGPT Desktop and Codex CLI now? This can take several minutes.",
            "Install ChatGPT and Codex",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question);
        if (installChoice == DialogResult.Yes)
        {
            var installResult = await InstallAppsAsync(false, confirm: false);
            if (installResult?.CliInstalled == true)
            {
                await _installer.WriteConfigAsync(
                    apiKey,
                    model,
                    reasoning,
                    _plaintextConfigCheckBox.Checked,
                    _lifetime.Token,
                    backupExisting: false);
            }
        }

        _detection = await _installer.DetectAsync(_lifetime.Token);
        _installer.SaveReceipt(true, _detection);
        UpdateDetectionUi(_detection);
        if (_launchAfterSetupCheckBox.Checked && _detection.DesktopAppId is not null)
        {
            _installer.OpenDesktop(_detection);
        }

        MessageBox.Show(
            this,
            BuildSetupCompleteMessage(_detection),
            "Setup Complete",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);
    }

    private async Task ConfigureOnlyAsync()
    {
        var apiKey = GetApiKeyOrThrow();
        await _installer.WriteConfigAsync(
            apiKey,
            SelectedModel,
            SelectedReasoning,
            _plaintextConfigCheckBox.Checked,
            _lifetime.Token);
        _apiKeyTextBox.Clear();
        _detection = await _installer.DetectAsync(_lifetime.Token);
        _installer.SaveReceipt(false, _detection);
        UpdateDetectionUi(_detection);
        MessageBox.Show(this, "Codex configuration was written.", "Configuration Complete");
    }

    private async Task TestConnectionAsync()
    {
        var ok = await _installer.TestEndpointAsync(
            GetApiKeyOrThrow(),
            SelectedModel,
            _lifetime.Token);
        MessageBox.Show(
            this,
            ok ? "Connection test succeeded." : "Connection test failed. Check the setup log and API key.",
            ok ? "Connection Succeeded" : "Connection Failed",
            MessageBoxButtons.OK,
            ok ? MessageBoxIcon.Information : MessageBoxIcon.Warning);
    }

    private async Task<InstallResult?> InstallAppsAsync(bool force, bool confirm = true)
    {
        if (confirm)
        {
            var confirmation = MessageBox.Show(
                this,
                "Installing ChatGPT Desktop or Codex CLI can take several minutes. Keep this app open until installation finishes.\r\n\r\nStart now?",
                "Install Applications",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);
            if (confirmation != DialogResult.Yes)
            {
                return null;
            }
        }

        var result = await _installer.InstallAppsAsync(force, _lifetime.Token);
        _detection = await _installer.DetectAsync(_lifetime.Token);
        UpdateDetectionUi(_detection);
        if (!result.DesktopInstalled)
        {
            MessageBox.Show(
                this,
                "ChatGPT Desktop could not be installed automatically. The official OpenAI download page was opened.\r\n\r\nA managed computer may require Software Center or IT approval.",
                "Desktop Installation Incomplete",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
        }

        if (!result.CliInstalled)
        {
            MessageBox.Show(
                this,
                "Codex CLI could not be installed automatically. The official OpenAI Codex page was opened.",
                "CLI Installation Incomplete",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
        }

        return result;
    }

    private async Task RefreshDetectionAsync()
    {
        _detection = await _installer.DetectAsync(_lifetime.Token);
        UpdateDetectionUi(_detection);
        _log.Write($"Detection: desktop={_detection.DesktopInstalled}, cli={!string.IsNullOrWhiteSpace(_detection.CliPath)}.");
    }

    private Task ChooseWorkspaceAsync()
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Choose the parent folder for ChatGPT and Codex projects.",
            SelectedPath = _paths.GetWorkspacePath(),
            ShowNewFolderButton = true
        };
        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            _installer.SetWorkspace(dialog.SelectedPath);
            UpdateWorkspaceDisplay();
        }
        return Task.CompletedTask;
    }

    private Task ResetWorkspaceAsync()
    {
        _installer.ResetWorkspace();
        UpdateWorkspaceDisplay();
        return Task.CompletedTask;
    }

    private Task OpenWorkspaceAsync()
    {
        _installer.OpenWorkspace();
        return Task.CompletedTask;
    }

    private Task OpenDownloadsAsync()
    {
        _installer.OpenUrl(InstallerService.ChatGPTDownloadUrl);
        _installer.OpenUrl(InstallerService.CodexDownloadUrl);
        return Task.CompletedTask;
    }

    private async Task SaveSupportReportAsync()
    {
        _detection = await _installer.DetectAsync(_lifetime.Token);
        var reportPath = _installer.SaveSupportReport(_detection);
        MessageBox.Show(this, $"Support report saved to:\r\n{reportPath}", "Support Report");
    }

    private Task ResetConfigurationAsync()
    {
        var choice = MessageBox.Show(
            this,
            "Reset UNC configuration for this Windows user?\r\n\r\nThis removes UNC_AZURE_API_KEY and restores the newest configuration backup. Project folders and user files are not deleted.",
            "Reset Configuration",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Warning);
        if (choice == DialogResult.Yes)
        {
            _installer.ResetConfiguration();
            MessageBox.Show(this, "Configuration reset complete.", "Reset Complete");
        }
        return Task.CompletedTask;
    }

    private async Task UninstallDesktopAsync()
    {
        if (!ConfirmDestructive("Uninstall ChatGPT Desktop?"))
        {
            return;
        }
        await _installer.UninstallDesktopAsync(_lifetime.Token);
        await RefreshDetectionAsync();
    }

    private async Task UninstallCliAsync()
    {
        if (!ConfirmDestructive("Uninstall the standalone Codex CLI?"))
        {
            return;
        }
        await _installer.UninstallCliAsync(_lifetime.Token);
        await RefreshDetectionAsync();
    }

    private async Task UninstallAllAsync()
    {
        if (!ConfirmDestructive(
                "Uninstall all UNC ChatGPT/Codex setup for this user?\r\n\r\nThis removes the credential, restores or removes the active config, and tries to remove ChatGPT Desktop and the standalone CLI. Project folders and user files are not deleted."))
        {
            return;
        }

        var message = await _installer.UninstallAllAsync(_lifetime.Token);
        await RefreshDetectionAsync();
        MessageBox.Show(
            this,
            $"UNC setup uninstall complete.\r\n\r\n{message}",
            "Uninstall Complete",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);
    }

    private async Task RunActionAsync(Func<Task> action, bool showErrors = true)
    {
        if (_busy)
        {
            return;
        }

        _busy = true;
        UseWaitCursor = true;
        SetActionsEnabled(false);
        try
        {
            await action();
        }
        catch (OperationCanceledException) when (_lifetime.IsCancellationRequested)
        {
            _log.Write("Operation cancelled because the app is closing.");
        }
        catch (Exception ex)
        {
            _log.Write($"ERROR: {ex}");
            if (showErrors)
            {
                MessageBox.Show(this, ex.Message, "Operation Failed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
        finally
        {
            SetActionsEnabled(true);
            UseWaitCursor = false;
            _busy = false;
            if (_closeAfterCancel && !IsDisposed)
            {
                BeginInvoke(Close);
            }
        }
    }

    private void UpdateReasoningOptions()
    {
        var model = SelectedModel;
        _reasoningComboBox.BeginUpdate();
        _reasoningComboBox.Items.Clear();
        foreach (var option in model.Reasoning)
        {
            _reasoningComboBox.Items.Add(option);
        }
        _reasoningComboBox.Enabled = model.Reasoning.Length > 0;
        if (model.DefaultReasoning is not null)
        {
            _reasoningComboBox.SelectedItem = model.DefaultReasoning;
        }
        _reasoningComboBox.EndUpdate();
        UpdateSelectionHelp();
    }

    private void UpdateSelectionHelp()
    {
        _modelHelpLabel.Text = SelectedModel.Description;
        _reasoningHelpLabel.Text = SelectedReasoning is null
            ? "Uses the model default because verified reasoning choices are unavailable for this model."
            : ModelCatalog.ReasoningDescription(SelectedReasoning);
    }

    private void UpdateDetectionUi(DetectionResult detection)
    {
        var parts = new List<string>();
        if (detection.DesktopInstalled)
        {
            parts.Add("ChatGPT desktop app detected");
        }
        if (!string.IsNullOrWhiteSpace(detection.CliPath))
        {
            parts.Add("CLI detected");
        }

        _statusLabel.Text = parts.Count == 0
            ? "Codex status: not detected yet."
            : $"Codex status: {string.Join("; ", parts)}.";
        _openDesktopButton.Visible = detection.DesktopAppId is not null;
        _openDesktopButton.Enabled = detection.DesktopAppId is not null && !_busy;
        _openCliButton.Visible = detection.CliPath is not null;
        _openCliButton.Enabled = detection.CliPath is not null && !_busy;
        _installButton.Text = detection.Installed ? "Install/Update Apps" : "Install Apps";
    }

    private void UpdateWorkspaceDisplay()
    {
        var workspace = _paths.GetWorkspacePath();
        _workspaceLabel.Text = workspace;
        _advancedWorkspaceLabel.Text = workspace;
    }

    private string GetApiKeyOrThrow()
    {
        var typed = _apiKeyTextBox.Text.Trim();
        var key = string.IsNullOrWhiteSpace(typed) ? _installer.GetAvailableApiKey() : typed;
        return !string.IsNullOrWhiteSpace(key)
            ? key
            : throw new InvalidOperationException("Paste the UNC Azure OpenAI API key before continuing.");
    }

    private ModelOption SelectedModel =>
        _modelComboBox.SelectedItem as ModelOption ?? ModelCatalog.Default;

    private string? SelectedReasoning =>
        _reasoningComboBox.Enabled ? _reasoningComboBox.SelectedItem as string : null;

    private void AppendLog(string message)
    {
        if (IsDisposed)
        {
            return;
        }

        void Append()
        {
            _logBox.AppendText(message + Environment.NewLine);
            _logBox.SelectionStart = _logBox.TextLength;
            _logBox.ScrollToCaret();
        }

        if (InvokeRequired)
        {
            BeginInvoke(Append);
        }
        else
        {
            Append();
        }
    }

    private Button CreateButton(
        string text,
        Func<Task> action,
        int width = 112,
        bool registerAction = true)
    {
        var button = new Button
        {
            Text = text,
            Size = new Size(width, 30),
            UseVisualStyleBackColor = true,
            AutoEllipsis = true,
            Margin = new Padding(4)
        };
        button.Click += async (_, _) => await RunActionAsync(action);
        if (registerAction)
        {
            _actionControls.Add(button);
        }
        return button;
    }

    private static void StyleActionButton(Button button)
    {
        button.UseVisualStyleBackColor = true;
        button.AutoEllipsis = true;
    }

    private static Label BoldLabel(string text) => new()
    {
        Text = text,
        Dock = DockStyle.Fill,
        Font = new Font("Segoe UI", 9F, FontStyle.Bold),
        TextAlign = ContentAlignment.BottomLeft
    };

    private static void ConfigureHelpLabel(Label label)
    {
        label.Dock = DockStyle.Fill;
        label.ForeColor = SystemColors.GrayText;
        label.AutoEllipsis = false;
        label.TextAlign = ContentAlignment.TopLeft;
        label.Padding = new Padding(0, 6, 10, 2);
    }

    private static void AddAdvancedCommand(
        TableLayoutPanel layout,
        Button button,
        int index)
    {
        button.Dock = DockStyle.Fill;
        button.Margin = new Padding(4);
        button.AutoEllipsis = true;
        layout.Controls.Add(button, index % layout.ColumnCount, index / layout.ColumnCount);
    }

    private static void AddWorkspaceCommand(
        TableLayoutPanel layout,
        Button button,
        int column)
    {
        button.Dock = DockStyle.Fill;
        button.Margin = new Padding(4, 8, 4, 8);
        button.AutoEllipsis = false;
        layout.Controls.Add(button, column, 0);
    }

    private void SetActionsEnabled(bool enabled)
    {
        foreach (var control in _actionControls)
        {
            control.Enabled = enabled;
        }

        _apiKeyTextBox.Enabled = enabled;
        _modelComboBox.Enabled = enabled;
        _reasoningComboBox.Enabled = enabled && SelectedModel.Reasoning.Length > 0;
        _launchAfterSetupCheckBox.Enabled = enabled;
        _plaintextConfigCheckBox.Enabled = enabled;
        _modeTabs.Enabled = enabled;

        if (enabled && _detection is not null)
        {
            UpdateDetectionUi(_detection);
        }
    }

    private bool ConfirmDestructive(string message) =>
        MessageBox.Show(
            this,
            message,
            "Confirm",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Warning) == DialogResult.Yes;

    private string BuildSetupCompleteMessage(DetectionResult detection) =>
        string.Join(
            Environment.NewLine,
            "Setup complete.",
            string.Empty,
            "What happened:",
            "- API key saved/configured.",
            "- UNC config written and tested.",
            $"- Project parent: {_paths.GetWorkspacePath()}",
            $"- ChatGPT Desktop: {(detection.DesktopInstalled ? "detected" : "not detected")}",
            $"- Codex CLI: {(detection.CliPath is not null ? "detected" : "not detected")}");

    private void OnFormClosing(object? sender, FormClosingEventArgs e)
    {
        if (!_busy)
        {
            return;
        }

        var choice = MessageBox.Show(
            this,
            "An installation or configuration operation is still running.\r\n\r\nClosing now will cancel this app's work. Continue closing?",
            "Operation In Progress",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Warning);
        if (choice != DialogResult.Yes)
        {
            e.Cancel = true;
            return;
        }

        e.Cancel = true;
        _closeAfterCancel = true;
        _statusLabel.Text = "Cancelling the current operation...";
        _lifetime.Cancel();
    }
}

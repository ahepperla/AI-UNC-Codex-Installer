using System.Drawing;
using AIUNCChatGPTInstaller.Controls;
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
    private readonly WrappingLabel _modelHelpLabel = new();
    private readonly WrappingLabel _reasoningHelpLabel = new();
    private readonly Label _workspaceLabel = new();
    private readonly Label _advancedWorkspaceLabel = new();
    private readonly Label _statusLabel = new();
    private readonly MeasuredCheckBox _launchAfterSetupCheckBox = new();
    private readonly MeasuredCheckBox _plaintextConfigCheckBox = new();
    private readonly MeasuredButton _openDesktopButton = new();
    private readonly MeasuredButton _openCliButton = new();
    private readonly MeasuredButton _installButton = new();
    private readonly TabControl _modeTabs = new();
    private readonly RichTextBox _logBox = new();
    private readonly ToolTip _toolTip = new();

    private DetectionResult? _detection;
    private bool _busy;
    private bool _closeAfterCancel;
    private bool _managedResourcesDisposed;

    public MainForm(bool runStartupDetection = true, float baseFontSize = 9F)
    {
        _log = new LogService(_paths);
        _installer = new InstallerService(_paths, _log);
        _log.MessageWritten += AppendLog;

        Text = "AI @ UNC ChatGPT Installer for Windows";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(900, 760);
        ClientSize = new Size(980, 820);
        AutoScaleDimensions = new SizeF(96F, 96F);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", baseFontSize);
        BackColor = SystemColors.Window;

        Controls.Add(BuildRootLayout());
        AcceptButton = _actionControls.OfType<Button>()
            .FirstOrDefault(button => button.Text == "Run Recommended Setup");

        if (runStartupDetection)
        {
            Load += async (_, _) => await RunActionAsync(RefreshDetectionAsync, showErrors: false);
        }
        Shown += (_, _) => BeginInvoke(AuditLayout);
        DpiChanged += (_, _) => BeginInvoke(AuditLayout);
        FormClosing += OnFormClosing;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing && !_managedResourcesDisposed)
        {
            _managedResourcesDisposed = true;
            _log.MessageWritten -= AppendLog;
            try
            {
                if (!_lifetime.IsCancellationRequested)
                {
                    _lifetime.Cancel();
                }
            }
            catch (ObjectDisposedException)
            {
                // A concurrent shutdown path may already have released the token source.
            }
            finally
            {
                _lifetime.Dispose();
            }

            _toolTip.Dispose();
            _installer.Dispose();
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
            RowCount = 4,
            BackColor = SystemColors.Window
        };
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 46));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 54));

        root.Controls.Add(BuildHeader(), 0, 0);
        root.Controls.Add(BuildApiKeyRow(), 0, 1);
        root.Controls.Add(BuildModeTabs(), 0, 2);

        var logPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            Margin = new Padding(0, 8, 0, 0)
        };
        logPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        logPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        var logLabel = new Label
        {
            Text = "Setup log",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            Font = new Font(Font, FontStyle.Bold),
            Margin = new Padding(0, 0, 0, 5)
        };
        logPanel.Controls.Add(logLabel, 0, 0);

        _logBox.Dock = DockStyle.Fill;
        _logBox.ReadOnly = true;
        _logBox.DetectUrls = false;
        _logBox.BackColor = Color.FromArgb(248, 249, 250);
        _logBox.BorderStyle = BorderStyle.FixedSingle;
        _logBox.Font = new Font("Consolas", Font.SizeInPoints);
        _logBox.WordWrap = false;
        logPanel.Controls.Add(_logBox, 0, 1);
        root.Controls.Add(logPanel, 0, 3);

        return root;
    }

    private Control BuildHeader()
    {
        var textPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            Margin = Padding.Empty,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        textPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        textPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        var title = new Label
        {
            Text = "AI @ UNC ChatGPT Installer",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            Font = new Font("Segoe UI", Font.SizeInPoints * (15F / 9F), FontStyle.Bold),
            Margin = new Padding(0, 0, 0, 2)
        };
        textPanel.Controls.Add(title, 0, 0);

        var subtitle = new Label
        {
            Text = $"Configure ChatGPT Desktop and Codex CLI for UNC. Version {InstallerService.InstallerVersion}.",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            ForeColor = SystemColors.GrayText,
            Margin = Padding.Empty
        };
        textPanel.Controls.Add(subtitle, 0, 1);

        var panel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 1,
            Margin = Padding.Empty,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.Controls.Add(textPanel, 0, 0);

        var closeButton = CreateButton("Close", async () =>
        {
            await Task.CompletedTask;
            Close();
        }, registerAction: false);
        closeButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        closeButton.Margin = new Padding(14, 0, 0, 0);
        panel.Controls.Add(closeButton, 1, 0);
        return panel;
    }

    private Control BuildApiKeyRow()
    {
        var panel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 2,
            Margin = new Padding(0, 6, 0, 8),
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        var apiKeyLabel = new Label
        {
            Text = "UNC Azure OpenAI API key",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            Font = new Font(Font, FontStyle.Bold),
            Margin = new Padding(0, 0, 0, 4)
        };
        panel.Controls.Add(apiKeyLabel, 0, 0);
        panel.SetColumnSpan(apiKeyLabel, 2);

        _apiKeyTextBox.Dock = DockStyle.Fill;
        _apiKeyTextBox.Margin = new Padding(0, 0, 10, 0);
        _apiKeyTextBox.UseSystemPasswordChar = true;
        _apiKeyTextBox.AccessibleName = "UNC Azure OpenAI API key";
        panel.Controls.Add(_apiKeyTextBox, 0, 1);

        var showKey = new MeasuredCheckBox
        {
            Text = "Show key",
            Anchor = AnchorStyles.Left,
            Margin = Padding.Empty
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
            Padding = new Padding(12, 10, 12, 10),
            AutoScroll = true
        };
        setupPage.Controls.Add(BuildRecommendedPanel());

        var advancedPage = new TabPage("Advanced Tools")
        {
            BackColor = SystemColors.Window,
            Padding = new Padding(12, 10, 12, 10),
            AutoScroll = true
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
            ColumnCount = 1,
            RowCount = 6,
            Margin = Padding.Empty,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        var description = new WrappingLabel
        {
            Text = "Paste your API key, choose a model, and run setup. The UNC configuration is tested before ChatGPT opens.",
            Dock = DockStyle.Top,
            ForeColor = SystemColors.GrayText,
            Margin = new Padding(0, 0, 0, 12)
        };
        layout.Controls.Add(description, 0, 0);

        _modelComboBox.Dock = DockStyle.Fill;
        _modelComboBox.DropDownStyle = ComboBoxStyle.DropDownList;
        _modelComboBox.AccessibleName = "Model selection";
        _modelComboBox.Margin = new Padding(0, 4, 8, 4);
        _modelComboBox.DataSource = ModelCatalog.Options.ToList();
        _modelComboBox.SelectedItem = ModelCatalog.Default;
        _modelComboBox.SelectedIndexChanged += (_, _) => UpdateReasoningOptions();

        _reasoningComboBox.Dock = DockStyle.Fill;
        _reasoningComboBox.DropDownStyle = ComboBoxStyle.DropDownList;
        _reasoningComboBox.AccessibleName = "Reasoning selection";
        _reasoningComboBox.Margin = new Padding(0, 4, 8, 4);
        _reasoningComboBox.SelectedIndexChanged += (_, _) => UpdateSelectionHelp();

        ConfigureHelpLabel(_modelHelpLabel);
        ConfigureHelpLabel(_reasoningHelpLabel);

        var primaryButton = CreateButton("Run Recommended Setup", RunRecommendedSetupAsync);
        primaryButton.Dock = DockStyle.Top;
        primaryButton.Margin = new Padding(10, 0, 0, 8);
        primaryButton.Font = new Font(Font, FontStyle.Bold);
        primaryButton.BackColor = Color.FromArgb(0, 100, 180);
        primaryButton.ForeColor = Color.White;
        primaryButton.FlatStyle = FlatStyle.Flat;
        primaryButton.FlatAppearance.BorderSize = 0;

        _openDesktopButton.Text = "Open ChatGPT Desktop";
        StyleActionButton(_openDesktopButton);
        _openDesktopButton.Dock = DockStyle.Top;
        _openDesktopButton.Margin = new Padding(10, 0, 0, 8);
        _openDesktopButton.Click += async (_, _) => await RunActionAsync(async () =>
        {
            _detection ??= await _installer.DetectAsync(_lifetime.Token);
            _installer.OpenDesktop(_detection);
        });
        _actionControls.Add(_openDesktopButton);

        _openCliButton.Text = "Open Codex CLI";
        StyleActionButton(_openCliButton);
        _openCliButton.Dock = DockStyle.Top;
        _openCliButton.Margin = new Padding(10, 0, 0, 8);
        _openCliButton.Click += async (_, _) => await RunActionAsync(async () =>
        {
            _detection ??= await _installer.DetectAsync(_lifetime.Token);
            _installer.OpenCli(_detection);
        });
        _actionControls.Add(_openCliButton);

        var selectors = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            ColumnCount = 3,
            RowCount = 1,
            Margin = Padding.Empty,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        selectors.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 37));
        selectors.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 35));
        selectors.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 28));
        selectors.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        selectors.Controls.Add(
            BuildSelectorPanel("Model", _modelComboBox, _modelHelpLabel),
            0,
            0);
        selectors.Controls.Add(
            BuildSelectorPanel("Reasoning", _reasoningComboBox, _reasoningHelpLabel),
            1,
            0);

        var actions = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 4,
            Margin = Padding.Empty,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        actions.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        actions.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        actions.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        actions.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        actions.Controls.Add(primaryButton, 0, 0);
        actions.Controls.Add(_openDesktopButton, 0, 1);
        actions.Controls.Add(_openCliButton, 0, 2);
        selectors.Controls.Add(actions, 2, 0);
        layout.Controls.Add(selectors, 0, 1);

        var workspaceRow = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            ColumnCount = 2,
            RowCount = 1,
            Margin = new Padding(0, 8, 0, 0),
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        workspaceRow.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        workspaceRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        workspaceRow.Controls.Add(new Label
        {
            Text = "Project parent:",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            Font = new Font(Font, FontStyle.Bold),
            Margin = new Padding(0, 4, 12, 4)
        }, 0, 0);

        _workspaceLabel.AutoSize = false;
        _workspaceLabel.Dock = DockStyle.Fill;
        _workspaceLabel.ForeColor = SystemColors.GrayText;
        _workspaceLabel.TextAlign = ContentAlignment.MiddleLeft;
        _workspaceLabel.AutoEllipsis = true;
        _workspaceLabel.Margin = new Padding(0, 4, 0, 4);
        workspaceRow.Controls.Add(_workspaceLabel, 1, 0);
        layout.Controls.Add(workspaceRow, 0, 2);

        _launchAfterSetupCheckBox.Text = "Open ChatGPT Desktop after setup";
        _launchAfterSetupCheckBox.Checked = true;
        _launchAfterSetupCheckBox.Anchor = AnchorStyles.Left;
        _launchAfterSetupCheckBox.Margin = new Padding(0, 6, 0, 6);
        layout.Controls.Add(_launchAfterSetupCheckBox, 0, 3);

        _statusLabel.AutoSize = true;
        _statusLabel.Anchor = AnchorStyles.Left;
        _statusLabel.ForeColor = SystemColors.GrayText;
        _statusLabel.Text = "Codex status: checking...";
        _statusLabel.Margin = new Padding(0, 4, 0, 0);
        layout.Controls.Add(_statusLabel, 0, 4);

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
            Margin = Padding.Empty,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        _plaintextConfigCheckBox.Text = "Store the API key directly in config.toml instead of using UNC_AZURE_API_KEY";
        _plaintextConfigCheckBox.Anchor = AnchorStyles.Left;
        _plaintextConfigCheckBox.Margin = new Padding(0, 0, 0, 12);
        _toolTip.SetToolTip(
            _plaintextConfigCheckBox,
            "Compatibility fallback only. The config file is restricted to the current Windows user.");
        layout.Controls.Add(_plaintextConfigCheckBox, 0, 0);

        var workspacePanel = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            ColumnCount = 5,
            RowCount = 1,
            Margin = new Padding(0, 0, 0, 14),
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        workspacePanel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        workspacePanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        workspacePanel.Controls.Add(new Label
        {
            Text = "Project parent:",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            Margin = new Padding(0, 0, 12, 0)
        }, 0, 0);
        _advancedWorkspaceLabel.AutoSize = false;
        _advancedWorkspaceLabel.Dock = DockStyle.Fill;
        _advancedWorkspaceLabel.ForeColor = SystemColors.GrayText;
        _advancedWorkspaceLabel.TextAlign = ContentAlignment.MiddleLeft;
        _advancedWorkspaceLabel.AutoEllipsis = true;
        _advancedWorkspaceLabel.Margin = new Padding(0, 0, 12, 0);
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
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        for (var column = 0; column < commands.ColumnCount; column++)
        {
            commands.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 20));
        }
        commands.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        commands.RowStyles.Add(new RowStyle(SizeType.AutoSize));

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

    private MeasuredButton CreateButton(
        string text,
        Func<Task> action,
        bool registerAction = true)
    {
        var button = new MeasuredButton
        {
            Text = text,
            AccessibleName = $"{text} button",
            AutoEllipsis = false,
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
        button.AutoEllipsis = false;
    }

    private Label BoldLabel(string text) => new()
    {
        Text = text,
        AutoSize = true,
        Anchor = AnchorStyles.Left,
        Font = new Font(Font, FontStyle.Bold),
        Margin = Padding.Empty
    };

    private static void ConfigureHelpLabel(WrappingLabel label)
    {
        label.Dock = DockStyle.Top;
        label.ForeColor = SystemColors.GrayText;
        label.AutoEllipsis = false;
        label.TextAlign = ContentAlignment.TopLeft;
        label.Margin = new Padding(0, 2, 8, 0);
    }

    private Control BuildSelectorPanel(
        string heading,
        ComboBox comboBox,
        WrappingLabel helpLabel)
    {
        var panel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            Margin = Padding.Empty,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        panel.Controls.Add(BoldLabel(heading), 0, 0);
        panel.Controls.Add(comboBox, 0, 1);
        panel.Controls.Add(helpLabel, 0, 2);
        panel.SizeChanged += (_, _) =>
        {
            var width = panel.ClientSize.Width - helpLabel.Margin.Horizontal;
            if (width > 0 && helpLabel.MaximumSize.Width != width)
            {
                helpLabel.MaximumSize = new Size(width, 0);
            }
        };
        return panel;
    }

    private static void AddAdvancedCommand(
        TableLayoutPanel layout,
        Button button,
        int index)
    {
        button.Dock = DockStyle.Fill;
        button.Margin = new Padding(5);
        button.AutoEllipsis = false;
        layout.Controls.Add(button, index % layout.ColumnCount, index / layout.ColumnCount);
    }

    private static void AddWorkspaceCommand(
        TableLayoutPanel layout,
        Button button,
        int column)
    {
        button.Anchor = AnchorStyles.Left;
        button.Margin = new Padding(5, 0, 0, 0);
        button.AutoEllipsis = false;
        layout.Controls.Add(button, column, 0);
    }

    internal IReadOnlyList<string> AuditLayout()
    {
        if (!IsHandleCreated || IsDisposed)
        {
            return [];
        }

        var selectedIndex = _modeTabs.SelectedIndex;
        var issues = new HashSet<string>(StringComparer.Ordinal);
        try
        {
            for (var index = 0; index < _modeTabs.TabPages.Count; index++)
            {
                _modeTabs.SelectedIndex = index;
                _modeTabs.TabPages[index].PerformLayout();
                PerformLayout();
                issues.UnionWith(UiLayoutAuditor.FindClippedText(this));
            }
        }
        finally
        {
            _modeTabs.SelectedIndex = selectedIndex;
            PerformLayout();
        }

        if (issues.Count == 0)
        {
            _log.Write($"UI layout audit passed at {DeviceDpi} DPI.");
        }
        else
        {
            foreach (var issue in issues)
            {
                _log.Write($"UI LAYOUT WARNING: {issue}");
            }
        }

        return issues.ToArray();
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

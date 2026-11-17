using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Security.Principal;
using System.Windows.Forms;
using Microsoft.Win32;

internal static class Program
{
    private const string Product = "Operations Manager";

    private const string HelpText =
        "Operations Manager Installer\r\n" +
        "\r\n" +
        "Graphical installer for the Operations Manager terminal file manager.\r\n" +
        "\r\n" +
        "Run with NO arguments to open the installer window.\r\n" +
        "\r\n" +
        "Silent / scripted options (no window is shown):\r\n" +
        "  OperationsManagerInstaller.exe /install [/dir:\"PATH\"] [/scope:user|machine]\r\n" +
        "                                  [/noppath] [/noshortcut] /silent\r\n" +
        "  OperationsManagerInstaller.exe /uninstall /silent\r\n" +
        "  OperationsManagerInstaller.exe /help\r\n" +
        "\r\n" +
        "For all-users installs, right-click the EXE and choose 'Run as administrator'.\r\n" +
        "A console-only build is also provided as OperationsManagerInstallerCLI.exe.";

    [STAThread]
    private static int Main(string[] args)
    {
        if (args != null && args.Length > 0)
            return RunCommandLine(args);

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new InstallerForm());
        return 0;
    }

    private static int RunCommandLine(string[] args)
    {
        string mode = "";
        string dir = null;
        EnvironmentVariableTarget scope = EnvironmentVariableTarget.User;
        bool addPath = true;
        bool shortcut = true;
        bool silent = false;
        bool help = false;

        for (int i = 0; i < args.Length; i++)
        {
            string a = args[i];
            string low = a.ToLowerInvariant();
            if (low == "/help" || low == "-h" || low == "/?" || low == "help")
                help = true;
            else if (low == "/install" || low == "-install")
                mode = "install";
            else if (low == "/uninstall" || low == "-uninstall")
                mode = "uninstall";
            else if (low == "/silent")
                silent = true;
            else if (low == "/noppath" || low == "/nopath")
                addPath = false;
            else if (low == "/noshortcut")
                shortcut = false;
            else if (low.StartsWith("/scope:"))
            {
                string s = a.Substring(7).Trim().ToLowerInvariant();
                scope = (s == "machine") ? EnvironmentVariableTarget.Machine : EnvironmentVariableTarget.User;
            }
            else if (low.StartsWith("/dir:") || low.StartsWith("/dir="))
            {
                int idx = a.IndexOfAny(new char[] { ':', '=' });
                dir = a.Substring(idx + 1).Trim().Trim('"');
            }
            else if (low.StartsWith("-dir="))
                dir = a.Substring(5).Trim().Trim('"');
            else
            {
                Console.Error.WriteLine("Unknown argument: " + a);
                return 1;
            }
        }

        if (help)
        {
            MessageBox.Show(HelpText, Product + " Installer Help",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
            return 0;
        }

        try
        {
            if (mode == "install")
            {
                if (string.IsNullOrEmpty(dir)) dir = Engine.DefaultDir(Engine.IsAdmin());
                if (scope == EnvironmentVariableTarget.Machine && !Engine.IsAdmin())
                    throw new InvalidOperationException("Machine-wide install requires Administrator rights. Right-click the EXE and choose 'Run as administrator', or use /scope:user.");
                Engine.Install(dir, scope, addPath, shortcut, null);
                return 0;
            }
            if (mode == "uninstall")
            {
                Engine.Uninstall(null);
                return 0;
            }
            MessageBox.Show(HelpText, Product + " Installer Help",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("Error: " + ex.Message);
            if (!silent)
                MessageBox.Show(ex.Message, Product + " Installer Error",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}

internal class InstallerForm : Form
{
    private const string Product = "Operations Manager";

    private TextBox txtDir;
    private RadioButton rbUser;
    private RadioButton rbMachine;
    private Label lblAdminNote;
    private CheckBox chkPath;
    private CheckBox chkShortcut;
    private CheckBox chkLaunch;
    private Button btnBrowse;
    private Button btnInstall;
    private Button btnUninstall;
    private Button btnHelp;
    private Button btnExit;
    private Label lblStatus;
    private ProgressBar progress;
    private bool _admin;

    public InstallerForm()
    {
        InitializeComponent();
        this.Load += new EventHandler(InstallerForm_Load);
    }

    private void InitializeComponent()
    {
        this.Text = Product + " - Installer";
        this.FormBorderStyle = FormBorderStyle.FixedDialog;
        this.StartPosition = FormStartPosition.CenterScreen;
        this.MaximizeBox = false;
        this.MinimizeBox = false;
        this.ClientSize = new Size(540, 470);
        this.BackColor = SystemColors.Control;

        Label header = new Label();
        header.Text = "Operations Manager Installer";
        header.Font = new Font("Segoe UI", 16F, FontStyle.Bold);
        header.ForeColor = Color.DarkBlue;
        header.Location = new Point(20, 16);
        header.Size = new Size(500, 30);
        this.Controls.Add(header);

        Label sub = new Label();
        sub.Text = "Terminal File Manager / Operations Suite";
        sub.Font = new Font("Segoe UI", 9F);
        sub.ForeColor = Color.DimGray;
        sub.Location = new Point(20, 46);
        sub.Size = new Size(500, 20);
        this.Controls.Add(sub);

        GroupBox gb = new GroupBox();
        gb.Text = "Installation options";
        gb.Location = new Point(20, 80);
        gb.Size = new Size(500, 240);
        this.Controls.Add(gb);

        Label lblDir = new Label();
        lblDir.Text = "Install folder:";
        lblDir.Location = new Point(15, 28);
        lblDir.Size = new Size(100, 20);
        gb.Controls.Add(lblDir);

        txtDir = new TextBox();
        txtDir.Location = new Point(110, 25);
        txtDir.Size = new Size(305, 23);
        gb.Controls.Add(txtDir);

        btnBrowse = new Button();
        btnBrowse.Text = "Browse...";
        btnBrowse.Location = new Point(425, 23);
        btnBrowse.Size = new Size(65, 26);
        btnBrowse.Click += new EventHandler(btnBrowse_Click);
        gb.Controls.Add(btnBrowse);

        rbUser = new RadioButton();
        rbUser.Text = "Current user (recommended - no administrator needed)";
        rbUser.Location = new Point(15, 65);
        rbUser.Size = new Size(450, 22);
        rbUser.Checked = true;
        gb.Controls.Add(rbUser);

        rbMachine = new RadioButton();
        rbMachine.Text = "All users (requires administrator rights)";
        rbMachine.Location = new Point(15, 90);
        rbMachine.Size = new Size(450, 22);
        gb.Controls.Add(rbMachine);

        lblAdminNote = new Label();
        lblAdminNote.Location = new Point(33, 112);
        lblAdminNote.Size = new Size(450, 25);
        lblAdminNote.ForeColor = Color.DimGray;
        lblAdminNote.Font = new Font("Segoe UI", 8F);
        gb.Controls.Add(lblAdminNote);

        chkPath = new CheckBox();
        chkPath.Text = "Add to PATH so 'operationsmanager' works in any command window";
        chkPath.Location = new Point(15, 150);
        chkPath.Size = new Size(460, 22);
        chkPath.Checked = true;
        gb.Controls.Add(chkPath);

        chkShortcut = new CheckBox();
        chkShortcut.Text = "Create an 'Operations Manager' Desktop shortcut";
        chkShortcut.Location = new Point(15, 175);
        chkShortcut.Size = new Size(460, 22);
        chkShortcut.Checked = true;
        gb.Controls.Add(chkShortcut);

        chkLaunch = new CheckBox();
        chkLaunch.Text = "Launch Operations Manager after installing";
        chkLaunch.Location = new Point(15, 200);
        chkLaunch.Size = new Size(460, 22);
        gb.Controls.Add(chkLaunch);

        btnInstall = new Button();
        btnInstall.Text = "Install";
        btnInstall.Location = new Point(20, 335);
        btnInstall.Size = new Size(115, 34);
        btnInstall.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
        btnInstall.Click += new EventHandler(btnInstall_Click);
        this.Controls.Add(btnInstall);

        btnUninstall = new Button();
        btnUninstall.Text = "Uninstall";
        btnUninstall.Location = new Point(145, 335);
        btnUninstall.Size = new Size(115, 34);
        btnUninstall.Click += new EventHandler(btnUninstall_Click);
        this.Controls.Add(btnUninstall);

        btnHelp = new Button();
        btnHelp.Text = "Help";
        btnHelp.Location = new Point(270, 335);
        btnHelp.Size = new Size(115, 34);
        btnHelp.Click += new EventHandler(btnHelp_Click);
        this.Controls.Add(btnHelp);

        btnExit = new Button();
        btnExit.Text = "Exit";
        btnExit.Location = new Point(395, 335);
        btnExit.Size = new Size(115, 34);
        btnExit.Click += new EventHandler(btnExit_Click);
        this.Controls.Add(btnExit);

        progress = new ProgressBar();
        progress.Location = new Point(20, 385);
        progress.Size = new Size(490, 12);
        progress.Style = ProgressBarStyle.Marquee;
        progress.Visible = false;
        this.Controls.Add(progress);

        Panel statusPanel = new Panel();
        statusPanel.Location = new Point(20, 405);
        statusPanel.Size = new Size(490, 48);
        statusPanel.BorderStyle = BorderStyle.FixedSingle;
        statusPanel.BackColor = Color.White;
        this.Controls.Add(statusPanel);

        lblStatus = new Label();
        lblStatus.Location = new Point(8, 8);
        lblStatus.Size = new Size(470, 32);
        lblStatus.Text = "Ready.";
        lblStatus.Font = new Font("Segoe UI", 9F);
        statusPanel.Controls.Add(lblStatus);
    }

    private void InstallerForm_Load(object sender, EventArgs e)
    {
        _admin = Engine.IsAdmin();
        rbMachine.Enabled = _admin;
        if (_admin)
            lblAdminNote.Text = "Administrator rights: YES - all-users install is available.";
        else
            lblAdminNote.Text = "Administrator rights: NO - current-user install only.";
        txtDir.Text = Engine.DefaultDir(_admin);
        SetStatus("Choose options, then click Install.");
    }

    private void btnBrowse_Click(object sender, EventArgs e)
    {
        using (FolderBrowserDialog dlg = new FolderBrowserDialog())
        {
            dlg.Description = "Choose the folder where Operations Manager will be installed";
            dlg.ShowNewFolderButton = true;
            string current = txtDir.Text.Trim();
            if (Directory.Exists(current)) dlg.SelectedPath = current;
            if (dlg.ShowDialog(this) == DialogResult.OK)
                txtDir.Text = dlg.SelectedPath;
        }
    }

    private void btnInstall_Click(object sender, EventArgs e)
    {
        string dir = txtDir.Text.Trim().Trim('"');
        if (dir.Length == 0) dir = Engine.DefaultDir(_admin);
        EnvironmentVariableTarget scope = rbMachine.Checked ? EnvironmentVariableTarget.Machine : EnvironmentVariableTarget.User;

        if (scope == EnvironmentVariableTarget.Machine && !_admin)
        {
            MessageBox.Show(this, "All-users installation needs administrator rights.\n\nRight-click the EXE and choose 'Run as administrator', or select Current user.",
                Product, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        SetBusy(true);
        progress.Visible = true;
        try
        {
            Engine.Install(dir, scope, chkPath.Checked, chkShortcut.Checked,
                delegate(string s) { SetStatus(s); });
            txtDir.Text = dir;
            SetStatus("Installation complete.");
            if (chkLaunch.Checked) LaunchInstalled(dir);
            string msg = "Operations Manager was installed successfully.\n\nFolder: " + dir;
            if (chkPath.Checked)
                msg += "\n\nOpen a NEW command prompt and type:\noperationsmanager";
            MessageBox.Show(this, msg, Product, MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            SetStatus("Install failed: " + ex.Message);
            MessageBox.Show(this, "Install failed:\n\n" + ex.Message, Product,
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            SetBusy(false);
            progress.Visible = false;
        }
    }

    private void btnUninstall_Click(object sender, EventArgs e)
    {
        if (MessageBox.Show(this, "Uninstall Operations Manager from this PC?",
                Product, MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
            return;

        SetBusy(true);
        progress.Visible = true;
        try
        {
            string removed = Engine.Uninstall(delegate(string s) { SetStatus(s); });
            if (removed != null)
            {
                if (txtDir.Text.Trim().Length == 0 ||
                    string.Equals(txtDir.Text.Trim(), removed, StringComparison.OrdinalIgnoreCase))
                    txtDir.Text = Engine.DefaultDir(_admin);
                SetStatus("Uninstall complete: " + removed);
                MessageBox.Show(this, "Operations Manager was uninstalled from:\n" + removed,
                    Product, MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            else
            {
                SetStatus("No installation was found on this PC.");
                MessageBox.Show(this, "No Operations Manager installation was found on this PC.",
                    Product, MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }
        catch (Exception ex)
        {
            SetStatus("Uninstall failed: " + ex.Message);
            MessageBox.Show(this, "Uninstall failed:\n\n" + ex.Message, Product,
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            SetBusy(false);
            progress.Visible = false;
        }
    }

    private void btnHelp_Click(object sender, EventArgs e)
    {
        string help =
            "HOW TO INSTALL\n" +
            "1. Choose an install folder (Browse to change it).\n" +
            "2. Pick Current user or All users (admin required).\n" +
            "3. Leave 'Add to PATH' checked so 'operationsmanager' works anywhere.\n" +
            "4. Optionally create a Desktop shortcut and/or launch after install.\n" +
            "5. Click Install.\n\n" +
            "AFTER INSTALL\n" +
            "Open a NEW command prompt and type:  operationsmanager\n\n" +
            "SAFE MODE PASSWORD\n" +
            "Delete and Copy/Move require: abc123\n\n" +
            "SILENT INSTALL (from Command Prompt)\n" +
            "  OperationsManagerInstaller.exe /install /silent\n" +
            "  OperationsManagerInstaller.exe /uninstall /silent\n\n" +
            "Or use OperationsManagerInstallerCLI.exe for full console help.";
        MessageBox.Show(this, help, Product + " Help",
            MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    private void btnExit_Click(object sender, EventArgs e)
    {
        this.Close();
    }

    private static void LaunchInstalled(string dir)
    {
        string bat = Path.Combine(dir, "operationsmanager.bat");
        if (!File.Exists(bat)) return;
        ProcessStartInfo psi = new ProcessStartInfo("cmd.exe", "/k \"\"" + bat + "\"\"");
        psi.WorkingDirectory = dir;
        Process.Start(psi);
    }

    private void SetBusy(bool busy)
    {
        btnInstall.Enabled = !busy;
        btnUninstall.Enabled = !busy;
        btnBrowse.Enabled = !busy;
        btnHelp.Enabled = !busy;
        btnExit.Enabled = !busy;
        txtDir.ReadOnly = busy;
        chkPath.Enabled = !busy;
        chkShortcut.Enabled = !busy;
        chkLaunch.Enabled = !busy;
        rbUser.Enabled = !busy;
        rbMachine.Enabled = !busy && _admin;
        this.Cursor = busy ? Cursors.WaitCursor : Cursors.Default;
    }

    private void SetStatus(string text)
    {
        if (lblStatus.InvokeRequired)
        {
            lblStatus.Invoke(new Action<string>(SetStatus), text);
            return;
        }
        lblStatus.Text = text;
    }
}

internal static class Engine
{
    private const string Product = "Operations Manager";
    private const string ShortName = "OperationsManager";
    private const string BatName = "operationsmanager.bat";
    private const string RegPath = @"Software\OperationsManager";

    public static bool IsAdmin()
    {
        WindowsIdentity id = WindowsIdentity.GetCurrent();
        WindowsPrincipal principal = new WindowsPrincipal(id);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }

    public static string DefaultDir(bool admin)
    {
        if (admin)
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), ShortName);
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), ShortName);
    }

    public static void Install(string dir, EnvironmentVariableTarget scope, bool addPath, bool shortcut, Action<string> log)
    {
        if (string.IsNullOrWhiteSpace(dir)) throw new ArgumentException("Install folder is empty.");
        dir = Path.GetFullPath(dir);

        Log(log, "Installing to: " + dir);
        Directory.CreateDirectory(dir);
        string batPath = Path.Combine(dir, BatName);

        using (Stream resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("OperationsManager.bat"))
        {
            if (resource == null)
                throw new InvalidOperationException("Embedded batch script not found in installer EXE.");
            using (FileStream output = new FileStream(batPath, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                resource.CopyTo(output);
            }
        }
        Log(log, "Batch file written: " + batPath);

        if (addPath)
        {
            Log(log, "Adding to PATH (" + scope + ")...");
            AddToPath(dir, scope);
        }
        else Log(log, "PATH update skipped.");

        string linkPath = null;
        if (shortcut)
        {
            try
            {
                linkPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), Product + ".lnk");
                CreateShortcut(batPath, dir, linkPath);
                Log(log, "Desktop shortcut created.");
            }
            catch (Exception ex)
            {
                Log(log, "Warning: could not create Desktop shortcut: " + ex.Message);
                linkPath = null;
            }
        }
        else Log(log, "Desktop shortcut skipped.");

        using (RegistryKey key = Registry.CurrentUser.CreateSubKey(RegPath))
        {
            key.SetValue("InstallDir", dir, RegistryValueKind.String);
            key.SetValue("Scope", scope.ToString(), RegistryValueKind.String);
            key.SetValue("BatPath", batPath, RegistryValueKind.String);
            if (linkPath != null) key.SetValue("Shortcut", linkPath, RegistryValueKind.String);
            else key.DeleteValue("Shortcut", false);
        }

        Log(log, "Installation complete.");
    }

    public static string Uninstall(Action<string> log)
    {
        string dir = null;
        string scopeValue = "User";
        string linkPath = null;

        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(RegPath))
        {
            if (key != null)
            {
                dir = key.GetValue("InstallDir") as string;
                scopeValue = key.GetValue("Scope") as string ?? "User";
                linkPath = key.GetValue("Shortcut") as string;
            }
        }

        if (string.IsNullOrEmpty(dir))
        {
            Log(log, "No installation was found on this PC.");
            return null;
        }

        Log(log, "Uninstalling from: " + dir);
        EnvironmentVariableTarget scope = EnvironmentVariableTarget.User;
        if (string.Equals(scopeValue, "Machine", StringComparison.OrdinalIgnoreCase))
            scope = EnvironmentVariableTarget.Machine;

        RemoveFromPath(dir, scope);
        RemoveFromPath(dir, EnvironmentVariableTarget.User);
        Log(log, "PATH entries removed.");

        if (!string.IsNullOrEmpty(linkPath) && File.Exists(linkPath))
        {
            try { File.Delete(linkPath); Log(log, "Desktop shortcut removed."); }
            catch { }
        }

        string batPath = Path.Combine(dir, BatName);
        if (Directory.Exists(dir) && File.Exists(batPath))
        {
            try { Directory.Delete(dir, true); Log(log, "Install folder removed."); }
            catch (Exception ex) { Log(log, "Warning: could not remove folder: " + ex.Message); }
        }

        try { Registry.CurrentUser.DeleteSubKeyTree(RegPath, false); }
        catch { }

        Log(log, "Uninstall complete.");
        return dir;
    }

    private static void Log(Action<string> log, string message)
    {
        if (log != null) log(message);
    }

    private static void AddToPath(string dir, EnvironmentVariableTarget target)
    {
        string current = Environment.GetEnvironmentVariable("Path", target) ?? "";
        string[] parts = current.Split(';');
        foreach (string part in parts)
        {
            if (string.Equals(part.Trim(), dir, StringComparison.OrdinalIgnoreCase)) return;
        }
        string separator = (current.Length == 0 || current.EndsWith(";")) ? "" : ";";
        Environment.SetEnvironmentVariable("Path", current + separator + dir, target);
    }

    private static void RemoveFromPath(string dir, EnvironmentVariableTarget target)
    {
        try
        {
            string current = Environment.GetEnvironmentVariable("Path", target) ?? "";
            string[] parts = current.Split(';');
            System.Collections.Generic.List<string> kept = new System.Collections.Generic.List<string>();
            foreach (string part in parts)
            {
                if (!string.Equals(part.Trim(), dir, StringComparison.OrdinalIgnoreCase)) kept.Add(part);
            }
            string updated = string.Join(";", kept.ToArray());
            if (!string.Equals(updated, current, StringComparison.Ordinal))
                Environment.SetEnvironmentVariable("Path", updated, target);
        }
        catch (Exception ex)
        {
            Log(null, "Warning: could not update " + target + " PATH: " + ex.Message);
        }
    }

    private static void CreateShortcut(string batPath, string workDir, string linkPath)
    {
        Type shellType = Type.GetTypeFromProgID("WScript.Shell");
        if (shellType == null) throw new InvalidOperationException("WScript.Shell is unavailable.");
        object shell = Activator.CreateInstance(shellType);
        object shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { linkPath });
        Type shortcutType = shortcut.GetType();

        string cmdPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "cmd.exe");
        shortcutType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { cmdPath });
        shortcutType.InvokeMember("Arguments", BindingFlags.SetProperty, null, shortcut, new object[] { "/k \"\"" + batPath + "\"\"" });
        shortcutType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { workDir });
        shortcutType.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { Product + " - Terminal File Manager" });
        shortcutType.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
    }
}

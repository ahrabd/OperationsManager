using System;
using System.IO;
using System.Reflection;
using System.Security.Principal;
using Microsoft.Win32;

internal static class Program
{
    private const string Product = "Operations Manager";
    private const string ShortName = "OperationsManager";
    private const string BatName = "operationsmanager.bat";
    private const string CommandName = "operationsmanager";
    private const string RegPath = @"Software\OperationsManager";

    private static bool IsAdmin()
    {
        WindowsIdentity id = WindowsIdentity.GetCurrent();
        WindowsPrincipal principal = new WindowsPrincipal(id);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }

    private static string DefaultDir(bool admin)
    {
        if (admin)
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), ShortName);
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), ShortName);
    }

    private static int Main(string[] args)
    {
        try
        {
            if (args.Length > 0)
                return ParseArguments(args);
            return Interactive();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("Error: " + ex.Message);
            return 1;
        }
    }

    private static int ParseArguments(string[] args)
    {
        string mode = "";
        string dir = null;
        EnvironmentVariableTarget scope = EnvironmentVariableTarget.User;
        bool addPath = true;
        bool shortcut = true;
        bool silent = false;

        for (int i = 0; i < args.Length; i++)
        {
            string a = args[i];
            string low = a.ToLowerInvariant();
            if (low == "/help" || low == "-h" || low == "/?")
            {
                PrintHelp();
                return 0;
            }
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
                if (s == "machine") scope = EnvironmentVariableTarget.Machine;
                else scope = EnvironmentVariableTarget.User;
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
                PrintHelp();
                return 1;
            }
        }

        if (mode == "install")
        {
            if (string.IsNullOrEmpty(dir)) dir = DefaultDir(IsAdmin());
            if (scope == EnvironmentVariableTarget.Machine && !IsAdmin())
            {
                Console.Error.WriteLine("Machine-wide install requires Administrator rights. Right-click the EXE and 'Run as administrator', or use /scope:user.");
                return 1;
            }
            return Install(dir, scope, addPath, shortcut, silent);
        }
        if (mode == "uninstall")
            return Uninstall(silent);

        PrintHelp();
        return 0;
    }

    private static void PrintHelp()
    {
        Console.WriteLine(Product + " Installer (Console)");
        Console.WriteLine();
        Console.WriteLine("Usage:");
        Console.WriteLine("  OperationsManagerInstaller.exe                  open the graphical installer");
        Console.WriteLine("  OperationsManagerInstallerCLI.exe               this console installer");
        Console.WriteLine("  OperationsManagerInstallerCLI.exe /install [/dir:\"PATH\"] [/scope:user|machine]");
        Console.WriteLine("                                        [/noppath] [/noshortcut] [/silent]");
        Console.WriteLine("  OperationsManagerInstallerCLI.exe /uninstall [/silent]");
        Console.WriteLine("  OperationsManagerInstallerCLI.exe /help");
        Console.WriteLine();
        Console.WriteLine("For all-users install: right-click the EXE -> Run as administrator, then choose machine scope.");
    }

    private static int Interactive()
    {
        Console.WriteLine("==============================================");
        Console.WriteLine("  " + Product + " - Installer");
        Console.WriteLine("==============================================");
        Console.WriteLine();
        if (IsAdmin())
            Console.WriteLine("Administrator rights: YES (machine-wide install available)");
        else
            Console.WriteLine("Administrator rights: NO  (current-user install only)");
        Console.WriteLine();

        while (true)
        {
            Console.Write("[I]nstall, [U]ninstall, [H]elp, [Q]uit: ");
            string ans = (Console.ReadLine() ?? "").Trim().ToLowerInvariant();
            if (ans == "q" || ans == "quit") return 0;
            if (ans == "i" || ans == "install")
            {
                if (DoInteractiveInstall()) return 0;
            }
            else if (ans == "u" || ans == "uninstall")
            {
                return Uninstall(false);
            }
            else if (ans == "h" || ans == "help" || ans == "?")
            {
                PrintHelp();
            }
            else
            {
                Console.WriteLine("Please type I, U, H or Q.");
            }
            Console.WriteLine();
        }
    }

    private static bool DoInteractiveInstall()
    {
        bool admin = IsAdmin();
        string defaultDir = DefaultDir(admin);
        Console.Write("Install folder [" + defaultDir + "]: ");
        string dir = (Console.ReadLine() ?? "").Trim().Trim('"');
        if (string.IsNullOrEmpty(dir)) dir = defaultDir;

        EnvironmentVariableTarget scope = EnvironmentVariableTarget.User;
        if (admin)
        {
            Console.Write("Install for [a]ll users (PATH/system) or [c]urrent user? [c]: ");
            string s = (Console.ReadLine() ?? "").Trim().ToLowerInvariant();
            if (s == "a" || s == "all") scope = EnvironmentVariableTarget.Machine;
        }

        Console.Write("Add to PATH so 'operationsmanager' works anywhere? [Y/n]: ");
        string p = (Console.ReadLine() ?? "").Trim().ToLowerInvariant();
        bool addPath = (p != "n" && p != "no");

        Console.Write("Create Desktop shortcut? [Y/n]: ");
        string sc = (Console.ReadLine() ?? "").Trim().ToLowerInvariant();
        bool shortcut = (sc != "n" && sc != "no");

        return Install(dir, scope, addPath, shortcut, false) == 0;
    }

    private static int Install(string dir, EnvironmentVariableTarget scope, bool addPath, bool shortcut, bool silent)
    {
        if (string.IsNullOrWhiteSpace(dir)) throw new ArgumentException("Install folder is empty.");
        dir = Path.GetFullPath(dir);

        if (!silent) Console.WriteLine("Installing " + Product + " to: " + dir);

        Directory.CreateDirectory(dir);
        string batPath = Path.Combine(dir, BatName);

        using (Stream resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("OperationsManager.bat"))
        {
            if (resource == null) throw new InvalidOperationException("Embedded batch script not found in installer EXE.");
            using (FileStream output = new FileStream(batPath, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                resource.CopyTo(output);
            }
        }

        if (addPath) AddToPath(dir, scope);

        string linkPath = null;
        if (shortcut)
        {
            try
            {
                linkPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), Product + ".lnk");
                CreateShortcut(batPath, dir, linkPath);
            }
            catch (Exception ex)
            {
                if (!silent) Console.WriteLine("Warning: could not create Desktop shortcut: " + ex.Message);
                linkPath = null;
            }
        }

        using (RegistryKey key = Registry.CurrentUser.CreateSubKey(RegPath))
        {
            key.SetValue("InstallDir", dir, RegistryValueKind.String);
            key.SetValue("Scope", scope.ToString(), RegistryValueKind.String);
            key.SetValue("BatPath", batPath, RegistryValueKind.String);
            if (linkPath != null) key.SetValue("Shortcut", linkPath, RegistryValueKind.String);
            else key.DeleteValue("Shortcut", false);
        }

        if (!silent)
        {
            Console.WriteLine();
            Console.WriteLine("Installation complete.");
            Console.WriteLine("  Batch file: " + batPath);
            if (addPath)
                Console.WriteLine("  PATH updated (" + scope + "). Open a NEW cmd window and type: " + CommandName);
            if (linkPath != null)
                Console.WriteLine("  Desktop shortcut: " + linkPath);
            Console.WriteLine();
        }
        return 0;
    }

    private static int Uninstall(bool silent)
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
            if (!silent) Console.WriteLine("No " + Product + " installation was found on this PC.");
            return 1;
        }

        if (!silent) Console.WriteLine("Uninstalling " + Product + " from: " + dir);

        EnvironmentVariableTarget scope = EnvironmentVariableTarget.User;
        if (string.Equals(scopeValue, "Machine", StringComparison.OrdinalIgnoreCase))
            scope = EnvironmentVariableTarget.Machine;

        RemoveFromPath(dir, scope);
        RemoveFromPath(dir, EnvironmentVariableTarget.User);

        if (!string.IsNullOrEmpty(linkPath) && File.Exists(linkPath))
        {
            try { File.Delete(linkPath); }
            catch { }
        }

        string batPath = Path.Combine(dir, BatName);
        if (Directory.Exists(dir) && File.Exists(batPath))
        {
            try { Directory.Delete(dir, true); }
            catch (Exception ex)
            {
                if (!silent) Console.WriteLine("Warning: could not remove folder: " + ex.Message);
            }
        }

        try { Registry.CurrentUser.DeleteSubKeyTree(RegPath, false); }
        catch { }

        if (!silent)
        {
            Console.WriteLine();
            Console.WriteLine("Uninstall complete. Restart open cmd windows for PATH changes to take effect.");
        }
        return 0;
    }

    private static void AddToPath(string dir, EnvironmentVariableTarget target)
    {
        string current = Environment.GetEnvironmentVariable("Path", target) ?? "";
        string[] parts = current.Split(';');
        foreach (string part in parts)
        {
            if (string.Equals(part.Trim(), dir, StringComparison.OrdinalIgnoreCase))
                return;
        }
        string separator = (string.IsNullOrEmpty(current) || current.EndsWith(";")) ? "" : ";";
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
                if (!string.Equals(part.Trim(), dir, StringComparison.OrdinalIgnoreCase))
                    kept.Add(part);
            }
            string updated = string.Join(";", kept.ToArray());
            if (!string.Equals(updated, current, StringComparison.Ordinal))
                Environment.SetEnvironmentVariable("Path", updated, target);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Warning: could not update " + target + " PATH: " + ex.Message);
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

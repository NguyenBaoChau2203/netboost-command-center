using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Principal;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("NetBoost Command Center")]
[assembly: AssemblyDescription("Mochi Cat launcher for NetBoost Command Center")]
[assembly: AssemblyCompany("NetBoost")]
[assembly: AssemblyProduct("NetBoost Command Center")]
[assembly: AssemblyCopyright("Copyright (c) 2026 NetBoost contributors")]
[assembly: AssemblyVersion("1.0.1.0")]
[assembly: AssemblyFileVersion("1.0.1.0")]
[assembly: AssemblyInformationalVersion("1.0.1")]

namespace NetBoostLauncher
{
    public static class Program
    {
        private const int ErrorCancelled = 1223;

        [STAThread]
        public static int Main(string[] arguments)
        {
            try
            {
                string executablePath = Assembly.GetExecutingAssembly().Location;
                string applicationRoot = Path.GetDirectoryName(executablePath);

                if (!IsAdministrator())
                {
                    try
                    {
                        Process elevatedProcess = Process.Start(
                            CreateElevationStartInfo(executablePath, arguments));
                        if (elevatedProcess != null)
                        {
                            elevatedProcess.Dispose();
                        }
                        return 0;
                    }
                    catch (Win32Exception exception)
                    {
                        if (exception.NativeErrorCode == ErrorCancelled)
                        {
                            return ErrorCancelled;
                        }
                        throw;
                    }
                }

                string scriptPath = ResolveScriptPath(applicationRoot);
                if (!File.Exists(scriptPath))
                {
                    ShowError(
                        "Không tìm thấy thành phần PowerShell của NetBoost:\n\n" + scriptPath +
                        "\n\nHãy giải nén đầy đủ gói phát hành rồi chạy lại.");
                    return 2;
                }

                Process process = Process.Start(
                    CreatePowerShellStartInfo(applicationRoot, arguments));
                if (process == null)
                {
                    ShowError("Windows không thể khởi động PowerShell cho NetBoost.");
                    return 3;
                }

                using (process)
                {
                    process.WaitForExit();
                    return process.ExitCode;
                }
            }
            catch (Exception exception)
            {
                ShowError("Không thể khởi động NetBoost Command Center.\n\n" + exception.Message);
                return 1;
            }
        }

        public static string ResolveScriptPath(string applicationRoot)
        {
            if (string.IsNullOrWhiteSpace(applicationRoot))
            {
                throw new ArgumentException("Application root is required.", "applicationRoot");
            }

            return Path.GetFullPath(Path.Combine(
                applicationRoot,
                "src",
                "powershell",
                "NetBoost_Command_Center.ps1"));
        }

        public static ProcessStartInfo CreateElevationStartInfo(
            string executablePath,
            string[] arguments)
        {
            if (string.IsNullOrWhiteSpace(executablePath))
            {
                throw new ArgumentException("Executable path is required.", "executablePath");
            }

            return new ProcessStartInfo
            {
                FileName = Path.GetFullPath(executablePath),
                Arguments = BuildArgumentString(arguments),
                WorkingDirectory = Path.GetDirectoryName(Path.GetFullPath(executablePath)),
                Verb = "runas",
                UseShellExecute = true,
                WindowStyle = ProcessWindowStyle.Normal
            };
        }

        public static ProcessStartInfo CreatePowerShellStartInfo(
            string applicationRoot,
            string[] forwardedArguments)
        {
            string scriptPath = ResolveScriptPath(applicationRoot);
            string systemDirectory = Environment.GetFolderPath(
                Environment.SpecialFolder.System);
            string powerShellPath = Path.Combine(
                systemDirectory,
                "WindowsPowerShell",
                "v1.0",
                "powershell.exe");

            var arguments = new List<string>
            {
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                scriptPath
            };

            if (forwardedArguments != null)
            {
                arguments.AddRange(forwardedArguments);
            }

            return new ProcessStartInfo
            {
                FileName = powerShellPath,
                Arguments = BuildArgumentString(arguments),
                WorkingDirectory = Path.GetFullPath(applicationRoot),
                UseShellExecute = false,
                WindowStyle = ProcessWindowStyle.Normal
            };
        }

        public static string BuildArgumentString(IEnumerable<string> arguments)
        {
            if (arguments == null)
            {
                return string.Empty;
            }

            var encoded = new List<string>();
            foreach (string argument in arguments)
            {
                encoded.Add(QuoteWindowsArgument(argument));
            }
            return string.Join(" ", encoded.ToArray());
        }

        public static string QuoteWindowsArgument(string argument)
        {
            if (argument == null)
            {
                argument = string.Empty;
            }

            bool requiresQuotes = argument.Length == 0;
            for (int index = 0; index < argument.Length && !requiresQuotes; index++)
            {
                requiresQuotes = char.IsWhiteSpace(argument[index]) || argument[index] == '"';
            }

            if (!requiresQuotes)
            {
                return argument;
            }

            var result = new StringBuilder(argument.Length + 2);
            result.Append('"');
            int backslashes = 0;

            foreach (char character in argument)
            {
                if (character == '\\')
                {
                    backslashes++;
                    continue;
                }

                if (character == '"')
                {
                    result.Append('\\', (backslashes * 2) + 1);
                    result.Append('"');
                    backslashes = 0;
                    continue;
                }

                result.Append('\\', backslashes);
                result.Append(character);
                backslashes = 0;
            }

            result.Append('\\', backslashes * 2);
            result.Append('"');
            return result.ToString();
        }

        private static bool IsAdministrator()
        {
            using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
            {
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
        }

        private static void ShowError(string message)
        {
            MessageBox.Show(
                message,
                "NetBoost Command Center",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}

using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;

[assembly: AssemblyTitle("BANNARAKX NETFORGE")]
[assembly: AssemblyProduct("BANNARAKX NETFORGE")]
[assembly: AssemblyCompany("BANNARAKX")]
[assembly: AssemblyDescription("Network Optimization Suite - DNS, Registry, Group Policy")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace BannarakxNetForge
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            try { Console.OutputEncoding = Encoding.UTF8; } catch { }
            try { Console.Title = "BANNARAKX NETFORGE"; } catch { }

            string dir = AppDomain.CurrentDomain.BaseDirectory;
            string self = Process.GetCurrentProcess().MainModule.FileName;
            string name = Path.GetFileNameWithoutExtension(self);
            string ps1 = Path.Combine(dir, name + ".ps1");

            if (!File.Exists(ps1))
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine();
                Console.WriteLine("  [X] " + name + ".ps1 not found next to this program.");
                Console.WriteLine("      Keep the whole folder together.");
                Console.ResetColor();
                Console.ReadLine();
                return 2;
            }

            string psExe = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
            if (!File.Exists(psExe)) psExe = "powershell.exe";

            StringBuilder a = new StringBuilder();
            a.Append("-NoProfile -ExecutionPolicy Bypass -File \"").Append(ps1).Append("\"");

            // pass through only the known switches
            foreach (string x in args)
            {
                if (string.Equals(x, "-Auto", StringComparison.OrdinalIgnoreCase)) a.Append(" -Auto");
                else if (string.Equals(x, "-NoReboot", StringComparison.OrdinalIgnoreCase)) a.Append(" -NoReboot");
                else if (string.Equals(x, "-Plus", StringComparison.OrdinalIgnoreCase)) a.Append(" -Plus");
            }

            try
            {
                ProcessStartInfo psi = new ProcessStartInfo(psExe, a.ToString());
                psi.UseShellExecute = false;          // share this console window
                psi.WorkingDirectory = dir;
                using (Process p = Process.Start(psi))
                {
                    p.WaitForExit();
                    return p.ExitCode;
                }
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("  [X] Cannot start PowerShell: " + ex.Message);
                Console.ResetColor();
                Console.ReadLine();
                return 1;
            }
        }
    }
}

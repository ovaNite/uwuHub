using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;

namespace JujiTABSLauncher
{
    internal static class Program
    {
        private const string GameExeName = "TotallyAccurateBattleSimulator.exe";
        private const string PluginName = "JujiTABS.dll";

        private static int Main()
        {
            Console.Title = "JujiTABS";
            Console.WriteLine("========================================");
            Console.WriteLine(" JujiTABS - Runtime Launcher");
            Console.WriteLine("========================================");

            string gameExe = FindTabs();
            if (string.IsNullOrEmpty(gameExe))
            {
                Console.Error.WriteLine("TABS wurde nicht gefunden.");
                Console.Error.WriteLine("Starte die EXE aus dem TABS-Installationsordner oder passe den Pfad an.");
                return 2;
            }

            string gameDir = Path.GetDirectoryName(gameExe);
            string plugins = Path.Combine(gameDir, "BepInEx", "plugins");
            Directory.CreateDirectory(plugins);

            string payload = Path.Combine(AppContext.BaseDirectory, "JujiTABS.dll");
            if (!File.Exists(payload))
            {
                Console.Error.WriteLine("Eingebettetes JujiTABS-Plugin fehlt.");
                return 3;
            }

            File.Copy(payload, Path.Combine(plugins, PluginName), true);
            Console.WriteLine("Plugin installiert: " + Path.Combine(plugins, PluginName));
            Console.WriteLine("Starte TABS...");

            Process.Start(new ProcessStartInfo
            {
                FileName = gameExe,
                WorkingDirectory = gameDir,
                UseShellExecute = true
            });

            return 0;
        }

        private static string FindTabs()
        {
            string[] candidates =
            {
                Environment.GetEnvironmentVariable("JUJITABS_GAME"),
                @"C:\Program Files\Epic Games\TABS\TotallyAccurateBattleSimulator.exe",
                @"C:\Program Files (x86)\Steam\steamapps\common\Totally Accurate Battle Simulator\TotallyAccurateBattleSimulator.exe",
                @"C:\Program Files\Steam\steamapps\common\Totally Accurate Battle Simulator\TotallyAccurateBattleSimulator.exe"
            };

            foreach (string path in candidates)
                if (!string.IsNullOrEmpty(path) && File.Exists(path))
                    return path;

            return string.Empty;
        }
    }
}

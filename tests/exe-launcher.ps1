#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$sourcePath = Join-Path $repoRoot 'src\launcher\NetBoost.Launcher.cs'
$builderPath = Join-Path $repoRoot 'tools\Build-NetBoostLauncher.ps1'
$iconPath = Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.ico'
$testRoot = Join-Path $repoRoot 'build\launcher-tests'
$outputPath = Join-Path $testRoot 'NetBoost Command Center.exe'
$assertions = 0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }

    $script:assertions++
}

function Assert-Equal {
    param(
        $Expected,
        $Actual,
        [string]$Message
    )

    if ($Expected -cne $Actual) {
        throw "Assertion failed: $Message. Expected '$Expected', got '$Actual'."
    }

    $script:assertions++
}

foreach ($requiredFile in @($sourcePath, $builderPath, $iconPath)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required launcher file is missing: $requiredFile"
    }
}

Add-Type -AssemblyName System.Drawing
Add-Type -Path $sourcePath -ReferencedAssemblies @('System.dll', 'System.Drawing.dll', 'System.Windows.Forms.dll')

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace NetBoostLauncherTests
{
    public static class WindowsCommandLine
    {
        [DllImport("shell32.dll", SetLastError = true)]
        private static extern IntPtr CommandLineToArgvW(
            [MarshalAs(UnmanagedType.LPWStr)] string commandLine,
            out int argumentCount);

        [DllImport("kernel32.dll")]
        private static extern IntPtr LocalFree(IntPtr memory);

        public static string[] Parse(string commandLine)
        {
            int count;
            IntPtr values = CommandLineToArgvW(commandLine, out count);
            if (values == IntPtr.Zero)
            {
                throw new InvalidOperationException("CommandLineToArgvW failed.");
            }

            try
            {
                var result = new List<string>(count);
                for (int index = 0; index < count; index++)
                {
                    IntPtr value = Marshal.ReadIntPtr(values, index * IntPtr.Size);
                    result.Add(Marshal.PtrToStringUni(value));
                }
                return result.ToArray();
            }
            finally
            {
                LocalFree(values);
            }
        }
    }
}
'@

$forwardedArguments = @(
    '',
    '--web',
    'two words',
    'quote"inside',
    'C:\path with spaces\',
    'backslash\\quote"tail',
    '--lang',
    'vi'
)

$encodedArguments = [NetBoostLauncher.Program]::BuildArgumentString([string[]]$forwardedArguments)
$decodedArguments = @([NetBoostLauncherTests.WindowsCommandLine]::Parse("launcher.exe $encodedArguments") | Select-Object -Skip 1)
Assert-Equal $forwardedArguments.Count $decodedArguments.Count 'argument quoting preserves the number of values'
for ($index = 0; $index -lt $forwardedArguments.Count; $index++) {
    Assert-Equal $forwardedArguments[$index] $decodedArguments[$index] "argument quoting round-trips value $index"
}

$fakeInstallRoot = Join-Path $testRoot 'install root with spaces'
$expectedScriptPath = [IO.Path]::GetFullPath((Join-Path $fakeInstallRoot 'src\powershell\NetBoost_Command_Center.ps1'))
Assert-Equal $expectedScriptPath ([NetBoostLauncher.Program]::ResolveScriptPath($fakeInstallRoot)) 'script path is relative to the EXE directory'

$powerShellStart = [NetBoostLauncher.Program]::CreatePowerShellStartInfo($fakeInstallRoot, [string[]]$forwardedArguments)
$expectedPowerShell = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::System)) 'WindowsPowerShell\v1.0\powershell.exe'
Assert-Equal $expectedPowerShell $powerShellStart.FileName 'launcher uses the built-in Windows PowerShell executable'
Assert-True (-not $powerShellStart.UseShellExecute) 'PowerShell child process does not use shell file associations'
Assert-Equal $fakeInstallRoot $powerShellStart.WorkingDirectory 'PowerShell starts in the extracted application directory'

$decodedPowerShellArguments = @([NetBoostLauncherTests.WindowsCommandLine]::Parse("powershell.exe $($powerShellStart.Arguments)") | Select-Object -Skip 1)
$expectedPowerShellArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $expectedScriptPath) + $forwardedArguments
Assert-Equal $expectedPowerShellArguments.Count $decodedPowerShellArguments.Count 'PowerShell receives the expected number of arguments'
for ($index = 0; $index -lt $expectedPowerShellArguments.Count; $index++) {
    Assert-Equal $expectedPowerShellArguments[$index] $decodedPowerShellArguments[$index] "PowerShell argument $index is preserved"
}

$fakeExecutable = Join-Path $fakeInstallRoot 'NetBoost Command Center.exe'
$elevationStart = [NetBoostLauncher.Program]::CreateElevationStartInfo($fakeExecutable, [string[]]$forwardedArguments)
Assert-Equal $fakeExecutable $elevationStart.FileName 'UAC relaunches the same executable'
Assert-Equal 'runas' $elevationStart.Verb 'UAC uses the runas verb'
Assert-True $elevationStart.UseShellExecute 'UAC relaunch uses the Windows shell'
Assert-Equal $fakeInstallRoot $elevationStart.WorkingDirectory 'UAC relaunch preserves the application directory'
$decodedElevationArguments = @([NetBoostLauncherTests.WindowsCommandLine]::Parse("launcher.exe $($elevationStart.Arguments)") | Select-Object -Skip 1)
Assert-Equal $forwardedArguments.Count $decodedElevationArguments.Count 'UAC relaunch preserves the number of arguments'
for ($index = 0; $index -lt $forwardedArguments.Count; $index++) {
    Assert-Equal $forwardedArguments[$index] $decodedElevationArguments[$index] "UAC argument $index is preserved"
}

$exitProbe = New-Object Diagnostics.ProcessStartInfo
$exitProbe.FileName = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::System)) 'cmd.exe'
$exitProbe.Arguments = '/d /c exit 37'
$exitProbe.UseShellExecute = $false
Assert-Equal 37 ([NetBoostLauncher.Program]::RunProcessAndWait($exitProbe)) 'launcher waits for a child process and propagates its exit code'

if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
[void](New-Item -ItemType Directory -Path $testRoot)

try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builderPath -OutputPath $outputPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Launcher build failed with exit code $LASTEXITCODE."
    }

    Assert-True (Test-Path -LiteralPath $outputPath -PathType Leaf) 'build produces the launcher EXE'

    $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($outputPath)
    Assert-Equal '1.0.1.0' $version.FileVersion 'EXE file version is 1.0.1.0'
    Assert-Equal '1.0.1' $version.ProductVersion 'EXE product version is 1.0.1'
    Assert-Equal 'NetBoost Command Center' $version.ProductName 'EXE product name is branded'

    $bytes = [IO.File]::ReadAllBytes($outputPath)
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    $subsystem = [BitConverter]::ToUInt16($bytes, $peOffset + 24 + 68)
    Assert-Equal 2 $subsystem 'EXE uses the Windows GUI subsystem and does not open an empty console first'

    [byte[]]$icoBytes = [IO.File]::ReadAllBytes($iconPath)
    $icoImageCount = [BitConverter]::ToUInt16($icoBytes, 4)
    $iconEntryOffset = $null
    for ($index = 0; $index -lt $icoImageCount; $index++) {
        $candidateOffset = 6 + ($index * 16)
        $candidateWidth = if ($icoBytes[$candidateOffset] -eq 0) { 256 } else { [int]$icoBytes[$candidateOffset] }
        if ($candidateWidth -eq 32) {
            $iconEntryOffset = $candidateOffset
            break
        }
    }
    Assert-True ($null -ne $iconEntryOffset) 'canonical ICO contains a 32x32 layer'
    $iconLength = [BitConverter]::ToUInt32($icoBytes, $iconEntryOffset + 8)
    $iconDataOffset = [BitConverter]::ToUInt32($icoBytes, $iconEntryOffset + 12)
    [byte[]]$canonicalPngBytes = New-Object byte[] $iconLength
    [Array]::Copy($icoBytes, [int]$iconDataOffset, $canonicalPngBytes, 0, [int]$iconLength)

    $embeddedIcon = [Drawing.Icon]::ExtractAssociatedIcon($outputPath)
    $canonicalStream = New-Object IO.MemoryStream(, $canonicalPngBytes)
    try {
        $embeddedBitmap = $embeddedIcon.ToBitmap()
        $canonicalBitmap = New-Object Drawing.Bitmap($canonicalStream)
        try {
            Assert-Equal $canonicalBitmap.Width $embeddedBitmap.Width 'embedded icon width matches the canonical icon'
            Assert-Equal $canonicalBitmap.Height $embeddedBitmap.Height 'embedded icon height matches the canonical icon'
            for ($y = 0; $y -lt $canonicalBitmap.Height; $y++) {
                for ($x = 0; $x -lt $canonicalBitmap.Width; $x++) {
                    if ($canonicalBitmap.GetPixel($x, $y).ToArgb() -ne $embeddedBitmap.GetPixel($x, $y).ToArgb()) {
                        throw "Assertion failed: embedded Mochi Cat icon differs at pixel ($x, $y)."
                    }
                }
            }
            $assertions++
        } finally {
            $embeddedBitmap.Dispose()
            $canonicalBitmap.Dispose()
        }
    } finally {
        $embeddedIcon.Dispose()
        $canonicalStream.Dispose()
    }
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

[pscustomobject]@{
    ok = $true
    assertions = $assertions
    version = '1.0.1'
    argumentForwarding = 'verified'
    uac = 'verified'
    icon = 'verified'
} | ConvertTo-Json -Depth 4

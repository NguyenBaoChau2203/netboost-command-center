#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$sourcePath = Join-Path $repoRoot 'src\launcher\NetBoost.Launcher.cs'
$iconPath = Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.ico'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOutputPath = Join-Path $repoRoot 'NetBoost Command Center.exe'
} elseif ([IO.Path]::IsPathRooted($OutputPath)) {
    $resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
} else {
    $resolvedOutputPath = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputPath))
}

if ([IO.Path]::GetExtension($resolvedOutputPath) -ine '.exe') {
    throw 'The launcher output path must use the .exe extension.'
}

foreach ($requiredFile in @($sourcePath, $iconPath)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required launcher build input was not found: $requiredFile"
    }
}

$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $outputDirectory -Force)
}

if (Test-Path -LiteralPath $resolvedOutputPath) {
    Remove-Item -LiteralPath $resolvedOutputPath -Force
}

$compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters
$compilerParameters.GenerateExecutable = $true
$compilerParameters.GenerateInMemory = $false
$compilerParameters.OutputAssembly = $resolvedOutputPath
$compilerParameters.CompilerOptions = '/target:winexe /win32icon:"{0}" /optimize+ /platform:anycpu /utf8output' -f $iconPath
foreach ($assembly in @('System.dll', 'System.Drawing.dll', 'System.Windows.Forms.dll')) {
    [void]$compilerParameters.ReferencedAssemblies.Add($assembly)
}

$provider = New-Object Microsoft.CSharp.CSharpCodeProvider
try {
    $compilerResult = $provider.CompileAssemblyFromFile($compilerParameters, $sourcePath)
} finally {
    $provider.Dispose()
}

if ($compilerResult.Errors.HasErrors) {
    $messages = @($compilerResult.Errors | ForEach-Object {
        '{0}({1},{2}): {3} {4}' -f $_.FileName, $_.Line, $_.Column, $_.ErrorNumber, $_.ErrorText
    })
    throw "Launcher compilation failed:`n$($messages -join "`n")"
}

if (-not (Test-Path -LiteralPath $resolvedOutputPath -PathType Leaf)) {
    throw "Launcher compilation did not produce the expected EXE: $resolvedOutputPath"
}

$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($resolvedOutputPath)
[pscustomobject]@{
    OutputPath = $resolvedOutputPath
    Version = $version.ProductVersion
    Bytes = (Get-Item -LiteralPath $resolvedOutputPath).Length
    IconPath = $iconPath
}

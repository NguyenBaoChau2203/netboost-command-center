#Requires -Version 5.1
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $repo 'src\powershell\NetBoost_Command_Center.ps1') --help | Out-Null
$ErrorActionPreference='Stop'
$script:assertions=0
function Assert {param([bool]$Condition,[string]$Message) if(-not $Condition){throw $Message};$script:assertions++}
$script:lines=[Collections.Generic.List[string]]::new()
function Write-Line {param([string]$Text,$Color) $script:lines.Add($Text)}
function Write-UiHeader {param($Title,$Kind)}
function Ensure-Admin {}
$Language='EN'
$script:CleanupDisplayState=New-CleanupDisplayState -KeyReader {return [ConsoleKey]::Spacebar}
Write-CleanupEvent -Level DELETE_OK -Path 'D:\fixture\file1.tmp' -Message 'Deleted file'
Write-CleanupEvent -Level DELETE_OK -Path 'D:\fixture\file2.tmp' -Message 'Deleted file'
Assert (@($script:lines|Where-Object{$_ -match '\] DELETE_OK\b'}).Count -eq 0) 'Space must hide the current and remaining file output.'
Assert (@($script:lines|Where-Object{$_ -match 'hidden'}).Count -eq 1) 'Skipping file details must be acknowledged once.'
Write-CleanupEvent -Level ERROR -ItemEvent -Path 'D:\fixture\locked.tmp' -Message 'individual file failed'
Write-CleanupEvent -Level ERROR -Path 'D:\fixture' -Message 'important target failure'
Write-CleanupEvent -Level WARN -Message 'important warning'
Write-CleanupEvent -Level SUMMARY -Message 'FilesDeleted=2;SkippedOrFailedFiles=1'
Assert (@($script:lines|Where-Object{$_ -match 'individual file failed'}).Count -eq 0) 'Individual failure rows are part of the skipped details.'
Assert (@($script:lines|Where-Object{$_ -match 'important target failure|important warning'}).Count -eq 2) 'Target errors and warnings must remain visible.'
Assert (@($script:lines|Where-Object{$_ -match '\] SUMMARY\b.*SkippedOrFailedFiles=1'}).Count -eq 1) 'Final counts must remain visible after skipping.'

$script:lines.Clear();$script:keyCalls=0
$script:CleanupDisplayState=New-CleanupDisplayState -KeyReader {$script:keyCalls++;if($script:keyCalls -eq 1){return [ConsoleKey]::Enter};if($script:keyCalls -eq 2){return [ConsoleKey]::A};return [ConsoleKey]::Spacebar}
foreach($index in 1..4){Write-CleanupEvent -Level DELETE_OK -Path ('D:\fixture\'+$index+'.tmp') -Message 'Deleted file'}
Assert (@($script:lines|Where-Object{$_ -match '\] DELETE_OK\b'}).Count -eq 2) 'Keys other than Space must not hide details.'
Assert ($script:keyCalls -eq 3) 'After Space, item output must bypass key polling and formatting.'

$script:lines.Clear()
$script:CleanupDisplayState=New-CleanupDisplayState -KeyReader {throw 'No interactive console'}
Write-CleanupEvent -Level DELETE_OK -Path 'D:\fixture\a.tmp' -Message 'Deleted file'
Write-CleanupEvent -Level SUMMARY -Message 'normal completion'
Assert (@($script:lines|Where-Object{$_ -match '\] DELETE_OK\b'}).Count -eq 1) 'Unavailable console input must not fail or suppress cleanup.'
$script:CleanupDisplayState=$null
$script:lines.Clear()
Write-CleanupEvent -Level DELETE_OK -Path 'D:\fixture\default.tmp' -Message 'normal output'
Assert (@($script:lines|Where-Object{$_ -match '\] DELETE_OK\b'}).Count -eq 1) 'Standalone logging outside a cleanup run must retain existing behavior.'

$fixture=Join-Path $repo ('build\cleanup-display-'+[guid]::NewGuid().ToString('N'))
$first=Join-Path $fixture 'first';$second=Join-Path $fixture 'second';$third=Join-Path $fixture 'third'
$fileLock=$null
try {
    foreach($directory in @($first,$second,$third)){[void][IO.Directory]::CreateDirectory($directory);[IO.File]::WriteAllText((Join-Path $directory 'one.tmp'),'fixture');[IO.File]::WriteAllText((Join-Path $directory 'two.tmp'),'fixture')}
    $locked=Join-Path $first 'locked.tmp';[IO.File]::WriteAllText($locked,'fixture')
    $fileLock=[IO.File]::Open($locked,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
    function Get-CleanupTargetDefinitions {
        return @(
            New-CleanupTargetDefinition -Id 'fixture-first' -Label 'First' -DisplayPath $first -Paths @($first) -Risk low -RequiresConfirmation $false
            New-CleanupTargetDefinition -Id 'fixture-second' -Label 'Second' -DisplayPath $second -Paths @($second) -Risk low -RequiresConfirmation $false
            New-CleanupTargetDefinition -Id 'fixture-third' -Label 'Third' -DisplayPath $third -Paths @($third) -Risk low -RequiresConfirmation $false
        )
    }
    $script:lines.Clear();$script:keyCalls=0
    Invoke-CleanupTargetSet -TargetIds @('fixture-first','fixture-second') -Deep $false -Confirmed $false -DisplayKeyReader {$script:keyCalls++;if($script:keyCalls -eq 2){return [ConsoleKey]::Spacebar};return $null}
    Assert (@(Get-ChildItem -LiteralPath $first -File).Count -eq 1 -and (Test-Path -LiteralPath $locked)) 'Space must preserve deletion behavior, including locked-file protection.'
    Assert (@(Get-ChildItem -LiteralPath $second -File).Count -eq 0) 'Cleanup must continue through later targets after Space.'
    Assert (@($script:lines|Where-Object{$_ -match '\] (DELETE_OK|DELETE_DIR|SKIP_LOCKED)\b'}).Count -eq 1) 'Space must suppress item rows across the whole target set.'
    Assert (@($script:lines|Where-Object{$_ -match '\] SUMMARY\b.*FilesDeleted=2;DirsDeleted=0;SkippedOrFailedFiles=1;'}).Count -eq 1) 'First target summary must count deleted and locked files accurately.'
    Assert (@($script:lines|Where-Object{$_ -match '\] SUMMARY\b.*FilesDeleted=2;DirsDeleted=0;SkippedOrFailedFiles=0;'}).Count -eq 1) 'Later target summaries must remain accurate and visible.'
    Assert ($null -eq $script:CleanupDisplayState) 'Display state must be cleared after a cleanup run.'
    $script:lines.Clear()
    Invoke-CleanupTargetSet -TargetIds @('fixture-third') -Deep $false -Confirmed $false -DisplayKeyReader {return $null}
    Assert (@($script:lines|Where-Object{$_ -match '\] DELETE_OK\b'}).Count -eq 2) 'The next cleanup must display details again without restarting NetBoost.'
    $sentinel=New-CleanupDisplayState -KeyReader {return $null};$script:CleanupDisplayState=$sentinel
    $thrown=$false
    try {Invoke-CleanupTargetSet -TargetIds @('fixture-third') -Deep $false -Confirmed $false -OnTargetStart {throw 'Injected target failure'} -DisplayKeyReader {return [ConsoleKey]::Spacebar}}catch{$thrown=$_.Exception.Message -eq 'Injected target failure'}
    Assert ($thrown -and [object]::ReferenceEquals($sentinel,$script:CleanupDisplayState)) 'Exceptions must propagate while restoring the previous display state.'
    $script:CleanupDisplayState=$null
    $script:lines.Clear()
    Invoke-CleanupTargetSet -TargetIds @('fixture-third') -Deep $false -Confirmed $false
    Assert (@($script:lines|Where-Object{$_ -match '\[SUMMARY\]'}).Count -ge 1) 'The default console reader must complete safely in a redirected test host.'
} finally {
    if($fileLock){$fileLock.Dispose()}
    $script:CleanupDisplayState=$null
    $buildPrefix=[IO.Path]::GetFullPath((Join-Path $repo 'build')).TrimEnd('\')+'\'
    if(-not [IO.Path]::GetFullPath($fixture).StartsWith($buildPrefix,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($fixture) -notmatch '^cleanup-display-[a-f0-9]{32}$'){throw 'Unsafe fixture cleanup path'}
    if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction Stop}
}
@{ok=$true;assertions=$script:assertions;cleanupPolicyChanged=$false;systemCleanupPerformed=$false}|ConvertTo-Json

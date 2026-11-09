#Requires -Version 5.1
# Durable state is persisted before a caller may mutate system configuration.
function Write-NetBoostJsonFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value, [switch]$NoOverwrite)
    $target=[IO.Path]::GetFullPath($Path)
    $parent=[IO.Path]::GetDirectoryName($target)
    [void][IO.Directory]::CreateDirectory($parent)
    $temporary=Join-Path $parent ('.netboost-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $json=ConvertTo-Json -InputObject $Value -Depth 16 -ErrorAction Stop
        $null=ConvertFrom-Json -InputObject $json -ErrorAction Stop
        $bytes=([Text.UTF8Encoding]::new($false)).GetBytes($json)
        $stream=[IO.FileStream]::new($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,4096,[IO.FileOptions]::WriteThrough)
        try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
        if([IO.File]::Exists($target) -and -not $NoOverwrite){ [IO.File]::Replace($temporary,$target,[NullString]::Value) }
        else { [IO.File]::Move($temporary,$target) }
        if([IO.File]::ReadAllText($target,[Text.Encoding]::UTF8) -cne $json){ throw 'Persisted state failed verification.' }
    } finally { if([IO.File]::Exists($temporary)){ [IO.File]::Delete($temporary) } }
}

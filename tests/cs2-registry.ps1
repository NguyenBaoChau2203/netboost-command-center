#Requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\powershell\NetBoost.CS2.ps1')
$name='NetBoostCS2Test_'+[guid]::NewGuid().ToString('N')
$path='HKCU:\Software\'+$name
$assertions=0
try {
    foreach($sample in @(
        [pscustomobject]@{Exists=$true;Kind='String';Value='AppStatus=4096;GpuPreference=1;'},
        [pscustomobject]@{Exists=$true;Kind='DWord';Value=1},
        [pscustomobject]@{Exists=$true;Kind='DWord';Value=[uint32]::MaxValue},
        [pscustomobject]@{Exists=$true;Kind='ExpandString';Value='%TEMP%\example'},
        [pscustomobject]@{Exists=$true;Kind='MultiString';Value=@('first','second')},
        [pscustomobject]@{Exists=$true;Kind='Binary';Value=[byte[]]@(1,2,255)}
    )) {
        Set-NetBoostCS2RegistryValue $path 'Fixture' $sample
        $actual=Get-NetBoostCS2RegistryValue $path 'Fixture'
        if($actual.Kind -ne $sample.Kind){throw 'Registry value type did not round trip.'}
        if($sample.Kind -eq 'DWord'){
            if(([long]$actual.Value -band 4294967295) -ne ([long]$sample.Value -band 4294967295)){throw 'DWORD bits did not round trip.'}
        }elseif((ConvertTo-Json -InputObject $actual.Value -Compress) -cne (ConvertTo-Json -InputObject $sample.Value -Compress)){throw 'Registry value data did not round trip.'}
        $assertions++
    }
    $absent=[pscustomobject]@{Exists=$false;Kind='';Value=$null}
    Set-NetBoostCS2RegistryValue $path 'Fixture' $absent
    Set-NetBoostCS2RegistryValue $path 'Fixture' $absent
    if((Get-NetBoostCS2RegistryValue $path 'Fixture').Exists){throw 'Absent registry property was not restored.'};$assertions++
} finally {
    if($path -cne ('HKCU:\Software\'+$name) -or $name -notmatch '^NetBoostCS2Test_[a-f0-9]{32}$'){throw 'Unsafe registry fixture cleanup'}
    if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -ErrorAction Stop}
}
@{ok=$true;assertions=$assertions;networkOrDriverChanges=$false;fixtureRemoved=(-not(Test-Path -LiteralPath $path))}|ConvertTo-Json

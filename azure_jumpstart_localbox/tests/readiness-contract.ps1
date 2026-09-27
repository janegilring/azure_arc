#Requires -Version 7.4
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot
$scripts = Join-Path $root 'artifacts/PowerShell'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

foreach ($name in @('Bootstrap.ps1', 'New-LocalBoxCluster.ps1', 'LocalBoxLogonScript.ps1', 'tests/Invoke-Test.ps1')) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $scripts $name), [ref]$null, [ref]$errors) | Out-Null
    Assert-True ($errors.Count -eq 0) "PowerShell syntax errors in $name"
}

$source = Get-Content (Join-Path $scripts 'New-LocalBoxCluster.ps1') -Raw
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$null, [ref]$null)
$pause = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.IfStatementAst] -and
    $node.Clauses[0].Item1.Extent.Text -eq "'True' -eq `$env:pauseBeforeArcRegistration"
}, $true)
Assert-True ($null -ne $pause) 'Expected explicit opt-in pause.'
Assert-True ($pause.Extent.StartOffset -gt $source.IndexOf('Invoke-AzureEdgeBootstrap -')) 'Node bootstrap must occur before pause.'
foreach ($downstream in @('Set-AzLocalDeployPrereqs -', 'Generate-ARM-Template.ps1', "Write-Host `"Verifying mandatory", 'Start-Sleep -Seconds 600', "New-AzResourceGroupDeployment -Name 'localcluster-validate'", "New-AzResourceGroupDeployment -Name 'localcluster-deploy'")) {
    Assert-True ($source.IndexOf($downstream) -gt $pause.Extent.EndOffset) "Pause must precede $downstream"
}

function Update-AzDeploymentProgressTag {
    param($ProgressString, $ResourceGroupName, $ComputerName, $ErrorAction)
    $script:progress = $ProgressString
}
function Stop-Transcript {}

$oldDirectory = $env:LocalBoxDir
$oldPause = $env:pauseBeforeArcRegistration
$directory = [System.IO.Directory]::CreateTempSubdirectory('localbox-contract-').FullName
try {
    $env:LocalBoxDir = $directory
    foreach ($value in @('True', 'true', 'False', '')) {
        $env:pauseBeforeArcRegistration = $value
        $script:progress = ''
        $marker = Join-Path $directory 'PausedBeforeArcRegistration.txt'
        if (Test-Path $marker) { Remove-Item $marker }
        $output = & ([scriptblock]::Create($pause.Extent.Text + "`n'REACHED_REGISTRATION'"))
        if ($value -ieq 'True') {
            Assert-True (Test-Path $marker) 'Pause must persist a marker.'
            Assert-True ($script:progress -eq 'PausedBeforeArcRegistration') 'Pause must not report deployment complete.'
            Assert-True ($output -notcontains 'REACHED_REGISTRATION') 'Pause must return before registration.'
        } else {
            Assert-True (-not (Test-Path $marker)) 'Default path must not create a marker.'
            Assert-True ($output -contains 'REACHED_REGISTRATION') 'Default path must continue unchanged.'
        }
    }
    foreach ($entryPoint in @('LocalBoxLogonScript.ps1', 'New-LocalBoxCluster.ps1')) {
        $text = Get-Content (Join-Path $scripts $entryPoint) -Raw
        Assert-True ($text.IndexOf('PausedBeforeArcRegistration.txt') -lt $text.IndexOf('Import-PowerShellDataFile')) 'Rerun guard must precede destructive setup.'
    }
    Write-Host 'PASS: script syntax, pause ordering, true/false/unset execution, durable marker, and rerun guards.'
} finally {
    $env:LocalBoxDir = $oldDirectory
    $env:pauseBeforeArcRegistration = $oldPause
    Remove-Item -LiteralPath $directory -Recurse -Force
}

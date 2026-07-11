$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw "FAIL: $Message"
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repositoryRoot "scripts/install_windows.ps1"
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wiki-installer-windows-test-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null

try {
    $starterRootName = "llm-wiki-starter-test"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = Join-Path $temporaryRoot "starter.zip"
    $safeZip = [System.IO.Compression.ZipFile]::Open($archive, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($source in @{
            "AGENTS.md" = "# Rules"
            "START_HERE.md" = "# Start Here"
        }.GetEnumerator()) {
            $entry = $safeZip.CreateEntry("$starterRootName/$($source.Key)")
            $entry.ExternalAttributes = -2147483648
            $writer = [System.IO.StreamWriter]::new($entry.Open())
            try {
                $writer.Write($source.Value)
            }
            finally {
                $writer.Dispose()
            }
        }
    }
    finally {
        $safeZip.Dispose()
    }

    $destination = Join-Path $temporaryRoot "installed-wiki"
    & $installer -ArchivePath $archive -Destination $destination -ExpectedRoot $starterRootName
    Assert-True (Test-Path -LiteralPath (Join-Path $destination "AGENTS.md") -PathType Leaf) "installer did not create the starter vault"
    Assert-True (-not (Get-ChildItem -LiteralPath $temporaryRoot -Force -Filter ".llm-wiki-stage-*")) "installer left a staging directory behind"

    $sentinel = Join-Path $destination "keep-me.txt"
    Set-Content -LiteralPath $sentinel -Value "preserve existing destination"
    $existingDestinationRejected = $false
    try {
        & $installer -ArchivePath $archive -Destination $destination -ExpectedRoot $starterRootName
    }
    catch {
        $existingDestinationRejected = $true
    }
    Assert-True $existingDestinationRejected "installer accepted an existing destination"
    Assert-True (Test-Path -LiteralPath $sentinel -PathType Leaf) "installer modified an existing destination"

    $unsafeArchive = Join-Path $temporaryRoot "unsafe.zip"
    $unsafeZip = [System.IO.Compression.ZipFile]::Open($unsafeArchive, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $unsafeEntry = $unsafeZip.CreateEntry("$starterRootName/../escape.txt")
        $writer = [System.IO.StreamWriter]::new($unsafeEntry.Open())
        try {
            $writer.Write("escape")
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $unsafeZip.Dispose()
    }

    $unsafeDestination = Join-Path $temporaryRoot "unsafe-destination"
    $unsafeArchiveRejected = $false
    try {
        & $installer -ArchivePath $unsafeArchive -Destination $unsafeDestination -ExpectedRoot $starterRootName
    }
    catch {
        $unsafeArchiveRejected = $true
    }
    Assert-True $unsafeArchiveRejected "installer accepted a traversal ZIP entry"
    Assert-True (-not (Test-Path -LiteralPath $unsafeDestination)) "unsafe archive created a destination"

    $version = (Get-Content -LiteralPath (Join-Path $repositoryRoot "VERSION") -Raw).Trim()
    $readme = Get-Content -LiteralPath (Join-Path $repositoryRoot "README.md") -Raw
    $commandMatch = [regex]::Match($readme, '(?ms)^```powershell\r?\n(?<command>.*?)\r?\n```')
    Assert-True $commandMatch.Success "README did not contain a PowerShell setup command"
    $releaseCommand = $commandMatch.Groups["command"].Value.Replace("`$v='$version'", "`$v='test'")
    $readmeDestination = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "llm-wiki"
    Assert-True (-not (Test-Path -LiteralPath $readmeDestination)) "Windows runner already has a README test destination"
    $script:mockArchive = $archive

    function Invoke-WebRequest {
        [CmdletBinding()]
        param(
            [switch]$UseBasicParsing,
            [Parameter(Mandatory = $true)]
            [string]$Uri,
            [Parameter(Mandatory = $true)]
            [string]$OutFile
        )

        Copy-Item -LiteralPath $script:mockArchive -Destination $OutFile -ErrorAction Stop
    }

    function Assert-ReadmeArchiveRejected {
        param(
            [Parameter(Mandatory = $true)]
            [string]$ArchiveFixture,

            [Parameter(Mandatory = $true)]
            [string]$Message
        )

        $script:mockArchive = $ArchiveFixture
        $rejected = $false
        try {
            [ScriptBlock]::Create($releaseCommand).Invoke()
        }
        catch {
            $rejected = $true
        }
        Assert-True $rejected $Message
        Assert-True (-not (Test-Path -LiteralPath $readmeDestination)) "$Message created a destination"
    }

    try {
        [ScriptBlock]::Create($releaseCommand).Invoke()
        Assert-True (Test-Path -LiteralPath (Join-Path $readmeDestination "AGENTS.md") -PathType Leaf) "README command did not install the starter vault"
    }
    finally {
        Remove-Item -LiteralPath $readmeDestination -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Path $readmeDestination | Out-Null
    $readmeSentinel = Join-Path $readmeDestination "keep-me.txt"
    Set-Content -LiteralPath $readmeSentinel -Value "preserve README destination"
    $readmeExistingDestinationRejected = $false
    try {
        [ScriptBlock]::Create($releaseCommand).Invoke()
    }
    catch {
        $readmeExistingDestinationRejected = $true
    }
    finally {
        $readmeSentinelPreserved = Test-Path -LiteralPath $readmeSentinel -PathType Leaf
        Remove-Item -LiteralPath $readmeDestination -Recurse -Force -ErrorAction SilentlyContinue
    }
    Assert-True $readmeExistingDestinationRejected "README command accepted an existing destination"
    Assert-True $readmeSentinelPreserved "README command modified an existing destination"

    Assert-ReadmeArchiveRejected -ArchiveFixture $unsafeArchive -Message "README command accepted a traversal ZIP entry"

    $duplicateArchive = Join-Path $temporaryRoot "duplicate.zip"
    $duplicateZip = [System.IO.Compression.ZipFile]::Open($duplicateArchive, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($content in @("first", "second")) {
            $duplicateEntry = $duplicateZip.CreateEntry("$starterRootName/Duplicate.md")
            $duplicateEntry.ExternalAttributes = -2147483648
            $writer = [System.IO.StreamWriter]::new($duplicateEntry.Open())
            try {
                $writer.Write($content)
            }
            finally {
                $writer.Dispose()
            }
        }
    }
    finally {
        $duplicateZip.Dispose()
    }
    Assert-ReadmeArchiveRejected -ArchiveFixture $duplicateArchive -Message "README command accepted duplicate ZIP entries"

    $nonRegularArchive = Join-Path $temporaryRoot "non-regular.zip"
    $nonRegularZip = [System.IO.Compression.ZipFile]::Open($nonRegularArchive, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $nonRegularEntry = $nonRegularZip.CreateEntry("$starterRootName/link")
        $nonRegularEntry.ExternalAttributes = -1610612736
        $writer = [System.IO.StreamWriter]::new($nonRegularEntry.Open())
        try {
            $writer.Write("not a regular file")
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $nonRegularZip.Dispose()
    }
    Assert-ReadmeArchiveRejected -ArchiveFixture $nonRegularArchive -Message "README command accepted a non-regular ZIP member"

    Write-Output "PASS: Windows starter setup behavior"
}
finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}

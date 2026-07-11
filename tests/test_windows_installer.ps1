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
    Add-Type -AssemblyName System.IO.Compression
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

    $expectedSize = (Get-Item -LiteralPath $archive).Length
    $expectedSha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    $destination = Join-Path $temporaryRoot "installed-wiki"
    & $installer -ArchivePath $archive -Destination $destination -ExpectedRoot $starterRootName -ExpectedSize $expectedSize -ExpectedSha256 $expectedSha256
    Assert-True (Test-Path -LiteralPath (Join-Path $destination "AGENTS.md") -PathType Leaf) "installer did not create the starter vault"
    Assert-True (-not (Get-ChildItem -LiteralPath $temporaryRoot -Force -Filter ".llm-wiki-stage-*")) "installer left a staging directory behind"

    $sentinel = Join-Path $destination "keep-me.txt"
    Set-Content -LiteralPath $sentinel -Value "preserve existing destination"
    $existingDestinationRejected = $false
    try {
        & $installer -ArchivePath $archive -Destination $destination -ExpectedRoot $starterRootName -ExpectedSize $expectedSize -ExpectedSha256 $expectedSha256
    }
    catch {
        $existingDestinationRejected = $true
    }
    Assert-True $existingDestinationRejected "installer accepted an existing destination"
    Assert-True (Test-Path -LiteralPath $sentinel -PathType Leaf) "installer modified an existing destination"

    $tamperedArchive = Join-Path $temporaryRoot "tampered.zip"
    [System.IO.File]::WriteAllBytes(
        $tamperedArchive,
        ([System.IO.File]::ReadAllBytes($archive) + [byte]0x00)
    )
    $tamperedDestination = Join-Path $temporaryRoot "tampered-destination"
    $tamperedArchiveRejected = $false
    try {
        & $installer -ArchivePath $tamperedArchive -Destination $tamperedDestination -ExpectedRoot $starterRootName -ExpectedSize $expectedSize -ExpectedSha256 $expectedSha256
    }
    catch {
        $tamperedArchiveRejected = $true
    }
    Assert-True $tamperedArchiveRejected "installer accepted a ZIP whose digest did not match"
    Assert-True (-not (Test-Path -LiteralPath $tamperedDestination)) "tampered ZIP created a destination"

    $wrongSizeDestination = Join-Path $temporaryRoot "wrong-size-destination"
    $wrongSizeRejected = $false
    try {
        & $installer -ArchivePath $archive -Destination $wrongSizeDestination -ExpectedRoot $starterRootName -ExpectedSize ($expectedSize + 1) -ExpectedSha256 $expectedSha256
    }
    catch {
        $wrongSizeRejected = $true
    }
    Assert-True $wrongSizeRejected "installer accepted an incorrect expected size"
    Assert-True (-not (Test-Path -LiteralPath $wrongSizeDestination)) "wrong expected size created a destination"

    $malformedDigestDestination = Join-Path $temporaryRoot "malformed-digest-destination"
    $malformedDigestRejected = $false
    try {
        & $installer -ArchivePath $archive -Destination $malformedDigestDestination -ExpectedRoot $starterRootName -ExpectedSize $expectedSize -ExpectedSha256 "not-a-sha256"
    }
    catch {
        $malformedDigestRejected = $true
    }
    Assert-True $malformedDigestRejected "installer accepted a malformed expected digest"
    Assert-True (-not (Test-Path -LiteralPath $malformedDigestDestination)) "malformed digest created a destination"

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

    $unsafeExpectedSize = (Get-Item -LiteralPath $unsafeArchive).Length
    $unsafeExpectedSha256 = (Get-FileHash -LiteralPath $unsafeArchive -Algorithm SHA256).Hash
    $unsafeDestination = Join-Path $temporaryRoot "unsafe-destination"
    $unsafeArchiveRejected = $false
    try {
        & $installer -ArchivePath $unsafeArchive -Destination $unsafeDestination -ExpectedRoot $starterRootName -ExpectedSize $unsafeExpectedSize -ExpectedSha256 $unsafeExpectedSha256
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

    function Set-ReadmeArchivePins {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Command,

            [Parameter(Mandatory = $true)]
            [string]$ArchiveFixture
        )

        $sizeMatch = [regex]::Match($Command, '\$expectedSize=\d+')
        $hashMatch = [regex]::Match($Command, '\$expectedSha256=''[0-9a-f]{64}''', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        Assert-True $sizeMatch.Success "README command did not contain an expected ZIP size"
        Assert-True $hashMatch.Success "README command did not contain an expected ZIP SHA-256"

        $expectedFixtureSize = (Get-Item -LiteralPath $ArchiveFixture).Length
        $expectedFixtureSha256 = (Get-FileHash -LiteralPath $ArchiveFixture -Algorithm SHA256).Hash
        return $Command.Replace($sizeMatch.Value, "`$expectedSize=$expectedFixtureSize").Replace($hashMatch.Value, "`$expectedSha256='$expectedFixtureSha256'")
    }

    $releaseCommand = Set-ReadmeArchivePins -Command $releaseCommand -ArchiveFixture $archive

    function Assert-ReadmeArchiveRejected {
        param(
            [Parameter(Mandatory = $true)]
            [string]$ArchiveFixture,

            [Parameter(Mandatory = $true)]
            [string]$Message,

            [bool]$UseFixturePins = $true
        )

        $script:mockArchive = $ArchiveFixture
        $command = if ($UseFixturePins) {
            Set-ReadmeArchivePins -Command $releaseCommand -ArchiveFixture $ArchiveFixture
        }
        else {
            $releaseCommand
        }
        $rejected = $false
        try {
            [ScriptBlock]::Create($command).Invoke()
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

    Assert-ReadmeArchiveRejected -ArchiveFixture $tamperedArchive -Message "README command accepted a ZIP whose digest did not match" -UseFixturePins $false
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

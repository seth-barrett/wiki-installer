[CmdletBinding(DefaultParameterSetName = "Uri")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Path")]
    [ValidateNotNullOrEmpty()]
    [string]$ArchivePath,

    [Parameter(Mandatory = $true, ParameterSetName = "Uri")]
    [ValidateNotNullOrEmpty()]
    [string]$ArchiveUri,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Destination,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-StarterArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath,

        [Parameter(Mandatory = $true)]
        [string]$RootName
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $prefix = "$RootName/"
    $seen = @{}
    $fileCount = 0

    try {
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName
            if ($name.Contains("\") -or -not $name.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                throw "unsafe ZIP member: $name"
            }

            $relativeName = $name.Substring($prefix.Length)
            if (
                $relativeName.StartsWith("/") -or
                ($relativeName.Split("/") -contains "..") -or
                ($relativeName.Split("/") -contains ".")
            ) {
                throw "unsafe ZIP member: $name"
            }

            if ($seen.ContainsKey($name)) {
                throw "duplicate ZIP entry: $name"
            }
            $seen[$name] = $true

            $mode = $entry.ExternalAttributes -shr 16
            $kind = $mode -band 0xF000
            if ($relativeName.Length -eq 0) {
                if ($kind -ne 0x4000) {
                    throw "unsafe ZIP member: $name"
                }
            }
            elseif ($name.EndsWith("/")) {
                if ($kind -ne 0x4000) {
                    throw "unsafe ZIP member: $name"
                }
            }
            else {
                if ($kind -ne 0x8000) {
                    throw "unsafe ZIP member: $name"
                }
                $fileCount += 1
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    if ($fileCount -eq 0) {
        throw "Archive contains no starter files"
    }
}

$destinationPath = [System.IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationPath) {
    throw "Destination must be new: $destinationPath"
}

$parentPath = [System.IO.Path]::GetDirectoryName($destinationPath)
if ([string]::IsNullOrWhiteSpace($parentPath) -or -not (Test-Path -LiteralPath $parentPath -PathType Container)) {
    throw "Destination parent directory does not exist: $parentPath"
}

$stagePath = Join-Path $parentPath (".llm-wiki-stage-" + [System.Guid]::NewGuid().ToString("N"))
$downloadPath = "$stagePath.zip"

try {
    if ($PSCmdlet.ParameterSetName -eq "Path") {
        if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
            throw "Archive file does not exist: $ArchivePath"
        }
        Copy-Item -LiteralPath $ArchivePath -Destination $downloadPath -ErrorAction Stop
    }
    else {
        $uri = [System.Uri]$ArchiveUri
        if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne [System.Uri]::UriSchemeHttps) {
            throw "Archive URI must use HTTPS"
        }
        Invoke-WebRequest -UseBasicParsing -Uri $ArchiveUri -OutFile $downloadPath -ErrorAction Stop
    }

    Test-StarterArchive -ZipPath $downloadPath -RootName $ExpectedRoot
    New-Item -ItemType Directory -Path $stagePath -ErrorAction Stop | Out-Null
    Expand-Archive -LiteralPath $downloadPath -DestinationPath $stagePath -ErrorAction Stop

    $sourcePath = Join-Path $stagePath $ExpectedRoot
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
        throw "Archive did not create the expected starter directory: $ExpectedRoot"
    }

    [System.IO.Directory]::Move($sourcePath, $destinationPath)
    Write-Output "Installed LLM Wiki to $destinationPath"
}
finally {
    Remove-Item -LiteralPath $downloadPath, $stagePath -Recurse -Force -ErrorAction SilentlyContinue
}

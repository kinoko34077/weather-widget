$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$verifier = Join-Path $repoRoot "project/tools/verify-static.ps1"
$currentIndex = Join-Path $repoRoot "index.html"

function Invoke-Case([string]$Name, [string]$IndexPath, [int]$ExpectedExitCode) {
    & pwsh -NoProfile -File $verifier -RootPath $repoRoot -IndexPath $IndexPath
    $actual = $LASTEXITCODE
    if ($actual -ne $ExpectedExitCode) {
        throw "${Name}: expected exit $ExpectedExitCode, got $actual"
    }
    Write-Host "[weather-static-test] PASS $Name"
}

Invoke-Case -Name "current accepted index" -IndexPath $currentIndex -ExpectedExitCode 0

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("weather-widget-static-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    $current = Get-Content -Raw -Encoding UTF8 -LiteralPath $currentIndex

    $missingEmbed = Join-Path $tempDir "missing-embed.html"
    $current.Replace("weatherwidget-io", "weatherwidget-removed") |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $missingEmbed
    Invoke-Case -Name "missing embed fails" -IndexPath $missingEmbed -ExpectedExitCode 1

    $manifestActivated = Join-Path $tempDir "manifest-activated.html"
    $manifestReplacement = '  <link rel="manifest" href="manifest.webmanifest" />' + [Environment]::NewLine + '</head>'
    ($current -replace '</head>', $manifestReplacement) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $manifestActivated
    Invoke-Case -Name "manifest activation fails" -IndexPath $manifestActivated -ExpectedExitCode 1

    $serviceWorkerActivated = Join-Path $tempDir "service-worker-activated.html"
    $serviceWorkerReplacement = '  <script>navigator.serviceWorker.register("./service-worker.js");</script>' + [Environment]::NewLine + '</body>'
    ($current -replace '</body>', $serviceWorkerReplacement) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $serviceWorkerActivated
    Invoke-Case -Name "service-worker activation fails" -IndexPath $serviceWorkerActivated -ExpectedExitCode 1
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

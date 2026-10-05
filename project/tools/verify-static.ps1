param(
    [string]$IndexPath,
    [string]$RootPath
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RootPath)) {
    $RootPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
if ([string]::IsNullOrWhiteSpace($IndexPath)) {
    $IndexPath = Join-Path $RootPath "index.html"
}

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) {
    [void]$failures.Add($Message)
}

if (-not (Test-Path -LiteralPath $IndexPath -PathType Leaf)) {
    Add-Failure "index.html is missing: $IndexPath"
}
else {
    $html = Get-Content -Raw -Encoding UTF8 -LiteralPath $IndexPath

    if ($html -notmatch '(?is)class\s*=\s*["''][^"'']*\bweatherwidget-io\b') {
        Add-Failure "active weatherwidget-io anchor is missing"
    }
    if ($html -notmatch [regex]::Escape('https://forecast7.com/ja/35d69139d69/tokyo/')) {
        Add-Failure "Tokyo forecast target is missing"
    }
    if ($html -notmatch [regex]::Escape('https://weatherwidget.io/js/widget.min.js')) {
        Add-Failure "weatherwidget.io loader is missing"
    }
    if ($html -notmatch '(?is)<link\b[^>]*href\s*=\s*["'']style\.css["'']') {
        Add-Failure "style.css link is missing"
    }

    if ($html -match '(?is)<link\b[^>]*rel\s*=\s*["''][^"'']*\bmanifest\b') {
        Add-Failure "manifest activation is outside the accepted dormant-PWA boundary"
    }
    if ($html -match '(?is)navigator\s*\.\s*serviceWorker\s*\.\s*register\s*\(') {
        Add-Failure "service-worker registration is outside the accepted dormant-PWA boundary"
    }
}

foreach ($required in @("manifest.webmanifest", "service-worker.js")) {
    $path = Join-Path $RootPath $required
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "retained dormant PWA artifact is missing: $required"
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "[weather-static] FAIL $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "[weather-static] PASS active embed and dormant-PWA contract"
exit 0

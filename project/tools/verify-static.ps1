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

function Find-HtmlTagEnd([string]$Html, [int]$StartIndex) {
    $quote = [char]0
    for ($index = $StartIndex; $index -lt $Html.Length; $index++) {
        $character = $Html[$index]
        if ($quote -ne [char]0) {
            if ($character -eq $quote) { $quote = [char]0 }
            continue
        }
        if ($character -eq [char]34 -or $character -eq [char]39) {
            $quote = $character
        }
        elseif ($character -eq '>') {
            return $index
        }
    }
    return -1
}

function Read-HtmlTag([string]$Html, [int]$StartIndex) {
    $cursor = $StartIndex + 1
    if ($cursor -ge $Html.Length) { return $null }

    if ($Html[$cursor] -eq '!' -or $Html[$cursor] -eq '?') {
        $end = Find-HtmlTagEnd -Html $Html -StartIndex $cursor
        if ($end -lt 0) { return @{ end = $Html.Length - 1; name = ''; closing = $false; declaration = $true } }
        return @{ end = $end; name = ''; closing = $false; declaration = $true }
    }

    $closing = $false
    if ($Html[$cursor] -eq '/') {
        $closing = $true
        $cursor++
    }
    if ($cursor -ge $Html.Length -or -not [char]::IsLetter($Html[$cursor])) { return $null }

    $nameStart = $cursor
    while ($cursor -lt $Html.Length -and -not [char]::IsWhiteSpace($Html[$cursor]) -and $Html[$cursor] -ne '/' -and $Html[$cursor] -ne '>') {
        $cursor++
    }
    if ($cursor -eq $nameStart) { return $null }
    $name = $Html.Substring($nameStart, $cursor - $nameStart).ToLowerInvariant()
    $end = Find-HtmlTagEnd -Html $Html -StartIndex $cursor
    if ($end -lt 0) { return @{ end = $Html.Length - 1; name = $name; closing = $closing; declaration = $false; incomplete = $true } }

    return @{ end = $end; name = $name; closing = $closing; declaration = $false; incomplete = $false }
}

function Find-HtmlRawTextEndTag([string]$Html, [string]$TagName, [int]$StartIndex) {
    $needle = "</$TagName"
    $searchIndex = $StartIndex
    while ($searchIndex -lt $Html.Length) {
        $candidate = $Html.IndexOf($needle, $searchIndex, [System.StringComparison]::OrdinalIgnoreCase)
        if ($candidate -lt 0) { return -1 }
        $afterName = $candidate + $needle.Length
        if ($afterName -ge $Html.Length -or [char]::IsWhiteSpace($Html[$afterName]) -or $Html[$afterName] -eq '/' -or $Html[$afterName] -eq '>') {
            return $candidate
        }
        $searchIndex = $candidate + 2
    }
    return -1
}

function Remove-HtmlComments([string]$Html) {
    $output = New-Object System.Text.StringBuilder
    $index = 0
    $rawTextTag = $null

    while ($index -lt $Html.Length) {
        if ($rawTextTag) {
            $closingTag = Find-HtmlRawTextEndTag -Html $Html -TagName $rawTextTag -StartIndex $index
            if ($closingTag -lt 0) {
                [void]$output.Append($Html, $index, $Html.Length - $index)
                break
            }
            if ($closingTag -gt $index) {
                [void]$output.Append($Html, $index, $closingTag - $index)
            }
            $index = $closingTag
            $rawTextTag = $null
            continue
        }

        if ($index + 3 -lt $Html.Length -and $Html.Substring($index, 4) -ceq '<!--') {
            $contentStart = $index + 4
            if ($contentStart -lt $Html.Length -and $Html[$contentStart] -eq '>') {
                $index = $contentStart + 1
                continue
            }
            if ($contentStart + 1 -lt $Html.Length -and $Html[$contentStart] -eq '-' -and $Html[$contentStart + 1] -eq '>') {
                $index = $contentStart + 2
                continue
            }

            $standardEnd = $Html.IndexOf('-->', $contentStart, [System.StringComparison]::Ordinal)
            $bangEnd = $Html.IndexOf('--!>', $contentStart, [System.StringComparison]::Ordinal)
            if ($standardEnd -lt 0 -and $bangEnd -lt 0) {
                # HTML treats an unterminated comment as extending to EOF.
                break
            }
            if ($standardEnd -ge 0 -and ($bangEnd -lt 0 -or $standardEnd -lt $bangEnd)) {
                $index = $standardEnd + 3
            }
            else {
                $index = $bangEnd + 4
            }
            continue
        }

        if ($Html[$index] -eq '<') {
            $tag = Read-HtmlTag -Html $Html -StartIndex $index
            if ($null -ne $tag) {
                $tagLength = $tag.end - $index + 1
                if ($tagLength -gt 0) {
                    [void]$output.Append($Html, $index, $tagLength)
                }
                if (-not $tag.declaration -and -not $tag.closing -and -not $tag.incomplete -and $tag.name -in @('script', 'style')) {
                    $rawTextTag = $tag.name
                }
                $index = $tag.end + 1
                if ($tag.incomplete) { break }
                continue
            }
        }

        [void]$output.Append($Html[$index])
        $index++
    }

    return $output.ToString()
}

if (-not (Test-Path -LiteralPath $IndexPath -PathType Leaf)) {
    Add-Failure "index.html is missing: $IndexPath"
}
else {
    $html = Get-Content -Raw -Encoding UTF8 -LiteralPath $IndexPath
    # Ignore real HTML comments without interpreting script/style or attributes as comments.
    $html = Remove-HtmlComments -Html $html

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

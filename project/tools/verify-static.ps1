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

function Find-HtmlBogusCommentEnd([string]$Html, [int]$StartIndex) {
    for ($index = $StartIndex; $index -lt $Html.Length; $index++) {
        if ($Html[$index] -eq '>') { return $index }
    }
    return -1
}

function Read-HtmlTag([string]$Html, [int]$StartIndex) {
    $cursor = $StartIndex + 1
    if ($cursor -ge $Html.Length) { return $null }

    if ($Html[$cursor] -eq '!' -or $Html[$cursor] -eq '?') {
        # Declarations never supply this static contract; discard through the tokenizer's first >.
        $end = Find-HtmlBogusCommentEnd -Html $Html -StartIndex $cursor
        if ($end -lt 0) {
            return @{ end = $Html.Length - 1; name = ''; closing = $false; declaration = $true; bogus_comment = $true; incomplete = $true }
        }
        return @{ end = $end; name = ''; closing = $false; declaration = $true; bogus_comment = $true; incomplete = $false }
    }

    $closing = $false
    if ($Html[$cursor] -eq '/') {
        $closing = $true
        $cursor++
        if ($cursor -ge $Html.Length -or -not [char]::IsLetter($Html[$cursor])) {
            # End-tag-open enters bogus-comment state and ends at the first >.
            $end = Find-HtmlBogusCommentEnd -Html $Html -StartIndex $cursor
            if ($end -lt 0) { return @{ end = $Html.Length - 1; name = ''; closing = $false; declaration = $true; bogus_comment = $true; incomplete = $true } }
            return @{ end = $end; name = ''; closing = $false; declaration = $true; bogus_comment = $true; incomplete = $false }
        }
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

function Test-HtmlNameBoundary([string]$Html, [int]$Index) {
    if ($Index -ge $Html.Length) { return $false }
    $character = $Html[$Index]
    return $character -eq '>' -or $character -eq '/' -or $character -eq ' ' -or
        $character -eq "`t" -or $character -eq "`n" -or $character -eq "`f" -or $character -eq "`r"
}

function Test-HtmlPrefix([string]$Html, [int]$Index, [string]$Prefix) {
    if ($Index + $Prefix.Length -gt $Html.Length) { return $false }
    return [string]::Compare($Html, $Index, $Prefix, 0, $Prefix.Length, [System.StringComparison]::OrdinalIgnoreCase) -eq 0
}

function Find-HtmlScriptEndTag([string]$Html, [int]$StartIndex) {
    # Script data has escaped and double-escaped states; the first textual </script>
    # can return to the escaped state without ending the element.
    $state = 'data'
    $index = $StartIndex
    while ($index -lt $Html.Length) {
        if ($state -ne 'data' -and $index + 2 -lt $Html.Length -and $Html.Substring($index, 3) -ceq '-->') {
            $state = 'data'
            $index += 3
            continue
        }

        if ($Html[$index] -ne '<') {
            $index++
            continue
        }

        if ($state -eq 'data') {
            if (Test-HtmlPrefix -Html $Html -Index $index -Prefix '<!--') {
                $state = 'escaped'
                $index += 4
                continue
            }
            if ((Test-HtmlPrefix -Html $Html -Index $index -Prefix '</script') -and
                (Test-HtmlNameBoundary -Html $Html -Index ($index + 8))) {
                return $index
            }
        }
        elseif ($state -eq 'escaped') {
            if ((Test-HtmlPrefix -Html $Html -Index $index -Prefix '</script') -and
                (Test-HtmlNameBoundary -Html $Html -Index ($index + 8))) {
                return $index
            }
            if ((Test-HtmlPrefix -Html $Html -Index $index -Prefix '<script') -and
                (Test-HtmlNameBoundary -Html $Html -Index ($index + 7))) {
                $state = 'double-escaped'
                $index += 7
                continue
            }
        }
        else {
            if ((Test-HtmlPrefix -Html $Html -Index $index -Prefix '</script') -and
                (Test-HtmlNameBoundary -Html $Html -Index ($index + 8))) {
                $state = 'escaped'
                $index += 8
                continue
            }
        }

        $index++
    }

    return -1
}

function Find-HtmlRawTextEndTag([string]$Html, [string]$TagName, [int]$StartIndex) {
    if ($TagName -eq 'script') {
        return Find-HtmlScriptEndTag -Html $Html -StartIndex $StartIndex
    }

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
    # Bounded scanner for comment stripping; not a full HTML5 tokenizer or DOM/namespace validator.
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

        if (Test-HtmlPrefix -Html $Html -Index $index -Prefix '<![CDATA[') {
            Add-Failure "CDATA section cannot be safely checked by the static verifier"
            return $Html
        }

        if ($Html[$index] -eq '<') {
            $tag = Read-HtmlTag -Html $Html -StartIndex $index
            if ($null -ne $tag) {
                if ($tag.bogus_comment) {
                    $index = $tag.end + 1
                    if ($tag.incomplete) { break }
                    continue
                }

                $tagLength = $tag.end - $index + 1
                if ($tagLength -gt 0) {
                    [void]$output.Append($Html, $index, $tagLength)
                }
                $commentMarkersAreText = $tag.name -in @('script', 'style', 'title', 'textarea', 'xmp', 'iframe', 'noembed', 'noframes', 'noscript')
                if (-not $tag.declaration -and -not $tag.closing -and -not $tag.incomplete -and $commentMarkersAreText) {
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

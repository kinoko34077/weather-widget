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

    $commentedAnchor = Join-Path $tempDir "commented-anchor.html"
    [regex]::Replace($current, '(?is)(<a\b.*?</a>)', '<!--$1-->') |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $commentedAnchor
    Invoke-Case -Name "commented anchor and forecast target fail" -IndexPath $commentedAnchor -ExpectedExitCode 1

    $commentedLoader = Join-Path $tempDir "commented-loader.html"
    [regex]::Replace($current, '(?is)(<script\b[^>]*>.*?weatherwidget\.io/js/widget\.min\.js.*?</script>)', '<!--$1-->') |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $commentedLoader
    Invoke-Case -Name "commented loader fails" -IndexPath $commentedLoader -ExpectedExitCode 1

    $commentedStylesheet = Join-Path $tempDir "commented-stylesheet.html"
    $current.Replace('<link rel="stylesheet" href="style.css" />', '<!-- <link rel="stylesheet" href="style.css" /> -->') |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $commentedStylesheet
    Invoke-Case -Name "commented stylesheet fails" -IndexPath $commentedStylesheet -ExpectedExitCode 1

    $unrelatedComment = Join-Path $tempDir "unrelated-comment.html"
    $current.Replace('</body>', '<!-- unrelated note --></body>') |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $unrelatedComment
    Invoke-Case -Name "unrelated comment preserves active markup" -IndexPath $unrelatedComment -ExpectedExitCode 0

    $unterminatedBeforeMarkup = Join-Path $tempDir "unterminated-before-markup.html"
    ('<!--' + $current) | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $unterminatedBeforeMarkup
    Invoke-Case -Name "unterminated comment before markup fails closed" -IndexPath $unterminatedBeforeMarkup -ExpectedExitCode 1

    $unterminatedAfterMarkup = Join-Path $tempDir "unterminated-after-markup.html"
    ($current + '<!--') | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $unterminatedAfterMarkup
    Invoke-Case -Name "unterminated comment after active markup preserves checks" -IndexPath $unterminatedAfterMarkup -ExpectedExitCode 0

    $commentedPwa = Join-Path $tempDir "commented-pwa.html"
    $commentedPwaMarkup = '<!-- <link rel="manifest" href="manifest.webmanifest" /><script>navigator.serviceWorker.register("./service-worker.js");</script> -->' + [Environment]::NewLine + '</body>'
    $current.Replace('</body>', $commentedPwaMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $commentedPwa
    Invoke-Case -Name "commented PWA markup does not trigger activation checks" -IndexPath $commentedPwa -ExpectedExitCode 0

    $emptyCommentManifest = Join-Path $tempDir "empty-comment-active-manifest.html"
    $emptyCommentManifestMarkup = '<!--><link rel="manifest" href="manifest.webmanifest" /><!-- separator --></body>'
    $current.Replace('</body>', $emptyCommentManifestMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $emptyCommentManifest
    Invoke-Case -Name "empty comment before active manifest does not hide activation" -IndexPath $emptyCommentManifest -ExpectedExitCode 1

    $emptyCommentServiceWorker = Join-Path $tempDir "empty-comment-active-service-worker.html"
    $emptyCommentServiceWorkerMarkup = '<!---><script>navigator.serviceWorker.register("./service-worker.js");</script><!-- separator --></body>'
    $current.Replace('</body>', $emptyCommentServiceWorkerMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $emptyCommentServiceWorker
    Invoke-Case -Name "empty hyphen comment before active service worker does not hide activation" -IndexPath $emptyCommentServiceWorker -ExpectedExitCode 1

    $bangClosedActiveManifest = Join-Path $tempDir "bang-closed-active-manifest.html"
    $bangClosedManifestMarkup = '<!-- note --!><link rel="manifest" href="manifest.webmanifest" /><!-- separator --></body>'
    $current.Replace('</body>', $bangClosedManifestMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $bangClosedActiveManifest
    Invoke-Case -Name "bang-closed comment does not hide active manifest" -IndexPath $bangClosedActiveManifest -ExpectedExitCode 1

    $scriptCommentMarker = Join-Path $tempDir "script-comment-marker-active-service-worker.html"
    $scriptCommentMarkup = '<script>var marker = "<!--"; navigator.serviceWorker.register("./service-worker.js");</script><!-- separator --></body>'
    $current.Replace('</body>', $scriptCommentMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $scriptCommentMarker
    Invoke-Case -Name "script comment marker does not hide active service worker" -IndexPath $scriptCommentMarker -ExpectedExitCode 1

    $styleCommentMarker = Join-Path $tempDir "style-comment-marker-active-manifest.html"
    $styleCommentMarkup = '<style>.marker::after { content: "<!--"; }</style><link rel="manifest" href="manifest.webmanifest" /><!-- separator --></body>'
    $current.Replace('</body>', $styleCommentMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $styleCommentMarker
    Invoke-Case -Name "style comment marker does not hide active manifest" -IndexPath $styleCommentMarker -ExpectedExitCode 1

    $textareaCommentMarker = Join-Path $tempDir "textarea-comment-marker-active-manifest.html"
    $textareaCommentMarkup = '<textarea><!--</textarea><link rel="manifest" href="manifest.webmanifest" /><!-- separator --></body>'
    $current.Replace('</body>', $textareaCommentMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $textareaCommentMarker
    Invoke-Case -Name "textarea comment marker does not hide active manifest" -IndexPath $textareaCommentMarker -ExpectedExitCode 1

    $titleCommentMarker = Join-Path $tempDir "title-comment-marker-active-service-worker.html"
    $titleCommentMarkup = '<title><!--</title><script>navigator.serviceWorker.register("./service-worker.js");</script><!-- separator --></body>'
    $current.Replace('</body>', $titleCommentMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $titleCommentMarker
    Invoke-Case -Name "title comment marker does not hide active service worker" -IndexPath $titleCommentMarker -ExpectedExitCode 1

    $attributeCommentMarker = Join-Path $tempDir "attribute-comment-marker-active-service-worker.html"
    $attributeCommentMarkup = '<div data-note="<!--"></div><script>navigator.serviceWorker.register("./service-worker.js");</script><!-- separator --></body>'
    $current.Replace('</body>', $attributeCommentMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $attributeCommentMarker
    Invoke-Case -Name "attribute comment marker does not hide active service worker" -IndexPath $attributeCommentMarker -ExpectedExitCode 1

    $scriptDoubleEscapeActiveManifest = Join-Path $tempDir "script-double-escape-active-manifest.html"
    $scriptDoubleEscapeMarkup = '<script><!--<script></script><!-- </script><link rel="manifest" href="manifest.webmanifest"> --></script>' + [Environment]::NewLine + '</body>'
    $current.Replace('</body>', $scriptDoubleEscapeMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $scriptDoubleEscapeActiveManifest
    Invoke-Case -Name "script double-escape state does not hide active manifest" -IndexPath $scriptDoubleEscapeActiveManifest -ExpectedExitCode 1

    $malformedEndTagActiveManifest = Join-Path $tempDir "malformed-end-tag-active-manifest.html"
    $malformedEndTagMarkup = '</ <link rel="manifest" href="manifest.webmanifest" />' + [Environment]::NewLine + '</body>'
    $current.Replace('</body>', $malformedEndTagMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $malformedEndTagActiveManifest
    Invoke-Case -Name "malformed end-tag open preserves following active manifest" -IndexPath $malformedEndTagActiveManifest -ExpectedExitCode 1

    $cdataHiddenManifest = Join-Path $tempDir "cdata-hidden-active-manifest.html"
    $cdataHiddenManifestMarkup = '<svg><![CDATA[ > <!-- ]]></svg><link rel="manifest" href="manifest.webmanifest"><!-- separator --></body>' + [Environment]::NewLine
    $current.Replace('</body>', $cdataHiddenManifestMarkup) |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $cdataHiddenManifest
    Invoke-Case -Name "CDATA content cannot hide active manifest" -IndexPath $cdataHiddenManifest -ExpectedExitCode 1

    $bogusDeclarationComment = Join-Path $tempDir "bogus-declaration-commented-contract.html"
    $bogusDeclarationCommentMarkup = '<!bogus "><!-- <a class="weatherwidget-io" href="https://forecast7.com/ja/35d69139d69/tokyo/">Tokyo</a><script src="https://weatherwidget.io/js/widget.min.js"></script><link rel="stylesheet" href="style.css" /><!-- separator -->'
    [System.IO.File]::WriteAllText($bogusDeclarationComment, $bogusDeclarationCommentMarkup, [System.Text.UTF8Encoding]::new($false))
    Invoke-Case -Name "bogus declaration cannot expose commented contract markup" -IndexPath $bogusDeclarationComment -ExpectedExitCode 1

    $malformedEndTagAnchor = Join-Path $tempDir "malformed-end-tag-commented-anchor.html"
    [regex]::Replace($current, '(?is)(<a\b.*?</a>)', '</ $1') |
        Set-Content -Encoding UTF8 -NoNewline -LiteralPath $malformedEndTagAnchor
    Invoke-Case -Name "malformed end-tag open cannot expose commented anchor" -IndexPath $malformedEndTagAnchor -ExpectedExitCode 1

    $malformedEndTagComment = Join-Path $tempDir "malformed-end-tag-commented-contract.html"
    $malformedEndTagCommentMarkup = '</<!-- > <a class="weatherwidget-io" href="https://forecast7.com/ja/35d69139d69/tokyo/">Tokyo</a><script src="https://weatherwidget.io/js/widget.min.js"></script><link rel="stylesheet" href="style.css" /><!-- separator -->'
    [System.IO.File]::WriteAllText($malformedEndTagComment, $malformedEndTagCommentMarkup, [System.Text.UTF8Encoding]::new($false))
    Invoke-Case -Name "malformed end-tag cannot truncate a following real comment" -IndexPath $malformedEndTagComment -ExpectedExitCode 1

    $malformedDoctypeComment = Join-Path $tempDir "malformed-doctype-commented-contract.html"
    $malformedDoctypeCommentMarkup = '<!DOCTYPE "><!-- <a class="weatherwidget-io" href="https://forecast7.com/ja/35d69139d69/tokyo/">Tokyo</a><script src="https://weatherwidget.io/js/widget.min.js"></script><link rel="stylesheet" href="style.css" /><!-- separator -->'
    [System.IO.File]::WriteAllText($malformedDoctypeComment, $malformedDoctypeCommentMarkup, [System.Text.UTF8Encoding]::new($false))
    Invoke-Case -Name "malformed doctype cannot expose commented contract markup" -IndexPath $malformedDoctypeComment -ExpectedExitCode 1

    $crlf = Join-Path $tempDir "crlf.html"
    $crlfContent = $current.Replace("`n", "`r`n")
    [System.IO.File]::WriteAllText($crlf, $crlfContent, [System.Text.UTF8Encoding]::new($false))
    Invoke-Case -Name "CRLF input preserves active markup" -IndexPath $crlf -ExpectedExitCode 0

    $empty = Join-Path $tempDir "empty.html"
    [System.IO.File]::WriteAllText($empty, "", [System.Text.UTF8Encoding]::new($false))
    Invoke-Case -Name "empty input fails required markup checks" -IndexPath $empty -ExpectedExitCode 1
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

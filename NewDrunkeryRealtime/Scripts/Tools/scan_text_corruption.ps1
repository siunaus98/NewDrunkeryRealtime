$ErrorActionPreference = 'Stop'

$projectRoot = 'D:\P-ND\NP\NewDrunkeryRealtime'
$targetExtensions = @('.gd', '.tscn', '.md', '.godot')
$skipDirs = @('.godot', '.git')
$replacementChar = [char]0xFFFD
$findings = New-Object System.Collections.Generic.List[string]
$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)

$suspiciousCodepoints = @(
    0x951F,
    0x70EB,
    0x9474,
    0x95BF,
    0x93C2,
    0x935F,
    0x6769,
    0x7487,
    0x7481,
    0x9514,
    0x7F01,
    0x9510,
    0x5BEE,
    0x6C18,
    0x7EBE,
    0x6FB6,
    0x699B
)

$suspiciousChars = @()
foreach ($codepoint in $suspiciousCodepoints) {
    $suspiciousChars += [string][char]$codepoint
}

Get-ChildItem -LiteralPath $projectRoot -Recurse -File | ForEach-Object {
    $file = $_
    $pathParts = $file.FullName -split '[\\/]'
    if (($skipDirs | Where-Object { $pathParts -contains $_ }).Count -gt 0) {
        return
    }
    if ($targetExtensions -notcontains $file.Extension.ToLowerInvariant()) {
        return
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $text = $utf8Strict.GetString($bytes)
    } catch {
        $findings.Add(('{0}: decode_error: {1}' -f $file.FullName, $_.Exception.Message))
        return
    }

    $lines = $text -split "`r?`n"
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        $matched = $false

        foreach ($charValue in $suspiciousChars) {
            if ($line.Contains($charValue)) {
                $findings.Add(('{0}:{1}: suspicious_char: {2}' -f $file.FullName, ($i + 1), $line.Trim()))
                $matched = $true
                break
            }
        }

        if ($matched) {
            continue
        }

        if ($line.Contains([string]$replacementChar)) {
            $findings.Add(('{0}:{1}: replacement_char: {2}' -f $file.FullName, ($i + 1), $line.Trim()))
        }
    }
}

if ($findings.Count -eq 0) {
    Write-Output 'No suspicious text corruption patterns found.'
    exit 0
}

Write-Output 'Suspicious text corruption findings:'
$findings
exit 1

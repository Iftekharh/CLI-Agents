<#
.SYNOPSIS
    HTML Report Generator
.DESCRIPTION
    Generates standard HTML reports from JSON data
.PARAMETER InputPath
    Path to JSON report file
.EXAMPLE
    .\html-generator.ps1 -InputPath ".\reports\comprehensive-report-20260128-202824.json"
#>

param([string]$InputPath)

if (!$InputPath) {
    Write-Host "Usage: .\html-generator.ps1 -InputPath <json-file>" -ForegroundColor Yellow
    exit 1
}

if (!(Test-Path $InputPath)) {
    Write-Host "❌ File not found: $InputPath" -ForegroundColor Red
    exit 1
}

Write-Host "🔧 Generating HTML report..." -ForegroundColor Cyan

# Delegate to the colorful generator for now
& "$PSScriptRoot\Generate-ComprehensiveColorful.ps1" -ReportPath $InputPath

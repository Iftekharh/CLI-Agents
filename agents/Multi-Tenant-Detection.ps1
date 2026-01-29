<#
.SYNOPSIS
    Multi-Tenant Detection Framework Base
.DESCRIPTION
    Foundation framework for multi-tenant security detection
.EXAMPLE
    .\Multi-Tenant-Detection.ps1
#>

Write-Host "`n🔐 Multi-Tenant Detection Framework" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════`n" -ForegroundColor Cyan

# This is a framework wrapper - use Consolidated-Multi-Tenant-Detection.ps1 for full implementation
& "$PSScriptRoot\Consolidated-Multi-Tenant-Detection.ps1" @args

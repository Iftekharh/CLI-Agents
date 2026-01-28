# ====================================================================
# Sentinel MCP Agents - New Machine Setup Script
# ====================================================================
# Automates deployment of the agent framework on a new computer
# Run this after cloning the repository
# ====================================================================

param(
    [switch]$SkipPrerequisites,
    [switch]$SkipConfiguration
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🚀 Sentinel MCP Agents - New Machine Setup                         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ====================================================================
# Step 1: Check Prerequisites
# ====================================================================

if (-not $SkipPrerequisites) {
    Write-Host "📋 Step 1: Checking Prerequisites..." -ForegroundColor Yellow
    Write-Host ""
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Host "  PowerShell Version: " -NoNewline
    if ($psVersion.Major -ge 7) {
        Write-Host "$psVersion ✓" -ForegroundColor Green
    } else {
        Write-Host "$psVersion (PowerShell 7+ recommended)" -ForegroundColor Yellow
    }
    
    # Check Azure CLI
    Write-Host "  Azure CLI: " -NoNewline
    try {
        $azVersion = az version --query '\"azure-cli\"' -o tsv 2>$null
        if ($azVersion) {
            Write-Host "$azVersion ✓" -ForegroundColor Green
        } else {
            throw "Not found"
        }
    }
    catch {
        Write-Host "Not installed ✗" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Please install Azure CLI:" -ForegroundColor Yellow
        Write-Host "  https://learn.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Gray
        Write-Host ""
        $install = Read-Host "Continue anyway? (y/N)"
        if ($install -ne 'y') { exit 1 }
    }
    
    # Check Git
    Write-Host "  Git: " -NoNewline
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            Write-Host "$gitVersion ✓" -ForegroundColor Green
        } else {
            throw "Not found"
        }
    }
    catch {
        Write-Host "Not installed ✗" -ForegroundColor Yellow
        Write-Host "  (Optional but recommended)" -ForegroundColor Gray
    }
    
    # Check PSWritePDF module (for PDF reports)
    Write-Host "  PSWritePDF Module: " -NoNewline
    if (Get-Module -ListAvailable -Name PSWritePDF) {
        Write-Host "Installed ✓" -ForegroundColor Green
    } else {
        Write-Host "Not installed" -ForegroundColor Yellow
        Write-Host ""
        $installPdf = Read-Host "  Install PSWritePDF for PDF report generation? (y/N)"
        if ($installPdf -eq 'y') {
            Write-Host "  Installing PSWritePDF..." -ForegroundColor Cyan
            Install-Module -Name PSWritePDF -Scope CurrentUser -Force -AllowClobber
            Write-Host "  ✓ PSWritePDF installed" -ForegroundColor Green
        }
    }
    
    Write-Host ""
}

# ====================================================================
# Step 2: Create Directory Structure
# ====================================================================

Write-Host "📁 Step 2: Creating Directory Structure..." -ForegroundColor Yellow
Write-Host ""

$directories = @(
    "reports",
    "baselines", 
    "anomalies",
    "logs"
)

foreach ($dir in $directories) {
    $path = Join-Path $PSScriptRoot $dir
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        # Create .gitkeep to preserve empty directories
        New-Item -Path (Join-Path $path ".gitkeep") -ItemType File -Force | Out-Null
        Write-Host "  Created: $dir\" -ForegroundColor Green
    } else {
        Write-Host "  Exists:  $dir\" -ForegroundColor Gray
    }
}

Write-Host ""

# ====================================================================
# Step 3: Configure Environment Files
# ====================================================================

if (-not $SkipConfiguration) {
    Write-Host "⚙️  Step 3: Configuring Environment..." -ForegroundColor Yellow
    Write-Host ""
    
    # Create mcp.json from template
    $mcpConfigPath = Join-Path $PSScriptRoot "mcp.json"
    $mcpTemplatePath = Join-Path $PSScriptRoot "mcp.json.template"
    
    if (-not (Test-Path $mcpConfigPath)) {
        if (Test-Path $mcpTemplatePath) {
            Copy-Item $mcpTemplatePath $mcpConfigPath
            Write-Host "  ✓ Created mcp.json from template" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Template mcp.json.template not found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ℹ️  mcp.json already exists (not overwriting)" -ForegroundColor Cyan
    }
    
    # Create mcp-environments.json from template
    $envConfigPath = Join-Path $PSScriptRoot "mcp-environments.json"
    $envTemplatePath = Join-Path $PSScriptRoot "mcp-environments.json.template"
    
    if (-not (Test-Path $envConfigPath)) {
        if (Test-Path $envTemplatePath) {
            Copy-Item $envTemplatePath $envConfigPath
            Write-Host "  ✓ Created mcp-environments.json from template" -ForegroundColor Green
            Write-Host ""
            Write-Host "  📝 Next: Edit mcp-environments.json with your Sentinel workspace details:" -ForegroundColor Yellow
            Write-Host "     • tenantId (your Azure tenant ID)" -ForegroundColor Gray
            Write-Host "     • workspaceId (your Sentinel workspace ID)" -ForegroundColor Gray
            Write-Host "     • displayName (friendly name for the environment)" -ForegroundColor Gray
        } else {
            Write-Host "  ⚠️  Template mcp-environments.json.template not found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ℹ️  mcp-environments.json already exists (not overwriting)" -ForegroundColor Cyan
    }
    
    Write-Host ""
}

# ====================================================================
# Step 4: Azure Authentication
# ====================================================================

Write-Host "🔐 Step 4: Azure Authentication..." -ForegroundColor Yellow
Write-Host ""

$azLogin = Read-Host "Authenticate with Azure now? (y/N)"
if ($azLogin -eq 'y') {
    Write-Host "  Launching Azure CLI login..." -ForegroundColor Cyan
    az login
    
    Write-Host ""
    Write-Host "  ✓ Azure authentication complete" -ForegroundColor Green
    Write-Host ""
}

# ====================================================================
# Step 5: First-Time Configuration Wizard
# ====================================================================

Write-Host "🧙 Step 5: Quick Configuration Wizard..." -ForegroundColor Yellow
Write-Host ""

$configure = Read-Host "Configure your first Sentinel environment now? (y/N)"
if ($configure -eq 'y') {
    Write-Host ""
    
    # Get environment details
    $envName = Read-Host "  Environment name (e.g., 'production', 'woodgrove')"
    if ([string]::IsNullOrEmpty($envName)) { $envName = "default" }
    
    $displayName = Read-Host "  Display name (e.g., 'Production Sentinel')"
    if ([string]::IsNullOrEmpty($displayName)) { $displayName = $envName }
    
    $tenantId = Read-Host "  Tenant ID (leave empty to detect from Azure CLI)"
    if ([string]::IsNullOrEmpty($tenantId)) {
        try {
            $tenantId = az account show --query tenantId -o tsv
            Write-Host "    Detected: $tenantId" -ForegroundColor Green
        }
        catch {
            Write-Host "    Could not auto-detect tenant ID" -ForegroundColor Yellow
        }
    }
    
    $workspaceId = Read-Host "  Workspace ID"
    
    # Update mcp-environments.json
    $envConfigPath = Join-Path $PSScriptRoot "mcp-environments.json"
    if (Test-Path $envConfigPath) {
        $envConfig = Get-Content $envConfigPath | ConvertFrom-Json
        
        $envConfig.environments.$envName = @{
            displayName = $displayName
            tenantId = $tenantId
            resourceId = "4500ebfb-89b6-4b14-a480-7f749797bfcd"
            mcpServerUrl = "https://sentinel.microsoft.com/mcp/data-exploration"
            workspaceId = $workspaceId
            description = "Configured via setup wizard"
        }
        
        $envConfig.currentEnvironment = $envName
        
        $envConfig | ConvertTo-Json -Depth 10 | Set-Content $envConfigPath
        
        Write-Host ""
        Write-Host "  ✓ Environment '$envName' configured!" -ForegroundColor Green
        Write-Host ""
        
        # Activate the environment
        $activateNow = Read-Host "Activate this environment now? (y/N)"
        if ($activateNow -eq 'y') {
            $mcpEnvScript = Join-Path $PSScriptRoot "mcp-env.ps1"
            if (Test-Path $mcpEnvScript) {
                & $mcpEnvScript use $envName
            }
        }
    }
}

# ====================================================================
# Setup Complete
# ====================================================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ SETUP COMPLETE!                                                 ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Review configuration files:" -ForegroundColor Cyan
Write-Host "     • mcp-environments.json (environment profiles)" -ForegroundColor Gray
Write-Host "     • agents\anomaly-hunter\anomaly-hunter-config.json (agent settings)" -ForegroundColor Gray

Write-Host ""
Write-Host "  2. Activate an environment:" -ForegroundColor Cyan
Write-Host "     .\mcp-env.ps1 use <environment-name>" -ForegroundColor Gray

Write-Host ""
Write-Host "  3. Run the Anomaly Hunter agent:" -ForegroundColor Cyan
Write-Host "     cd agents\anomaly-hunter" -ForegroundColor Gray
Write-Host "     .\anomaly-hunter-agent.ps1 -Mode scan -Environment <environment-name>" -ForegroundColor Gray

Write-Host ""
Write-Host "  4. Read the documentation:" -ForegroundColor Cyan
Write-Host "     • README.md (overview)" -ForegroundColor Gray
Write-Host "     • QUICK-REFERENCE.md (command cheat sheet)" -ForegroundColor Gray
Write-Host "     • agents\anomaly-hunter\ANOMALY-HUNTER-README.md (agent details)" -ForegroundColor Gray

Write-Host ""
Write-Host "📚 Additional Resources:" -ForegroundColor Yellow
Write-Host "  • MCP-ENVIRONMENT-SETUP.md - Environment management guide" -ForegroundColor Gray
Write-Host "  • TOKEN-AUTOMATION-GUIDE.md - Token refresh automation" -ForegroundColor Gray
Write-Host "  • security-agent-use-cases.md - Ideas for new agents" -ForegroundColor Gray

Write-Host ""
Write-Host "Happy Hunting! 🎯" -ForegroundColor Green
Write-Host ""

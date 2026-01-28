# Token Decoder - Find Resource ID from JWT
# Decodes your existing JWT token to extract resource ID and other details

param(
    [Parameter(Mandatory=$false)]
    [string]$Token,
    
    [Parameter(Mandatory=$false)]
    [string]$McpConfigPath = "C:\App\loop\mcp.json"
)

function Decode-JwtToken {
    param([string]$JwtToken)
    
    # Remove "Bearer " prefix if present
    $JwtToken = $JwtToken -replace "^Bearer\s+", ""
    
    # Split token into parts (header.payload.signature)
    $parts = $JwtToken.Split('.')
    
    if ($parts.Count -lt 2) {
        Write-Host "ERROR: Invalid JWT token format" -ForegroundColor Red
        return $null
    }
    
    try {
        # Decode header (first part)
        $headerPart = $parts[0]
        while ($headerPart.Length % 4 -ne 0) { $headerPart += "=" }
        $headerBytes = [Convert]::FromBase64String($headerPart)
        $headerJson = [System.Text.Encoding]::UTF8.GetString($headerBytes)
        $header = $headerJson | ConvertFrom-Json
        
        # Decode payload (second part)
        $payloadPart = $parts[1]
        while ($payloadPart.Length % 4 -ne 0) { $payloadPart += "=" }
        $payloadBytes = [Convert]::FromBase64String($payloadPart)
        $payloadJson = [System.Text.Encoding]::UTF8.GetString($payloadBytes)
        $payload = $payloadJson | ConvertFrom-Json
        
        return @{
            Header = $header
            Payload = $payload
        }
    }
    catch {
        Write-Host "ERROR: Failed to decode token: $_" -ForegroundColor Red
        return $null
    }
}

function Format-DateTime {
    param([int]$UnixTimestamp)
    if ($UnixTimestamp -gt 0) {
        return [DateTimeOffset]::FromUnixTimeSeconds($UnixTimestamp).LocalDateTime.ToString('yyyy-MM-dd HH:mm:ss')
    }
    return "N/A"
}

# Main script
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    JWT TOKEN DECODER                                  ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get token from parameter or config file
if ([string]::IsNullOrEmpty($Token)) {
    if (Test-Path $McpConfigPath) {
        Write-Host "Reading token from: $McpConfigPath" -ForegroundColor Gray
        try {
            $config = Get-Content $McpConfigPath -Raw | ConvertFrom-Json
            $Token = $config.servers.'mcp-sentinel'.headers.Authorization -replace "^Bearer\s+", ""
        }
        catch {
            Write-Host "ERROR: Could not read token from config file" -ForegroundColor Red
            Write-Host "Please provide token via -Token parameter" -ForegroundColor Yellow
            exit 1
        }
    }
    else {
        Write-Host "ERROR: Config file not found: $McpConfigPath" -ForegroundColor Red
        Write-Host "Usage: .\decode-token.ps1 -Token 'your-jwt-token'" -ForegroundColor Yellow
        exit 1
    }
}

# Decode the token
$decoded = Decode-JwtToken -JwtToken $Token

if ($null -eq $decoded) {
    exit 1
}

$payload = $decoded.Payload
$header = $decoded.Header

# Display results
Write-Host "┌─────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "│ TOKEN HEADER                                                        │" -ForegroundColor White
Write-Host "├─────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

if ($header.typ) {
    Write-Host "│ Type:              " -NoNewline -ForegroundColor Gray
    Write-Host $header.typ.PadRight(48) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor White
}
if ($header.alg) {
    Write-Host "│ Algorithm:         " -NoNewline -ForegroundColor Gray
    Write-Host $header.alg.PadRight(48) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor White
}
if ($header.kid) {
    Write-Host "│ Key ID:            " -NoNewline -ForegroundColor Gray
    Write-Host $header.kid.PadRight(48) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor White
}

Write-Host "└─────────────────────────────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

Write-Host "┌─────────────────────────────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host "│ 🎯 KEY INFORMATION FOR TOKEN GENERATION                            │" -ForegroundColor Green
Write-Host "├─────────────────────────────────────────────────────────────────────┤" -ForegroundColor Green

Write-Host "│ " -NoNewline -ForegroundColor Green
Write-Host "Resource ID (aud): " -NoNewline -ForegroundColor Yellow
Write-Host $payload.aud.PadRight(43) -NoNewline -ForegroundColor Cyan
Write-Host "│" -ForegroundColor Green

Write-Host "│ " -NoNewline -ForegroundColor Green
Write-Host "Tenant ID (tid):   " -NoNewline -ForegroundColor Yellow
Write-Host $payload.tid.PadRight(43) -NoNewline -ForegroundColor Cyan
Write-Host "│" -ForegroundColor Green

Write-Host "└─────────────────────────────────────────────────────────────────────┘" -ForegroundColor Green
Write-Host ""

Write-Host "┌─────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "│ AUTHENTICATION DETAILS                                              │" -ForegroundColor White
Write-Host "├─────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

if ($payload.iss) {
    Write-Host "│ Issuer:            " -NoNewline -ForegroundColor Gray
    $issuer = $payload.iss
    if ($issuer.Length -gt 48) { $issuer = $issuer.Substring(0, 45) + "..." }
    Write-Host $issuer.PadRight(48) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor White
}

if ($payload.azp) {
    Write-Host "│ Client App ID:     " -NoNewline -ForegroundColor Gray
    Write-Host $payload.azp.PadRight(48) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor White
}

if ($payload.name) {
    Write-Host "│ User Name:         " -NoNewline -ForegroundColor Gray
    $name = $payload.name
    if ($name.Length -gt 48) { $name = $name.Substring(0, 45) + "..." }
    Write-Host $name.PadRight(48) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor White
}

if ($payload.preferred_username) {
    Write-Host "│ User Principal:    " -NoNewline -ForegroundColor Gray
    $upn = $payload.preferred_username
    if ($upn.Length -gt 48) { $upn = $upn.Substring(0, 45) + "..." }
    Write-Host $upn.PadRight(48) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor White
}

Write-Host "└─────────────────────────────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

Write-Host "┌─────────────────────────────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "│ TOKEN VALIDITY                                                      │" -ForegroundColor White
Write-Host "├─────────────────────────────────────────────────────────────────────┤" -ForegroundColor White

$issuedAt = Format-DateTime -UnixTimestamp $payload.iat
$expiresAt = Format-DateTime -UnixTimestamp $payload.exp
$notBefore = Format-DateTime -UnixTimestamp $payload.nbf

Write-Host "│ Issued At:         " -NoNewline -ForegroundColor Gray
Write-Host $issuedAt.PadRight(48) -NoNewline -ForegroundColor White
Write-Host "│" -ForegroundColor White

Write-Host "│ Not Before:        " -NoNewline -ForegroundColor Gray
Write-Host $notBefore.PadRight(48) -NoNewline -ForegroundColor White
Write-Host "│" -ForegroundColor White

Write-Host "│ Expires At:        " -NoNewline -ForegroundColor Gray
$expiryColor = "White"
$now = Get-Date
$expiry = [DateTimeOffset]::FromUnixTimeSeconds($payload.exp).LocalDateTime

if ($expiry -lt $now) {
    $expiryColor = "Red"
    $expiresAt += " ⚠️ EXPIRED"
}
elseif (($expiry - $now).TotalMinutes -lt 15) {
    $expiryColor = "Yellow"
    $expiresAt += " ⚠️ EXPIRING SOON"
}

Write-Host $expiresAt.PadRight(48) -NoNewline -ForegroundColor $expiryColor
Write-Host "│" -ForegroundColor White

if ($expiry -gt $now) {
    $timeLeft = $expiry - $now
    $timeLeftStr = ""
    if ($timeLeft.TotalDays -ge 1) {
        $timeLeftStr = "$([math]::Floor($timeLeft.TotalDays)) days, $($timeLeft.Hours) hours remaining"
    }
    elseif ($timeLeft.TotalHours -ge 1) {
        $timeLeftStr = "$([math]::Floor($timeLeft.TotalHours)) hours, $($timeLeft.Minutes) minutes remaining"
    }
    else {
        $timeLeftStr = "$([math]::Floor($timeLeft.TotalMinutes)) minutes remaining"
    }
    
    Write-Host "│ Time Remaining:    " -NoNewline -ForegroundColor Gray
    Write-Host $timeLeftStr.PadRight(48) -NoNewline -ForegroundColor Green
    Write-Host "│" -ForegroundColor White
}

Write-Host "└─────────────────────────────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

# Usage instructions
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TO GENERATE A NEW TOKEN WITH THESE VALUES:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Using Azure CLI:" -ForegroundColor Yellow
Write-Host "  az login --tenant $($payload.tid)" -ForegroundColor Gray
Write-Host "  az account get-access-token --resource $($payload.aud)" -ForegroundColor Gray
Write-Host ""
Write-Host "Or use the automation scripts:" -ForegroundColor Yellow
Write-Host "  .\mcp-token-refresh.ps1" -ForegroundColor Gray
Write-Host ""

# Export to variables for scripting
$global:RESOURCE_ID = $payload.aud
$global:TENANT_ID = $payload.tid

Write-Host "Variables set for current session:" -ForegroundColor Green
Write-Host "  `$RESOURCE_ID = $($payload.aud)" -ForegroundColor Gray
Write-Host "  `$TENANT_ID = $($payload.tid)" -ForegroundColor Gray
Write-Host ""

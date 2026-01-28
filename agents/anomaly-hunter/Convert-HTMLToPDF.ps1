# Automated HTML to PDF Converter
# Converts Anomaly Hunter HTML reports to PDF automatically

param(
    [Parameter(Mandatory=$false)]
    [string]$HtmlPath,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPdfPath,
    
    [switch]$ConvertLatest
)

function Convert-HTMLToPDF {
    param(
        [string]$HtmlFile,
        [string]$PdfFile
    )
    
    Write-Host "Converting HTML to PDF..." -ForegroundColor Cyan
    Write-Host "  Source: $HtmlFile" -ForegroundColor Gray
    Write-Host "  Output: $PdfFile" -ForegroundColor Gray
    Write-Host ""
    
    # Method 1: Try Microsoft Edge (headless)
    try {
        $edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
        if (-not (Test-Path $edgePath)) {
            $edgePath = "msedge"
        }
        
        Write-Host "  Method: Microsoft Edge (headless)" -ForegroundColor Yellow
        
        $arguments = "--headless --disable-gpu --print-to-pdf=`"$PdfFile`" `"$HtmlFile`""
        
        $process = Start-Process -FilePath $edgePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -and (Test-Path $PdfFile)) {
            Write-Host "  ✓ PDF created successfully!" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "  Edge conversion failed: $_" -ForegroundColor Yellow
    }
    
    # Method 2: Try Google Chrome (headless)
    try {
        $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
        if (-not (Test-Path $chromePath)) {
            $chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
        }
        
        if (Test-Path $chromePath) {
            Write-Host "  Method: Google Chrome (headless)" -ForegroundColor Yellow
            
            $arguments = "--headless --disable-gpu --print-to-pdf=`"$PdfFile`" `"$HtmlFile`""
            
            $process = Start-Process -FilePath $chromePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0 -and (Test-Path $PdfFile)) {
                Write-Host "  ✓ PDF created successfully!" -ForegroundColor Green
                return $true
            }
        }
    }
    catch {
        Write-Host "  Chrome conversion failed: $_" -ForegroundColor Yellow
    }
    
    # Method 3: Fallback - provide manual instructions
    Write-Host ""
    Write-Host "  ⚠️  Automated conversion not available" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Manual conversion options:" -ForegroundColor White
    Write-Host "    1. Open HTML file in browser" -ForegroundColor Gray
    Write-Host "    2. Press Ctrl+P" -ForegroundColor Gray
    Write-Host "    3. Select 'Save as PDF'" -ForegroundColor Gray
    Write-Host "    4. Save to: $(Split-Path $PdfFile -Parent)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Opening HTML in browser..." -ForegroundColor Cyan
    Start-Process $HtmlFile
    
    return $false
}

# Main script
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  📄 HTML to PDF Converter                                            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($ConvertLatest) {
    # Find latest HTML report
    $latestHtml = Get-ChildItem "C:\App\loop\reports" -Filter "*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($latestHtml) {
        $HtmlPath = $latestHtml.FullName
        $OutputPdfPath = $HtmlPath -replace '\.html$', '.pdf'
        
        Write-Host "Latest HTML report: $($latestHtml.Name)" -ForegroundColor Green
        Write-Host ""
    }
    else {
        Write-Host "ERROR: No HTML reports found in C:\App\loop\reports" -ForegroundColor Red
        exit 1
    }
}

if ([string]::IsNullOrEmpty($HtmlPath)) {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\Convert-HTMLToPDF.ps1 -HtmlPath 'path\to\report.html'" -ForegroundColor Gray
    Write-Host "  .\Convert-HTMLToPDF.ps1 -ConvertLatest" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

if ([string]::IsNullOrEmpty($OutputPdfPath)) {
    $OutputPdfPath = $HtmlPath -replace '\.html$', '.pdf'
}

if (-not (Test-Path $HtmlPath)) {
    Write-Host "ERROR: HTML file not found: $HtmlPath" -ForegroundColor Red
    exit 1
}

$success = Convert-HTMLToPDF -HtmlFile $HtmlPath -PdfFile $OutputPdfPath

if ($success) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ✅ PDF CREATED SUCCESSFULLY                                        ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "PDF Location: " -NoNewline
    Write-Host $OutputPdfPath -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Opening PDF..." -ForegroundColor Yellow
    Start-Process $OutputPdfPath
}

Write-Host ""

# Flutter Installation Script for Windows
# This script downloads, extracts, and configures Flutter SDK

Write-Host "=== Flutter Installation Script ===" -ForegroundColor Cyan
Write-Host ""

# Configuration
$flutterInstallPath = "C:\src"
$flutterDir = "$flutterInstallPath\flutter"
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
$zipFile = "$env:TEMP\flutter_sdk.zip"

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "NOTE: Not running as administrator. Will add to User PATH only." -ForegroundColor Yellow
    Write-Host "For system-wide installation, restart PowerShell as Administrator." -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: Create installation directory
Write-Host "[1/5] Creating installation directory..." -ForegroundColor Green
if (-not (Test-Path $flutterInstallPath)) {
    New-Item -ItemType Directory -Path $flutterInstallPath -Force | Out-Null
    Write-Host "  Created: $flutterInstallPath" -ForegroundColor Gray
} else {
    Write-Host "  Directory already exists: $flutterInstallPath" -ForegroundColor Gray
}

# Step 2: Download Flutter SDK
Write-Host "[2/5] Downloading Flutter SDK..." -ForegroundColor Green
Write-Host "  This may take several minutes depending on your connection speed..." -ForegroundColor Gray

try {
    # Remove old zip if exists
    if (Test-Path $zipFile) {
        Remove-Item $zipFile -Force
    }
    
    # Download with progress
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $flutterUrl -OutFile $zipFile -UseBasicParsing
    $ProgressPreference = 'Continue'
    
    $fileSize = (Get-Item $zipFile).Length / 1MB
    Write-Host "  Downloaded: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Gray
} catch {
    Write-Host "  ERROR: Failed to download Flutter SDK" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}

# Step 3: Extract Flutter SDK
Write-Host "[3/5] Extracting Flutter SDK..." -ForegroundColor Green

try {
    # Remove old installation if exists
    if (Test-Path $flutterDir) {
        Write-Host "  Removing old Flutter installation..." -ForegroundColor Yellow
        Remove-Item -Path $flutterDir -Recurse -Force
    }
    
    # Extract
    Expand-Archive -Path $zipFile -DestinationPath $flutterInstallPath -Force
    Write-Host "  Extracted to: $flutterDir" -ForegroundColor Gray
    
    # Clean up zip file
    Remove-Item $zipFile -Force
} catch {
    Write-Host "  ERROR: Failed to extract Flutter SDK" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}

# Step 4: Add to PATH
Write-Host "[4/5] Adding Flutter to PATH..." -ForegroundColor Green

$flutterBinPath = "$flutterDir\bin"

# Get current user PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

# Check if already in PATH
if ($currentPath -like "*$flutterBinPath*") {
    Write-Host "  Flutter is already in User PATH" -ForegroundColor Gray
} else {
    # Add to user PATH
    $newPath = "$currentPath;$flutterBinPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "  Added to User PATH: $flutterBinPath" -ForegroundColor Gray
    
    # Update current session PATH
    $env:Path = "$env:Path;$flutterBinPath"
}

# Step 5: Verify installation
Write-Host "[5/5] Verifying installation..." -ForegroundColor Green

# Refresh PATH for current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Check if flutter command is available
$flutterExe = "$flutterBinPath\flutter.bat"
if (Test-Path $flutterExe) {
    Write-Host "  Flutter executable found!" -ForegroundColor Gray
    
    # Get version
    try {
        Write-Host ""
        Write-Host "Running 'flutter --version'..." -ForegroundColor Cyan
        & "$flutterExe" --version
    } catch {
        Write-Host "  Warning: Could not run flutter --version" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ERROR: Flutter executable not found at $flutterExe" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Installation Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: " -ForegroundColor Yellow -NoNewline
Write-Host "Please restart your terminal or PowerShell window for PATH changes to take effect."
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Close and reopen your terminal/PowerShell"
Write-Host "  2. Run: flutter doctor"
Write-Host "  3. Follow any additional setup instructions from 'flutter doctor'"
Write-Host ""

<#
.SYNOPSIS
  Idempotent Velociraptor client installer for Windows.
.DESCRIPTION
  Downloads the agent and config, installs the service if not already present,
  and ensures the service is running. Safe to re-run.
#>

param(
    [string]$ServerUrl   = "http://velociraptor.lab:9000",
    [string]$AgentFile   = "velociraptor.exe",
    [string]$ConfigFile  = "client.windows.yaml",
    [string]$InstallDir  = "C:\Program Files\Velociraptor"
)

$ErrorActionPreference = "Stop"

# Must run as admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run as Administrator."
}

$agentPath  = Join-Path $InstallDir "Velociraptor.exe"
$configPath = Join-Path $InstallDir "client.config.yaml"

# --- Idempotency check: is service already installed? ---
$existing = Get-Service -Name "Velociraptor" -ErrorAction SilentlyContinue

if ($existing) {
    Write-Host "[i] Velociraptor service already installed. Skipping download and install."

    if ($existing.Status -ne "Running") {
        Write-Host "[i] Starting service..."
        Start-Service -Name "Velociraptor"
    }
    Write-Host "[+] Service status: $((Get-Service Velociraptor).Status)"
    return
}

Write-Host "[i] Velociraptor not installed. Starting setup..."

# --- Download agent ---
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

Write-Host "[i] Downloading agent..."
Invoke-WebRequest -Uri "$ServerUrl/$AgentFile" -OutFile $agentPath -UseBasicParsing

Write-Host "[i] Downloading config..."
Invoke-WebRequest -Uri "$ServerUrl/$ConfigFile" -OutFile $configPath -UseBasicParsing

# --- Install service ---
Write-Host "[i] Installing service..."
& $agentPath --config $configPath service install

Start-Sleep -Seconds 3

# --- Verify ---
$svc = Get-Service -Name "Velociraptor" -ErrorAction SilentlyContinue
if (-not $svc) {
    throw "Service installation failed."
}

if ($svc.Status -ne "Running") {
    Start-Service -Name "Velociraptor"
}

Write-Host "[+] Installation complete. Service status: $((Get-Service Velociraptor).Status)"
# APIM Swagger Import POC - Setup Script
# Ensures required PowerShell modules and Azure authentication

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipModuleUpdate,
    [switch]$Pipeline  # Indicates running in Azure DevOps pipeline
)

# Import configuration
. "$PSScriptRoot\config.ps1"

$environmentType = if ($Pipeline) { "Pipeline" } else { "Local" }
Write-Host "🚀 APIM Swagger Import POC - $environmentType Environment Setup" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta

# Required PowerShell modules
$RequiredModules = @(
    @{ Name = "Az.Accounts"; MinVersion = "2.0.0" }
    @{ Name = "Az.Resources"; MinVersion = "6.0.0" }
    @{ Name = "Az.ApiManagement"; MinVersion = "4.0.0" }
    @{ Name = "Az.Profile"; MinVersion = "1.0.0" }
)

# Function to check if module is installed and meets minimum version
function Test-ModuleVersion {
    param(
        [string]$ModuleName,
        [string]$MinVersion
    )
    
    $module = Get-Module -Name $ModuleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    
    if (-not $module) {
        return $false
    }
    
    return [version]$module.Version -ge [version]$MinVersion
}

# Function to install or update PowerShell module
function Install-RequiredModule {
    param(
        [string]$ModuleName,
        [string]$MinVersion
    )
    
    Write-Host "📦 Checking module: $ModuleName (min: $MinVersion)" -ForegroundColor Yellow
    
    if (Test-ModuleVersion -ModuleName $ModuleName -MinVersion $MinVersion -and -not $Force) {
        Write-Host "✅ Module $ModuleName is already installed and meets minimum version" -ForegroundColor Green
        return
    }
    
    try {
        if ($SkipModuleUpdate) {
            Write-Host "⏭️  Skipping module update for $ModuleName" -ForegroundColor Yellow
            return
        }
        
        Write-Host "📥 Installing/updating module: $ModuleName..." -ForegroundColor Cyan
        
        # In pipeline, always use CurrentUser scope; for local, detect admin privileges
        if ($Pipeline) {
            Install-Module -Name $ModuleName -MinimumVersion $MinVersion -Force -AllowClobber -Scope CurrentUser
        } else {
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            
            if ($isAdmin) {
                Install-Module -Name $ModuleName -MinimumVersion $MinVersion -Force -AllowClobber -Scope AllUsers
            } else {
                Install-Module -Name $ModuleName -MinimumVersion $MinVersion -Force -AllowClobber -Scope CurrentUser
            }
        }
        
        Write-Host "✅ Module $ModuleName installed successfully" -ForegroundColor Green
        
    } catch {
        Write-Error "❌ Failed to install module $ModuleName`: $($_.Exception.Message)"
        throw
    }
}

# Main setup process
try {
    Write-Host "📋 Checking PowerShell execution policy..." -ForegroundColor Yellow
    if ($Pipeline) {
        # In pipeline, show current policy but don't modify it
        $executionPolicy = Get-ExecutionPolicy -Scope Process
        Write-Host "✅ Pipeline execution policy: $executionPolicy" -ForegroundColor Green
    } else {
        # Local development - check and update if needed
        $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($executionPolicy -eq "Restricted") {
            Write-Host "⚠️  Execution policy is Restricted. Setting to RemoteSigned for CurrentUser..." -ForegroundColor Yellow
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Host "✅ Execution policy updated" -ForegroundColor Green
        } else {
            Write-Host "✅ Execution policy is acceptable: $executionPolicy" -ForegroundColor Green
        }
    }
    
    Write-Host "`n🔧 Installing/updating required PowerShell modules..." -ForegroundColor Cyan
    
    foreach ($module in $RequiredModules) {
        Install-RequiredModule -ModuleName $module.Name -MinVersion $module.MinVersion
    }
    
    Write-Host "`n🔐 Verifying Azure authentication..." -ForegroundColor Cyan
    
    if ($Pipeline) {
        # In pipeline with service connection, context should already be established
        Write-Host "📡 Pipeline mode: Using service connection authentication" -ForegroundColor Cyan
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        
        if (-not $azContext) {
            Write-Host "❌ No Azure context found in pipeline. Ensure AzurePowerShell@5 task is used with proper service connection." -ForegroundColor Red
            exit 1
        }
    } else {
        # Local development - check if connected
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        
        if (-not $azContext) {
            Write-Host "❌ Not connected to Azure. Please run:" -ForegroundColor Red
            Write-Host "   Connect-AzAccount" -ForegroundColor Yellow
            Write-Host "   Then run this setup script again." -ForegroundColor Yellow
            exit 1
        }
    }
    
    Write-Host "✅ Connected to Azure:" -ForegroundColor Green
    Write-Host "   Account: $($azContext.Account.Id)" -ForegroundColor White
    Write-Host "   Subscription: $($azContext.Subscription.Name) ($($azContext.Subscription.Id))" -ForegroundColor White
    Write-Host "   Tenant: $($azContext.Tenant.Id)" -ForegroundColor White
    
    Write-Host "`n🔧 Initializing configuration..." -ForegroundColor Cyan
    if (Initialize-Config) {
        Write-Host "✅ Configuration initialized successfully" -ForegroundColor Green
    } else {
        throw "Failed to initialize configuration"
    }
    
    Write-Host "\n✅ $environmentType environment setup completed successfully!" -ForegroundColor Green
    Write-Host "🎯 Ready to run the APIM Swagger import POC" -ForegroundColor Cyan
    
    if ($Pipeline) {
        Write-Host "\n📋 Pipeline ready for next stages:" -ForegroundColor Yellow
        Write-Host "  - APIM provisioning" -ForegroundColor White
        Write-Host "  - Swagger import operations" -ForegroundColor White
    } else {
        Write-Host "\nNext steps:" -ForegroundColor Yellow
        Write-Host "  1. Review configuration in config.ps1" -ForegroundColor White
        Write-Host "  2. Run .\demo.ps1 to start the full demonstration" -ForegroundColor White
    }
    
} catch {
    Write-Error "❌ Setup failed: $($_.Exception.Message)"
    if ($Pipeline) {
        Write-Host "\n🔄 Pipeline Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Ensure service connection has required permissions (Contributor + API Management Service Contributor)" -ForegroundColor White
        Write-Host "  2. Verify AzurePowerShell@5 task is used (not PowerShell@2)" -ForegroundColor White
        Write-Host "  3. Use -SkipModuleUpdate on Microsoft-hosted agents" -ForegroundColor White
        Write-Host "  4. Check service connection is properly configured in Azure DevOps" -ForegroundColor White
    } else {
        Write-Host "\n🔄 Local Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Ensure you're running PowerShell as Administrator (for system-wide module installation)" -ForegroundColor White
        Write-Host "  2. Check internet connectivity for module downloads" -ForegroundColor White
        Write-Host "  3. Verify Azure CLI is installed and you're logged in" -ForegroundColor White
        Write-Host "  4. Run with -SkipModuleUpdate if modules are already installed" -ForegroundColor White
    }
    exit 1
}
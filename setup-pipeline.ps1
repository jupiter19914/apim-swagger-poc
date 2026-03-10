# APIM Swagger Import POC - Pipeline Setup Script
# Modified for Azure DevOps pipeline execution with service principal authentication

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipModuleUpdate,
    [switch]$UsePipelineAuth,  # New parameter for pipeline mode
    [string]$ServicePrincipalId,
    [string]$ServicePrincipalSecret,
    [string]$TenantId,
    [string]$SubscriptionId
)

# Import configuration
. "$PSScriptRoot\config.ps1"

Write-Host "🚀 APIM Swagger Import POC - Pipeline Environment Setup" -ForegroundColor Magenta
Write-Host "======================================================" -ForegroundColor Magenta

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
        
        # In pipeline, always use CurrentUser scope to avoid permission issues
        Install-Module -Name $ModuleName -MinimumVersion $MinVersion -Force -AllowClobber -Scope CurrentUser
        
        Write-Host "✅ Module $ModuleName installed successfully" -ForegroundColor Green
        
    } catch {
        Write-Error "❌ Failed to install module $ModuleName`: $($_.Exception.Message)"
        throw
    }
}

# Function to authenticate with service principal
function Connect-WithServicePrincipal {
    param(
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$TenantId,
        [string]$SubscriptionId
    )
    
    try {
        Write-Host "🔐 Authenticating with service principal..." -ForegroundColor Cyan
        
        $SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)
        
        Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $TenantId -Subscription $SubscriptionId | Out-Null
        
        Write-Host "✅ Successfully authenticated with service principal" -ForegroundColor Green
        return $true
    } catch {
        Write-Error "❌ Service principal authentication failed: $($_.Exception.Message)"
        return $false
    }
}

# Main setup process
try {
    Write-Host "📋 Checking PowerShell execution policy..." -ForegroundColor Yellow
    $executionPolicy = Get-ExecutionPolicy -Scope Process
    Write-Host "✅ Current execution policy: $executionPolicy" -ForegroundColor Green
    
    Write-Host "`n🔧 Installing/updating required PowerShell modules..." -ForegroundColor Cyan
    
    foreach ($module in $RequiredModules) {
        Install-RequiredModule -ModuleName $module.Name -MinVersion $module.MinVersion
    }
    
    Write-Host "`n🔐 Configuring Azure authentication..." -ForegroundColor Cyan
    
    if ($UsePipelineAuth) {
        # Pipeline authentication with service principal
        $spId = $ServicePrincipalId ?? $env:AZURE_CLIENT_ID
        $spSecret = $ServicePrincipalSecret ?? $env:AZURE_CLIENT_SECRET  
        $tenantId = $TenantId ?? $env:AZURE_TENANT_ID
        $subscriptionId = $SubscriptionId ?? $env:AZURE_SUBSCRIPTION_ID
        
        if (-not ($spId -and $spSecret -and $tenantId)) {
            throw "Service principal authentication requires ClientId, ClientSecret, and TenantId"
        }
        
        if (-not (Connect-WithServicePrincipal -ClientId $spId -ClientSecret $spSecret -TenantId $tenantId -SubscriptionId $subscriptionId)) {
            throw "Failed to authenticate with service principal"
        }
    } else {
        # Check if already connected to Azure (for local development)
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        
        if (-not $azContext) {
            Write-Host "❌ Not connected to Azure. For pipeline use, add -UsePipelineAuth parameter" -ForegroundColor Red
            Write-Host "   For local development, please run: Connect-AzAccount" -ForegroundColor Yellow
            exit 1
        }
    }
    
    # Verify current context
    $currentContext = Get-AzContext
    Write-Host "✅ Connected to Azure:" -ForegroundColor Green
    Write-Host "   Account: $($currentContext.Account.Id)" -ForegroundColor White
    Write-Host "   Subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))" -ForegroundColor White
    Write-Host "   Tenant: $($currentContext.Tenant.Id)" -ForegroundColor White
    
    Write-Host "`n🔧 Initializing configuration..." -ForegroundColor Cyan
    if (Initialize-Config -SubscriptionId $currentContext.Subscription.Id) {
        Write-Host "✅ Configuration initialized successfully" -ForegroundColor Green
    } else {
        throw "Failed to initialize configuration"
    }
    
    Write-Host "`n✅ Pipeline environment setup completed successfully!" -ForegroundColor Green
    Write-Host "🎯 Ready to run the APIM Swagger import POC" -ForegroundColor Cyan
    
} catch {
    Write-Error "❌ Setup failed: $($_.Exception.Message)"
    Write-Host "`n🔄 Pipeline Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure service principal has required permissions" -ForegroundColor White
    Write-Host "  2. Verify AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID variables" -ForegroundColor White
    Write-Host "  3. Check subscription access for the service principal" -ForegroundColor White
    Write-Host "  4. Use -SkipModuleUpdate on Microsoft-hosted agents" -ForegroundColor White
    exit 1
}
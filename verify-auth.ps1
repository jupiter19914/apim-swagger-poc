# Authentication Verification Script
# Tests both Azure PowerShell and Azure CLI authentication in pipeline context

[CmdletBinding()]
param(
    [switch]$Pipeline
)

$environmentType = if ($Pipeline) { "Pipeline" } else { "Local" }
Write-Host "🔍 Authentication Verification - $environmentType Mode" -ForegroundColor Magenta
Write-Host "==============================================" -ForegroundColor Magenta

# Test Azure PowerShell Authentication
Write-Host "`n1️⃣ Testing Azure PowerShell Authentication..." -ForegroundColor Cyan
try {
    $azContext = Get-AzContext -ErrorAction Stop
    
    if ($azContext) {
        Write-Host "✅ Azure PowerShell: Connected" -ForegroundColor Green
        Write-Host "   Account: $($azContext.Account.Id)" -ForegroundColor White
        Write-Host "   Subscription: $($azContext.Subscription.Name) ($($azContext.Subscription.Id))" -ForegroundColor White
        Write-Host "   Tenant: $($azContext.Tenant.Id)" -ForegroundColor White
    } else {
        Write-Host "❌ Azure PowerShell: No context found" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Azure PowerShell: Failed - $($_.Exception.Message)" -ForegroundColor Red
}

# Test Azure CLI Authentication
Write-Host "`n2️⃣ Testing Azure CLI Authentication..." -ForegroundColor Cyan
try {
    $cliResult = az account show --output json 2>&1 | ConvertFrom-Json
    
    if ($cliResult -and $cliResult.id) {
        Write-Host "✅ Azure CLI: Connected" -ForegroundColor Green
        Write-Host "   Account: $($cliResult.user.name)" -ForegroundColor White
        Write-Host "   Subscription: $($cliResult.name) ($($cliResult.id))" -ForegroundColor White
        Write-Host "   Tenant: $($cliResult.tenantId)" -ForegroundColor White
    } else {
        Write-Host "❌ Azure CLI: Not authenticated" -ForegroundColor Red
        Write-Host "   Output: $cliResult" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Azure CLI: Failed - $($_.Exception.Message)" -ForegroundColor Red
}

# Compare subscription contexts
Write-Host "`n3️⃣ Comparing Subscription Contexts..." -ForegroundColor Cyan
try {
    if ($azContext -and $cliResult) {
        $psSubscription = $azContext.Subscription.Id
        $cliSubscription = $cliResult.id
        
        if ($psSubscription -eq $cliSubscription) {
            Write-Host "✅ Subscription Match: Both contexts use the same subscription" -ForegroundColor Green
            Write-Host "   Subscription ID: $psSubscription" -ForegroundColor White
        } else {
            Write-Host "⚠️  Subscription Mismatch:" -ForegroundColor Yellow
            Write-Host "   PowerShell: $psSubscription" -ForegroundColor White
            Write-Host "   Azure CLI:  $cliSubscription" -ForegroundColor White
            Write-Host "   This could cause authentication issues!" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "❌ Could not compare subscriptions: $($_.Exception.Message)" -ForegroundColor Red
}

# Test APIM access with both methods
Write-Host "`n4️⃣ Testing APIM Service Access..." -ForegroundColor Cyan

# Import configuration for APIM details
try {
    . "$PSScriptRoot\config.ps1"
    Initialize-Config | Out-Null
    
    $resourceGroupName = $Global:Config.ResourceGroupName
    $serviceName = $Global:Config.ApimServiceName
    
    # Test PowerShell APIM access
    Write-Host "   Testing PowerShell APIM access..." -ForegroundColor Yellow
    try {
        $apimService = Get-AzApiManagement -ResourceGroupName $resourceGroupName -Name $serviceName -ErrorAction Stop
        Write-Host "   ✅ PowerShell: Can access APIM service '$serviceName'" -ForegroundColor Green
        Write-Host "      Status: $($apimService.ProvisioningState)" -ForegroundColor White
    } catch {
        Write-Host "   ❌ PowerShell: Cannot access APIM - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test Azure CLI APIM access
    Write-Host "   Testing Azure CLI APIM access..." -ForegroundColor Yellow
    try {
        $cliApim = az apim show --name $serviceName --resource-group $resourceGroupName --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $apimInfo = $cliApim | ConvertFrom-Json
            Write-Host "   ✅ Azure CLI: Can access APIM service '$serviceName'" -ForegroundColor Green
            Write-Host "      Status: $($apimInfo.provisioningState)" -ForegroundColor White
        } else {
            Write-Host "   ❌ Azure CLI: Cannot access APIM - $cliApim" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Azure CLI: Cannot access APIM - $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "   ❌ Could not load configuration: $($_.Exception.Message)" -ForegroundColor Red
}

# Recommendations
Write-Host "`n💡 Recommendations:" -ForegroundColor Cyan
if ($Pipeline) {
    Write-Host "   For Pipeline mode:" -ForegroundColor White
    Write-Host "   1. Ensure AzurePowerShell@5 task is used for PowerShell scripts" -ForegroundColor Gray
    Write-Host "   2. Ensure AzureCLI@2 task is used before any 'az' commands" -ForegroundColor Gray
    Write-Host "   3. Use same service connection for both tasks" -ForegroundColor Gray
    Write-Host "   4. Verify service principal has 'API Management Service Contributor' role" -ForegroundColor Gray
} else {
    Write-Host "   For Local development:" -ForegroundColor White
    Write-Host "   1. Run 'Connect-AzAccount' for PowerShell authentication" -ForegroundColor Gray
    Write-Host "   2. Run 'az login' for Azure CLI authentication" -ForegroundColor Gray
    Write-Host "   3. Ensure both use the same subscription with 'az account set'" -ForegroundColor Gray
}

Write-Host "`n🎯 Authentication verification completed!" -ForegroundColor Green
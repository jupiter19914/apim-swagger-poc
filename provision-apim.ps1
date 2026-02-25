# APIM Swagger Import POC - APIM Instance Provisioning
# Creates Azure API Management instance for demonstration

#Requires -Module Az.ApiManagement
#Requires -Module Az.Resources

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$WaitForCompletion = $true,
    [int]$TimeoutMinutes = 45
)

# Import configuration
. "$PSScriptRoot\config.ps1"

Write-Host "🏗️  APIM Instance Provisioning" -ForegroundColor Magenta
Write-Host "==============================" -ForegroundColor Magenta

# Initialize configuration
if (-not (Initialize-Config)) {
    Write-Error "Failed to initialize configuration"
    exit 1
}

# Function to check if resource group exists
function Test-ResourceGroup {
    param([string]$ResourceGroupName)
    
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        return $null -ne $rg
    } catch {
        return $false
    }
}

# Function to check if APIM service exists
function Test-ApimService {
    param(
        [string]$ResourceGroupName,
        [string]$ServiceName
    )
    
    try {
        $apim = Get-AzApiManagement -ResourceGroupName $ResourceGroupName -Name $ServiceName -ErrorAction SilentlyContinue
        return $null -ne $apim
    } catch {
        return $false
    }
}

# Function to create resource group
function New-DemoResourceGroup {
    param(
        [string]$ResourceGroupName,
        [string]$Location
    )
    
    Write-Host "📁 Creating resource group: $ResourceGroupName" -ForegroundColor Cyan
    
    try {
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force
        Write-Host "✅ Resource group created: $($rg.ResourceGroupName)" -ForegroundColor Green
        return $rg
    } catch {
        Write-Error "❌ Failed to create resource group: $($_.Exception.Message)"
        throw
    }
}

# Function to create APIM instance
function New-ApimInstance {
    param(
        [string]$ResourceGroupName,
        [string]$ServiceName,
        [string]$Location,
        [string]$Publisher,
        [string]$PublisherEmail,
        [string]$Sku
    )
    
    Write-Host "🔧 Creating APIM instance: $ServiceName" -ForegroundColor Cyan
    Write-Host "   SKU: $Sku" -ForegroundColor White
    Write-Host "   Location: $Location" -ForegroundColor White
    Write-Host "   Publisher: $Publisher" -ForegroundColor White
    
    try {
        $apimContext = New-AzApiManagement -ResourceGroupName $ResourceGroupName `
                                         -Location $Location `
                                         -Name $ServiceName `
                                         -Organization $Publisher `
                                         -AdminEmail $PublisherEmail `
                                         -Sku $Sku
        
        Write-Host "✅ APIM instance creation initiated" -ForegroundColor Green
        return $apimContext
        
    } catch {
        Write-Error "❌ Failed to create APIM instance: $($_.Exception.Message)"
        throw
    }
}

# Function to wait for APIM provisioning to complete
function Wait-ApimProvisioning {
    param(
        [string]$ResourceGroupName,
        [string]$ServiceName,
        [int]$TimeoutMinutes = 45
    )
    
    Write-Host "⏳ Waiting for APIM provisioning to complete..." -ForegroundColor Yellow
    Write-Host "   This typically takes 15-45 minutes for Developer tier" -ForegroundColor White
    Write-Host "   Timeout: $TimeoutMinutes minutes" -ForegroundColor White
    
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    $lastStatus = ""
    
    do {
        Start-Sleep -Seconds 30
        
        try {
            $apim = Get-AzApiManagement -ResourceGroupName $ResourceGroupName -Name $ServiceName -ErrorAction SilentlyContinue
            
            if ($apim) {
                $currentStatus = $apim.ProvisioningState
                
                if ($currentStatus -ne $lastStatus) {
                    Write-Host "📊 Status: $currentStatus" -ForegroundColor Cyan
                    $lastStatus = $currentStatus
                }
                
                if ($currentStatus -eq "Succeeded") {
                    Write-Host "✅ APIM instance provisioned successfully!" -ForegroundColor Green
                    return $apim
                } elseif ($currentStatus -eq "Failed") {
                    throw "APIM provisioning failed"
                }
            }
            
            if ((Get-Date) -gt $timeout) {
                Write-Warning "⚠️  Timeout reached. APIM may still be provisioning in the background."
                return $null
            }
            
        } catch {
            Write-Warning "⚠️  Error checking APIM status: $($_.Exception.Message)"
        }
        
    } while ($true)
}

# Main provisioning process
try {
    $resourceGroupName = Get-ConfigValue "ResourceGroupName"
    $location = Get-ConfigValue "Location"
    $serviceName = Get-ConfigValue "ApimServiceName"
    $sku = Get-ConfigValue "ApimSku"
    $publisher = Get-ConfigValue "ApimPublisherName"
    $publisherEmail = Get-ConfigValue "ApimPublisherEmail"
    
    Write-Host "🎯 Target Configuration:" -ForegroundColor Cyan
    Write-Host "   Resource Group: $resourceGroupName" -ForegroundColor White
    Write-Host "   APIM Service: $serviceName" -ForegroundColor White
    Write-Host "   Location: $location" -ForegroundColor White
    
    # Check if APIM already exists
    if (Test-ApimService -ResourceGroupName $resourceGroupName -ServiceName $serviceName -and -not $Force) {
        Write-Host "✅ APIM instance already exists: $serviceName" -ForegroundColor Green
        $existingApim = Get-AzApiManagement -ResourceGroupName $resourceGroupName -Name $serviceName
        
        Write-Host "📊 Existing APIM Details:" -ForegroundColor Cyan
        Write-Host "   Gateway URL: $($existingApim.GatewayUrl)" -ForegroundColor White
        Write-Host "   Management URL: $($existingApim.ManagementApiUrl)" -ForegroundColor White
        Write-Host "   Status: $($existingApim.ProvisioningState)" -ForegroundColor White
        
        # Store APIM details in config for other scripts
        if ($existingApim.GatewayUrl) {
            Set-ConfigValue "ApimGatewayUrl" $existingApim.GatewayUrl
        }
        if ($existingApim.ManagementApiUrl) {
            Set-ConfigValue "ApimManagementUrl" $existingApim.ManagementApiUrl
        }
        
        Write-Host "🎯 Ready for API import demonstration" -ForegroundColor Green
        exit 0
    }
    
    # Create resource group if it doesn't exist
    if (-not (Test-ResourceGroup -ResourceGroupName $resourceGroupName)) {
        New-DemoResourceGroup -ResourceGroupName $resourceGroupName -Location $location
    } else {
        Write-Host "✅ Resource group already exists: $resourceGroupName" -ForegroundColor Green
    }
    
    # Create APIM instance
    Write-Host "`n🔧 Starting APIM instance creation..." -ForegroundColor Cyan
    $apimContext = New-ApimInstance -ResourceGroupName $resourceGroupName `
                                   -ServiceName $serviceName `
                                   -Location $location `
                                   -Publisher $publisher `
                                   -PublisherEmail $publisherEmail `
                                   -Sku $sku
    
    if ($WaitForCompletion) {
        $completedApim = Wait-ApimProvisioning -ResourceGroupName $resourceGroupName `
                                              -ServiceName $serviceName `
                                              -TimeoutMinutes $TimeoutMinutes
        
        if ($completedApim) {
            Write-Host "`n🎉 APIM Instance Ready!" -ForegroundColor Green
            Write-Host "📊 APIM Details:" -ForegroundColor Cyan
            Write-Host "   Gateway URL: $($completedApim.GatewayUrl)" -ForegroundColor White
            Write-Host "   Management URL: $($completedApim.ManagementApiUrl)" -ForegroundColor White
            Write-Host "   Portal URL: $($completedApim.PortalUrl)" -ForegroundColor White
            
            # Store APIM details in config for other scripts
            if ($completedApim.GatewayUrl) {
                Set-ConfigValue "ApimGatewayUrl" $completedApim.GatewayUrl
            }
            if ($completedApim.ManagementApiUrl) {
                Set-ConfigValue "ApimManagementUrl" $completedApim.ManagementApiUrl
            }
            
        } else {
            Write-Warning "⚠️  APIM provisioning may still be in progress. Check Azure Portal for status."
        }
    } else {
        Write-Host "✅ APIM instance creation initiated successfully" -ForegroundColor Green
        Write-Host "📝 Check Azure Portal for provisioning progress" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "❌ APIM provisioning failed: $($_.Exception.Message)"
    Write-Host "`n🔄 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify sufficient Azure subscription quotas for APIM" -ForegroundColor White
    Write-Host "  2. Check service name availability (must be globally unique)" -ForegroundColor White
    Write-Host "  3. Ensure proper permissions in the subscription/resource group" -ForegroundColor White
    Write-Host "  4. Try a different Azure region if current region has capacity issues" -ForegroundColor White
    exit 1
}
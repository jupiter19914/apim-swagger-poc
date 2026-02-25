# APIM Swagger Import POC - Main Demonstration Script
# End-to-end demonstration of importing large Swagger 2.0 via APIM REST API

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$SkipSetup,
    [switch]$SkipProvisioning,
    [switch]$SkipImport,
    [switch]$InteractiveMode,
    [string]$SwaggerUrl = "",
    [switch]$CleanupAfter,
    [switch]$Force
)

# Import configuration
. "$PSScriptRoot\config.ps1"

Write-Host "🎭 APIM Swagger Import POC - End-to-End Demo" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "Demonstrating: Large (>4MB) Swagger 2.0 import via REST API" -ForegroundColor Cyan
Write-Host "Bypassing: Terraform inline specification size limitations`n" -ForegroundColor Yellow

# Function to display section header
function Write-SectionHeader {
    param([string]$Title, [string]$Description = "")
    
    Write-Host "`n" -NoNewline
    Write-Host "🎯 $Title" -ForegroundColor Cyan
    Write-Host "=" * ($Title.Length + 3) -ForegroundColor Cyan
    if ($Description) {
        Write-Host $Description -ForegroundColor White
    }
    Write-Host ""
}

# Function to wait for user confirmation in interactive mode
function Wait-UserConfirmation {
    param([string]$Message = "Press Enter to continue or Ctrl+C to abort...")
    
    if ($InteractiveMode) {
        Write-Host $Message -ForegroundColor Yellow
        Read-Host
    }
}

# Function to measure and display execution time
function Measure-ExecutionTime {
    param(
        [scriptblock]$ScriptBlock,
        [string]$OperationName
    )
    
    $startTime = Get-Date
    Write-Host "⏱️  Starting: $OperationName" -ForegroundColor Cyan
    
    try {
        & $ScriptBlock
        $endTime = Get-Date
        $duration = $endTime - $startTime
        Write-Host "✅ Completed: $OperationName" -ForegroundColor Green
        Write-Host "   Duration: $($duration.ToString('mm\:ss\.fff'))" -ForegroundColor White
        return $true
    } catch {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        Write-Host "❌ Failed: $OperationName" -ForegroundColor Red
        Write-Host "   Duration: $($duration.ToString('mm\:ss\.fff'))" -ForegroundColor White
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to display demo summary
function Show-DemoSummary {
    Write-Host "`n🎉 DEMO SUMMARY" -ForegroundColor Green
    Write-Host "===============" -ForegroundColor Green
    
    $subscriptionId = Get-ConfigValue "SubscriptionId"
    $resourceGroupName = Get-ConfigValue "ResourceGroupName"
    $serviceName = Get-ConfigValue "ApimServiceName"
    $gatewayUrl = Get-ConfigValue "ApimGatewayUrl"
    $apiId = Get-ConfigValue "ImportedApiId"
    $operationCount = Get-ConfigValue "ImportedOperationCount"
    $swaggerUrl = Get-ConfigValue "ValidatedSwaggerUrl"
    
    Write-Host "📊 Infrastructure:" -ForegroundColor Cyan
    Write-Host "   Subscription: $subscriptionId" -ForegroundColor White
    Write-Host "   Resource Group: $resourceGroupName" -ForegroundColor White
    Write-Host "   APIM Service: $serviceName" -ForegroundColor White
    Write-Host "   Gateway URL: $gatewayUrl" -ForegroundColor White
    
    Write-Host "`n📋 API Import Results:" -ForegroundColor Cyan
    Write-Host "   Source: $swaggerUrl" -ForegroundColor White
    Write-Host "   API ID: $apiId" -ForegroundColor White
    Write-Host "   Operations: $operationCount" -ForegroundColor White
    Write-Host "   Status: Successfully imported via REST API" -ForegroundColor Green
    
    Write-Host "`n🎯 Key Achievements:" -ForegroundColor Cyan
    Write-Host "   ✅ Bypassed Terraform's 4MB inline limitation" -ForegroundColor Green
    Write-Host "   ✅ Imported large Swagger 2.0 specification directly" -ForegroundColor Green
    Write-Host "   ✅ Used native APIM REST API capabilities" -ForegroundColor Green
    Write-Host "   ✅ Demonstrated scalable import approach" -ForegroundColor Green
    
    Write-Host "`n📝 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. View imported API in Azure Portal:" -ForegroundColor White
    Write-Host "      https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.ApiManagement/service/$serviceName/apis" -ForegroundColor Gray
    Write-Host "   2. Test API operations through APIM gateway" -ForegroundColor White
    Write-Host "   3. Configure policies, security, and monitoring" -ForegroundColor White
    Write-Host "   4. Integrate this approach into your CI/CD pipelines" -ForegroundColor White
}

# Function to cleanup resources
function Invoke-Cleanup {
    Write-SectionHeader "Resource Cleanup" "Removing demo resources"
    
    $resourceGroupName = Get-ConfigValue "ResourceGroupName"
    
    Write-Host "⚠️  About to delete resource group: $resourceGroupName" -ForegroundColor Yellow
    Write-Host "   This will remove all resources created during this demo" -ForegroundColor White
    
    $confirmation = Read-Host "Type 'DELETE' to confirm removal"
    
    if ($confirmation -eq "DELETE") {
        try {
            Write-Host "🗑️  Removing resource group..." -ForegroundColor Red
            Remove-AzResourceGroup -Name $resourceGroupName -Force
            Write-Host "✅ Cleanup completed" -ForegroundColor Green
        } catch {
            Write-Error "❌ Cleanup failed: $($_.Exception.Message)"
        }
    } else {
        Write-Host "❌ Cleanup cancelled" -ForegroundColor Yellow
    }
}

# Main demo execution
try {
    Write-Host "🔍 Demo Parameters:" -ForegroundColor Cyan
    Write-Host "   Skip Setup: $SkipSetup" -ForegroundColor White
    Write-Host "   Skip Provisioning: $SkipProvisioning" -ForegroundColor White
    Write-Host "   Skip Import: $SkipImport" -ForegroundColor White
    Write-Host "   Interactive Mode: $InteractiveMode" -ForegroundColor White
    Write-Host "   Force: $Force" -ForegroundColor White
    
    if ($SwaggerUrl) {
        Write-Host "   Custom Swagger URL: $SwaggerUrl" -ForegroundColor White
    }
    
    Wait-UserConfirmation
    
    # Step 1: Environment Setup
    if (-not $SkipSetup) {
        Write-SectionHeader "Environment Setup" "Installing required modules and verifying Azure connection"
        
        $setupSuccess = Measure-ExecutionTime -OperationName "Environment Setup" -ScriptBlock {
            & "$PSScriptRoot\setup.ps1"
        }
        
        if (-not $setupSuccess) {
            Write-Error "❌ Setup failed. Cannot continue."
            exit 1
        }
        
        Wait-UserConfirmation
    }
    
    # Step 2: Swagger Specification Preparation
    Write-SectionHeader "Swagger Specification Validation" "Preparing and validating large Swagger 2.0 specification"
    
    $prepareParams = @{}
    if ($SwaggerUrl) { $prepareParams.SwaggerUrl = $SwaggerUrl }
    
    $prepareSuccess = Measure-ExecutionTime -OperationName "Swagger Validation" -ScriptBlock {
        & "$PSScriptRoot\prepare-swagger.ps1" @prepareParams
    }
    
    if (-not $prepareSuccess) {
        Write-Error "❌ Swagger preparation failed. Cannot continue."
        exit 1
    }
    
    Wait-UserConfirmation
    
    # Step 3: APIM Provisioning
    if (-not $SkipProvisioning) {
        Write-SectionHeader "APIM Instance Provisioning" "Creating Azure API Management instance"
        
        $provisionParams = @{}
        if ($Force) { $provisionParams.Force = $true }
        
        $provisionSuccess = Measure-ExecutionTime -OperationName "APIM Provisioning" -ScriptBlock {
            & "$PSScriptRoot\provision-apim.ps1" @provisionParams
        }
        
        if (-not $provisionSuccess) {
            Write-Error "❌ APIM provisioning failed. Cannot continue."
            exit 1
        }
        
        Wait-UserConfirmation
    }
    
    # Step 4: REST API Import
    if (-not $SkipImport) {
        Write-SectionHeader "REST API Import Demonstration" "Importing large Swagger specification via APIM REST API"
        
        $importParams = @{}
        if ($SwaggerUrl) { $importParams.SwaggerUrl = $SwaggerUrl }
        if ($Force) { $importParams.Force = $true }
        
        $importSuccess = Measure-ExecutionTime -OperationName "Swagger Import" -ScriptBlock {
            & "$PSScriptRoot\import-swagger.ps1" @importParams
        }
        
        if (-not $importSuccess) {
            Write-Error "❌ Swagger import failed. Cannot continue."
            exit 1
        }
        
        Wait-UserConfirmation
    }
    
    # Step 5: Demo Summary
    Write-SectionHeader "Demonstration Complete" "Reviewing results and next steps"
    Show-DemoSummary
    
    # Optional cleanup
    if ($CleanupAfter) {
        Wait-UserConfirmation "`nProceed with resource cleanup?"
        Invoke-Cleanup
    }
    
    Write-Host "`n🎉 APIM Swagger Import POC Completed Successfully!" -ForegroundColor Green
    Write-Host "📚 This demonstrates a scalable approach for importing large API specifications" -ForegroundColor Cyan
    Write-Host "🚀 Ready for integration into automated deployment pipelines" -ForegroundColor Yellow
    
} catch {
    Write-Error "❌ Demo execution failed: $($_.Exception.Message)"
    
    Write-Host "`n🔄 Troubleshooting Guide:" -ForegroundColor Yellow
    Write-Host "  1. Ensure you're logged into Azure (az login or Connect-AzAccount)" -ForegroundColor White
    Write-Host "  2. Verify sufficient permissions in your Azure subscription" -ForegroundColor White
    Write-Host "  3. Check internet connectivity for module downloads" -ForegroundColor White
    Write-Host "  4. Try running individual scripts to isolate issues:" -ForegroundColor White
    Write-Host "     - .\setup.ps1" -ForegroundColor Gray
    Write-Host "     - .\prepare-swagger.ps1" -ForegroundColor Gray
    Write-Host "     - .\provision-apim.ps1" -ForegroundColor Gray
    Write-Host "     - .\import-swagger.ps1" -ForegroundColor Gray
    Write-Host "  5. Use -InteractiveMode for step-by-step execution" -ForegroundColor White
    Write-Host "  6. Check Azure service health and regional availability" -ForegroundColor White
    
    exit 1
}
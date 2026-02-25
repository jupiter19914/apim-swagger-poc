# APIM Swagger Import POC - Azure CLI Import
# Simple, reliable import of Swagger specifications using Azure CLI

[CmdletBinding()]
param(
    [string]$SwaggerUrl = "",
    [string]$ApiId = "",
    [switch]$Force
)

# Import configuration
. "$PSScriptRoot\config.ps1"

Write-Host "🚀 APIM Swagger Import via Azure CLI" -ForegroundColor Magenta
Write-Host "====================================" -ForegroundColor Magenta

# Initialize configuration
if (-not (Initialize-Config)) {
    Write-Error "Failed to initialize configuration"
    exit 1
}

# Use configuration defaults if parameters not provided
$SwaggerUrl = if ($SwaggerUrl) { $SwaggerUrl } else { $Global:Config.DefaultSwaggerUrl }
$ApiId = if ($ApiId) { $ApiId } else { $Global:Config.ApiId }

# Build configuration values
$resourceGroupName = $Global:Config.ResourceGroupName
$serviceName = $Global:Config.ApimServiceName
$apiDisplayName = $Global:Config.ApiDisplayName
$apiPath = $Global:Config.ApiPath
$apiDescription = $Global:Config.ApiDescription

Write-Host "🎯 Import Configuration:" -ForegroundColor Cyan
Write-Host "   APIM Service: $serviceName" -ForegroundColor White
Write-Host "   API ID: $ApiId" -ForegroundColor White
Write-Host "   Swagger URL: $SwaggerUrl" -ForegroundColor White

# Check if API already exists and handle Force parameter
if (-not $Force) {
    try {
        $existingApi = az apim api show --resource-group $resourceGroupName --service-name $serviceName --api-id $ApiId 2>$null
        if ($existingApi) {
            Write-Host "⚠️  API '$ApiId' already exists. Use -Force to overwrite." -ForegroundColor Yellow
            exit 1
        }
    } catch {
        # API doesn't exist, continue
    }
}

try {
    Write-Host "📥 Importing Swagger specification via Azure CLI..." -ForegroundColor Cyan
    
    # Import the API using Azure CLI
    $importResult = az apim api import `
        --resource-group $resourceGroupName `
        --service-name $serviceName `
        --api-id $ApiId `
        --specification-url $SwaggerUrl `
        --specification-format Swagger `
        --display-name $apiDisplayName `
        --path $apiPath `
        --description $apiDescription 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Import completed successfully!" -ForegroundColor Green
        
        # Get API details
        Write-Host "📊 Retrieving API details..." -ForegroundColor Cyan
        $apiDetails = az apim api show --resource-group $resourceGroupName --service-name $serviceName --api-id $ApiId | ConvertFrom-Json
        $operations = az apim api operation list --resource-group $resourceGroupName --service-name $serviceName --api-id $ApiId | ConvertFrom-Json
        
        # Display results
        Write-Host "`n🎉 Swagger Import Completed Successfully!" -ForegroundColor Green
        Write-Host "📊 Import Summary:" -ForegroundColor Cyan
        Write-Host "   API Name: $($apiDetails.displayName)" -ForegroundColor White
        Write-Host "   API ID: $($apiDetails.name)" -ForegroundColor White
        Write-Host "   API Path: $($apiDetails.path)" -ForegroundColor White
        Write-Host "   Operations Imported: $($operations.Count)" -ForegroundColor White
        Write-Host "   Service URL: $($apiDetails.serviceUrl)" -ForegroundColor White
        Write-Host "   Gateway URL: https://$serviceName.azure-api.net$($apiDetails.path)" -ForegroundColor White
        
        # Store results for demo script
        Set-ConfigValue "ImportedApiId" $ApiId
        Set-ConfigValue "ImportedOperationCount" $operations.Count
        Set-ConfigValue "ImportedApiPath" $apiDetails.path
        Set-ConfigValue "ImportedServiceUrl" $apiDetails.serviceUrl
        
        Write-Host "`n✅ Large Swagger specification imported successfully!" -ForegroundColor Green
        Write-Host "🎯 This demonstrates bypassing Terraform's 4MB inline limitation" -ForegroundColor Cyan
        Write-Host "🚀 Using reliable Azure CLI for production deployments" -ForegroundColor Yellow
        
    } else {
        Write-Host "❌ Import failed: $importResult" -ForegroundColor Red
        Write-Host "`n🔄 Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Verify APIM instance is fully provisioned and accessible" -ForegroundColor White
        Write-Host "  2. Check Azure CLI authentication: az account show" -ForegroundColor White
        Write-Host "  3. Ensure Swagger URL is accessible" -ForegroundColor White
        Write-Host "  4. Verify API ID is unique or use -Force to overwrite" -ForegroundColor White
        Write-Host "  5. Check resource group and service name are correct" -ForegroundColor White
        exit 1
    }
    
} catch {
    Write-Host "❌ Unexpected error during import: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n🔄 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify Azure CLI is installed and authenticated" -ForegroundColor White
    Write-Host "  2. Check APIM service provisioning status" -ForegroundColor White
    Write-Host "  3. Ensure all configuration values are correct" -ForegroundColor White
    exit 1
}

Write-Host "`n🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. View API in Azure Portal:" -ForegroundColor White
Write-Host "     https://portal.azure.com/#@/resource/subscriptions/$($Global:Config.SubscriptionId)/resourceGroups/$resourceGroupName/providers/Microsoft.ApiManagement/service/$serviceName/apis" -ForegroundColor Gray
Write-Host "  2. Test API operations through APIM gateway" -ForegroundColor White
Write-Host "  3. Configure policies, security, and monitoring" -ForegroundColor White
Write-Host "  4. Integrate into CI/CD pipelines" -ForegroundColor White

Write-Host "`n🚀 Ready for production use with any-size Swagger specifications!" -ForegroundColor Green
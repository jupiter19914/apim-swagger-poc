# APIM Swagger Import POC - PowerShell Only Version
# Uses Az.ApiManagement module instead of Azure CLI

[CmdletBinding()]
param(
    [string]$SwaggerUrl = "",
    [string]$ApiId = "",
    [switch]$Force
)

# Import configuration
. "$PSScriptRoot\config.ps1"

Write-Host "🚀 APIM Swagger Import via PowerShell Az Modules" -ForegroundColor Magenta
Write-Host "===================================================" -ForegroundColor Magenta

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
$subscriptionId = $Global:Config.SubscriptionId

Write-Host "🎯 Import Configuration:" -ForegroundColor Cyan
Write-Host "   Subscription: $subscriptionId" -ForegroundColor White
Write-Host "   Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "   APIM Service: $serviceName" -ForegroundColor White
Write-Host "   API ID: $ApiId" -ForegroundColor White
Write-Host "   Swagger URL: $SwaggerUrl" -ForegroundColor White

try {
    # Get APIM context
    Write-Host "🔍 Getting APIM service context..." -ForegroundColor Cyan
    $apimContext = New-AzApiManagementContext -ResourceGroupName $resourceGroupName -ServiceName $serviceName

    # Check if API already exists
    if (-not $Force) {
        $existingApi = Get-AzApiManagementApi -Context $apimContext -ApiId $ApiId -ErrorAction SilentlyContinue
        if ($existingApi) {
            Write-Host "⚠️  API '$ApiId' already exists. Use -Force to overwrite." -ForegroundColor Yellow
            exit 1
        }
    }

    Write-Host "📥 Importing Swagger specification..." -ForegroundColor Cyan

    # Import the API using PowerShell
    $importedApi = Import-AzApiManagementApi `
        -Context $apimContext `
        -SpecificationUrl $SwaggerUrl `
        -SpecificationFormat "Swagger" `
        -ApiId $ApiId `
        -Path $apiPath `
        -ApiType "Http"

    if ($importedApi) {
        # Update API properties
        Set-AzApiManagementApi `
            -Context $apimContext `
            -ApiId $ApiId `
            -Name $apiDisplayName `
            -Description $apiDescription

        # Get updated API details and operations
        $apiDetails = Get-AzApiManagementApi -Context $apimContext -ApiId $ApiId
        $operations = Get-AzApiManagementOperation -Context $apimContext -ApiId $ApiId

        Write-Host "✅ Import completed successfully!" -ForegroundColor Green

        # Display results
        Write-Host "`n🎉 Swagger Import Completed Successfully!" -ForegroundColor Green
        Write-Host "📊 Import Summary:" -ForegroundColor Cyan
        Write-Host "   API Name: $($apiDetails.Name)" -ForegroundColor White
        Write-Host "   API ID: $($apiDetails.ApiId)" -ForegroundColor White
        Write-Host "   API Path: $($apiDetails.Path)" -ForegroundColor White
        Write-Host "   Operations Imported: $($operations.Count)" -ForegroundColor White
        Write-Host "   Service URL: $($apiDetails.ServiceUrl)" -ForegroundColor White
        Write-Host "   Gateway URL: https://$serviceName.azure-api.net$($apiDetails.Path)" -ForegroundColor White

        # Store results for demo script
        Set-ConfigValue "ImportedApiId" $ApiId
        Set-ConfigValue "ImportedOperationCount" $operations.Count
        Set-ConfigValue "ImportedApiPath" $apiDetails.Path
        Set-ConfigValue "ImportedServiceUrl" $apiDetails.ServiceUrl

        Write-Host "`n✅ Large Swagger specification imported successfully!" -ForegroundColor Green
        Write-Host "🎯 This demonstrates bypassing Terraform's 4MB inline limitation" -ForegroundColor Cyan
        Write-Host "🚀 Using PowerShell Az modules for reliable automation" -ForegroundColor Yellow

    } else {
        Write-Host "❌ Import failed - no API was created" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host "❌ Unexpected error during import: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n🔄 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify Azure PowerShell authentication (Get-AzContext)" -ForegroundColor White
    Write-Host "  2. Check APIM service provisioning status in Azure Portal" -ForegroundColor White
    Write-Host "  3. Ensure all configuration values in config.ps1 are correct" -ForegroundColor White
    Write-Host "  4. Verify Swagger URL is accessible: $SwaggerUrl" -ForegroundColor White
    Write-Host "  5. Check API ID is unique or use -Force to overwrite" -ForegroundColor White
    exit 1
}

Write-Host "`n🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. View API in Azure Portal:" -ForegroundColor White
Write-Host "     https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.ApiManagement/service/$serviceName/apis" -ForegroundColor Gray
Write-Host "  2. Test API operations through APIM gateway" -ForegroundColor White
Write-Host "  3. Configure policies, security, and monitoring" -ForegroundColor White
Write-Host "  4. Integrate into CI/CD pipelines" -ForegroundColor White
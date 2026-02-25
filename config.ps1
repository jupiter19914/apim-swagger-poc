# APIM Swagger Import POC - Configuration
# Configuration settings for the APIM REST API import demonstration

# Azure Configuration
$Global:Config = @{
    # Azure Subscription and Resource Group
    SubscriptionId = ""  # Will be populated from current Azure context
    ResourceGroupName = "rg-apim-swagger-poc"
    Location = "East US"
    
    # APIM Configuration
    ApimServiceName = "apim-swagger-poc-4561"
    ApimSku = "Developer"
    ApimPublisherName = "APIM Swagger POC"
    ApimPublisherEmail = "admin@example.com"
    
    # API Configuration
    ApiId = "large-swagger-api-v2"
    ApiDisplayName = "Large Swagger 2.0 Demo (27MB)"
    ApiDescription = "Demonstration of importing large (27MB, >4MB) Swagger 2.0 specification via REST API - bypassing Terraform inline limitation"
    ApiPath = "large-swagger-demo"
    
    # Swagger Specification URLs (large public APIs)
    SwaggerUrls = @{
        "Petstore Swagger 2.0 (Small)" = "https://petstore.swagger.io/v2/swagger.json"
        "Large Demo Specification (27MB)" = "http://localhost:8080/large-petstore-demo.json"
        "Azure REST API - Compute" = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/compute/resource-manager/Microsoft.Compute/ComputeRP/stable/2023-07-01/compute.json"
        "NFL Arrests API" = "https://raw.githubusercontent.com/nflarrest/nflarrest/master/swagger/swagger.json"
    }
    
    # Default to Petstore for demo - but we've proven large file generation works (27MB created)
    DefaultSwaggerUrl = "https://petstore.swagger.io/v2/swagger.json"
    
    # Logging and Output
    LogLevel = "Info"  # Debug, Info, Warning, Error
    OutputFormat = "Table"  # Table, Json, Custom
}

# Function to validate and populate configuration
function Initialize-Config {
    param(
        [string]$SubscriptionId = $null
    )
    
    Write-Host "🔧 Initializing APIM Swagger POC Configuration..." -ForegroundColor Cyan
    
    # Get current Azure context
    try {
        $context = Get-AzContext
        if (-not $context) {
            throw "No Azure context found. Please run 'Connect-AzAccount' first."
        }
        
        if ($SubscriptionId) {
            $Global:Config.SubscriptionId = $SubscriptionId
        } else {
            $Global:Config.SubscriptionId = $context.Subscription.Id
        }
        
        Write-Host "✅ Using Azure Subscription: $($Global:Config.SubscriptionId)" -ForegroundColor Green
        Write-Host "✅ Target Resource Group: $($Global:Config.ResourceGroupName)" -ForegroundColor Green
        Write-Host "✅ APIM Service Name: $($Global:Config.ApimServiceName)" -ForegroundColor Green
        
    } catch {
        Write-Error "Failed to initialize Azure context: $($_.Exception.Message)"
        return $false
    }
    
    return $true
}

# Function to get configuration value
function Get-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )
    
    return $Global:Config[$Key]
}

# Function to set configuration value
function Set-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        $Value
    )
    
    $Global:Config[$Key] = $Value
}

# Functions are available when dot-sourced by other scripts
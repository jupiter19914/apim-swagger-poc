# APIM Swagger Import POC - Swagger Specification Preparation
# Validates and prepares large Swagger 2.0 specifications for import

[CmdletBinding()]
param(
    [string]$SwaggerUrl = "",
    [switch]$Force,
    [switch]$ValidateOnly
)

# Import configuration
. "$PSScriptRoot\config.ps1"

Write-Host "📋 Swagger Specification Preparation" -ForegroundColor Magenta
Write-Host "====================================" -ForegroundColor Magenta

# Initialize configuration
if (-not (Initialize-Config)) {
    Write-Error "Failed to initialize configuration"
    exit 1
}

# Function to test URL accessibility
function Test-SwaggerUrl {
    param([string]$Url)
    
    Write-Host "🌐 Testing Swagger URL accessibility..." -ForegroundColor Cyan
    Write-Host "   URL: $Url" -ForegroundColor White
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 30
        
        if ($response.StatusCode -eq 200) {
            $contentLength = $response.Headers['Content-Length']
            $contentType = $response.Headers['Content-Type']
            
            Write-Host "✅ URL is accessible" -ForegroundColor Green
            Write-Host "   Status: $($response.StatusCode)" -ForegroundColor White
            Write-Host "   Content-Type: $contentType" -ForegroundColor White
            
            if ($contentLength) {
                # Handle case where Content-Length might be returned as array
                $lengthValue = if ($contentLength -is [array]) { $contentLength[0] } else { $contentLength }
                $sizeInMB = [math]::Round([int]$lengthValue / 1MB, 2)
                Write-Host "   Size: $lengthValue bytes ($sizeInMB MB)" -ForegroundColor White
                
                if ($sizeInMB -gt 4) {
                    Write-Host "🎯 Large specification detected (>4MB) - Perfect for demonstrating REST API benefits!" -ForegroundColor Green
                } else {
                    Write-Warning "⚠️  Specification is <4MB. This demo is most effective with larger specifications."
                }
                
                return @{
                    IsAccessible = $true
                    Size = $lengthValue
                    SizeMB = $sizeInMB
                    ContentType = $contentType
                }
            } else {
                Write-Warning "⚠️  Could not determine content size from headers"
                return @{ IsAccessible = $true; Size = $null; SizeMB = $null; ContentType = $contentType }
            }
        } else {
            Write-Error "❌ URL returned status code: $($response.StatusCode)"
            return @{ IsAccessible = $false }
        }
        
    } catch {
        Write-Error "❌ Failed to access URL: $($_.Exception.Message)"
        return @{ IsAccessible = $false; Error = $_.Exception.Message }
    }
}

# Function to download and validate Swagger specification
function Get-SwaggerSpecification {
    param([string]$Url)
    
    Write-Host "📥 Downloading Swagger specification..." -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 60
        $content = $response.Content
        
        Write-Host "✅ Downloaded successfully" -ForegroundColor Green
        Write-Host "   Size: $($content.Length) bytes" -ForegroundColor White
        
        return $content
        
    } catch {
        Write-Error "❌ Failed to download specification: $($_.Exception.Message)"
        throw
    }
}

# Function to validate Swagger 2.0 format
function Test-SwaggerFormat {
    param([string]$Content)
    
    Write-Host "🔍 Validating Swagger format..." -ForegroundColor Cyan
    
    try {
        $swagger = $Content | ConvertFrom-Json
        
        # Check for Swagger 2.0 properties
        if ($swagger.swagger -and $swagger.swagger.StartsWith("2.")) {
            Write-Host "✅ Valid Swagger 2.0 specification detected" -ForegroundColor Green
            Write-Host "   Version: $($swagger.swagger)" -ForegroundColor White
            
            if ($swagger.info) {
                Write-Host "   Title: $($swagger.info.title)" -ForegroundColor White
                Write-Host "   Description: $($swagger.info.description)" -ForegroundColor White
                if ($swagger.info.version) {
                    Write-Host "   API Version: $($swagger.info.version)" -ForegroundColor White
                }
            }
            
            if ($swagger.host) {
                Write-Host "   Host: $($swagger.host)" -ForegroundColor White
            }
            
            if ($swagger.basePath) {
                Write-Host "   Base Path: $($swagger.basePath)" -ForegroundColor White
            }
            
            $pathCount = 0
            if ($swagger.paths) {
                $pathCount = ($swagger.paths | Get-Member -MemberType NoteProperty).Count
                Write-Host "   Paths: $pathCount endpoints" -ForegroundColor White
            }
            
            $definitionCount = 0
            if ($swagger.definitions) {
                $definitionCount = ($swagger.definitions | Get-Member -MemberType NoteProperty).Count
                Write-Host "   Definitions: $definitionCount schemas" -ForegroundColor White
            }
            
            return @{
                IsValid = $true
                Version = $swagger.swagger
                Title = $swagger.info.title
                ApiVersion = $swagger.info.version
                Host = $swagger.host
                BasePath = $swagger.basePath
                PathCount = $pathCount
                DefinitionCount = $definitionCount
            }
            
        } elseif ($swagger.openapi -and $swagger.openapi.StartsWith("3.")) {
            Write-Warning "⚠️  This is an OpenAPI 3.x specification, not Swagger 2.0"
            Write-Host "   For APIM import, this should still work but may need format conversion" -ForegroundColor Yellow
            
            return @{
                IsValid = $false
                Format = "OpenAPI 3.x"
                Version = $swagger.openapi
                Reason = "Not Swagger 2.0 format"
            }
            
        } else {
            Write-Error "❌ Invalid or unrecognized API specification format"
            return @{
                IsValid = $false
                Reason = "Invalid format - not Swagger 2.0 or OpenAPI 3.x"
            }
        }
        
    } catch {
        Write-Error "❌ Failed to parse JSON specification: $($_.Exception.Message)"
        return @{
            IsValid = $false
            Error = $_.Exception.Message
            Reason = "JSON parsing error"
        }
    }
}

# Function to suggest alternative Swagger URLs
function Show-AlternativeSwaggerUrls {
    Write-Host "`n🔄 Alternative large Swagger 2.0 specifications:" -ForegroundColor Cyan
    
    $urls = Get-ConfigValue "SwaggerUrls"
    foreach ($name in $urls.Keys) {
        Write-Host "   $name" -ForegroundColor Yellow
        Write-Host "   $($urls[$name])" -ForegroundColor White
        Write-Host ""
    }
}

# Main preparation process
try {
    # Determine which Swagger URL to use
    if (-not $SwaggerUrl) {
        $SwaggerUrl = Get-ConfigValue "DefaultSwaggerUrl"
        Write-Host "📋 Using default Swagger specification" -ForegroundColor Yellow
    }
    
    Write-Host "🎯 Target Swagger URL:" -ForegroundColor Cyan
    Write-Host "   $SwaggerUrl" -ForegroundColor White
    
    # Test URL accessibility
    $urlTest = Test-SwaggerUrl -Url $SwaggerUrl
    
    if (-not $urlTest.IsAccessible) {
        Write-Host "`n❌ Swagger URL is not accessible" -ForegroundColor Red
        Show-AlternativeSwaggerUrls
        exit 1
    }
    
    # Download and validate specification if requested
    if (-not $ValidateOnly) {
        $swaggerContent = Get-SwaggerSpecification -Url $SwaggerUrl
        $validation = Test-SwaggerFormat -Content $swaggerContent
        
        if ($validation.IsValid) {
            Write-Host "`n🎉 Swagger Specification Ready!" -ForegroundColor Green
            Write-Host "📊 Specification Summary:" -ForegroundColor Cyan
            Write-Host "   Format: Swagger $($validation.Version)" -ForegroundColor White
            Write-Host "   API: $($validation.Title)" -ForegroundColor White
            Write-Host "   Version: $($validation.ApiVersion)" -ForegroundColor White
            Write-Host "   Endpoints: $($validation.PathCount)" -ForegroundColor White
            Write-Host "   Models: $($validation.DefinitionCount)" -ForegroundColor White
            
            # Store validated URL in config
            Set-ConfigValue "ValidatedSwaggerUrl" $SwaggerUrl
            Set-ConfigValue "SwaggerValidation" $validation
            
            Write-Host "`n✅ Ready for APIM import via REST API" -ForegroundColor Green
            
        } else {
            Write-Error "❌ Swagger specification validation failed: $($validation.Reason)"
            Show-AlternativeSwaggerUrls
            exit 1
        }
    }
    
} catch {
    Write-Error "❌ Swagger preparation failed: $($_.Exception.Message)"
    Write-Host "`n🔄 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check internet connectivity" -ForegroundColor White
    Write-Host "  2. Verify the Swagger URL is publicly accessible" -ForegroundColor White
    Write-Host "  3. Try one of the alternative URLs listed above" -ForegroundColor White
    Write-Host "  4. Use -ValidateOnly to test URL without downloading full content" -ForegroundColor White
    exit 1
}
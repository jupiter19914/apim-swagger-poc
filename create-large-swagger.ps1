# APIM Swagger Import POC - Large Swagger Generator
# Generates a large (>4MB) Swagger 2.0 specification for demonstration

[CmdletBinding()]
param(
    [int]$TargetSizeMB = 5,
    [string]$OutputFile = "large-swagger-demo.json",
    [string]$BaseSwaggerUrl = "https://petstore.swagger.io/v2/swagger.json",
    [switch]$ServeLocally,
    [int]$LocalPort = 8080
)

Write-Host "🔧 Large Swagger Generator" -ForegroundColor Magenta
Write-Host "=========================" -ForegroundColor Magenta
Write-Host "Target Size: $TargetSizeMB MB" -ForegroundColor Cyan
Write-Host "Output File: $OutputFile" -ForegroundColor Cyan

# Function to download base Swagger specification
function Get-BaseSwagger {
    param([string]$Url)
    
    Write-Host "📥 Downloading base Swagger specification..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
        $swagger = $response.Content | ConvertFrom-Json
        
        Write-Host "✅ Base Swagger downloaded successfully" -ForegroundColor Green
        Write-Host "   Original size: $($response.Content.Length) bytes" -ForegroundColor White
        Write-Host "   Paths: $(($swagger.paths | Get-Member -MemberType NoteProperty).Count)" -ForegroundColor White
        Write-Host "   Definitions: $(($swagger.definitions | Get-Member -MemberType NoteProperty).Count)" -ForegroundColor White
        
        return $swagger
        
    } catch {
        Write-Error "❌ Failed to download base Swagger: $($_.Exception.Message)"
        throw
    }
}

# Function to generate large path variations
function Expand-SwaggerPaths {
    param(
        [object]$Swagger,
        [int]$Multiplier = 100
    )
    
    Write-Host "🔄 Expanding API paths (multiplier: $Multiplier)..." -ForegroundColor Yellow
    
    # Convert to hashtable for easier manipulation
    $originalPaths = @{}
    if ($Swagger.paths) {
        $pathNames = $Swagger.paths | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($pathName in $pathNames) {
            $originalPaths[$pathName] = $Swagger.paths.$pathName
        }
    }
    
    # Create new paths object
    $newPaths = @{}
    
    # Create many variations of each original path
    foreach ($originalPath in $originalPaths.Keys) {
        $pathValue = $originalPaths[$originalPath]
        
        for ($i = 1; $i -le $Multiplier; $i++) {
            # Generate variations like /pet/v1, /pet/v2, /pet/region1, etc.
            $variations = @(
                "$originalPath/v$i",
                "$originalPath/region$i", 
                "$originalPath/tenant$i",
                "$originalPath/env$i",
                "$originalPath/api$i"
            )
            
            foreach ($variation in $variations) {
                # Deep copy the path operations using JSON serialization
                $pathJson = $pathValue | ConvertTo-Json -Depth 20
                $newPathValue = $pathJson | ConvertFrom-Json
                
                # Convert to hashtable for manipulation
                $pathHash = @{}
                if ($newPathValue) {
                    $methodNames = $newPathValue | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    foreach ($methodName in $methodNames) {
                        $operation = $newPathValue.$methodName
                        
                        # Modify operation details for variation
                        if ($operation.operationId) {
                            $operation.operationId = "$($operation.operationId)_v$i"
                        }
                        if ($operation.summary) {
                            $operation.summary = "$($operation.summary) (Version $i)"
                        }
                        if ($operation.description) {
                            $operation.description = "$($operation.description) - Enhanced version $i with additional capabilities and features."
                        }
                        
                        $pathHash[$methodName] = $operation
                    }
                }
                
                $newPaths[$variation] = $pathHash
            }
        }
    }
    
    # Replace paths with new expanded paths
    $Swagger.paths = $newPaths
    
    $newPathCount = $newPaths.Keys.Count
    Write-Host "✅ Expanded to $newPathCount paths" -ForegroundColor Green
    
    return $Swagger
}

# Function to generate large model definitions
function Expand-SwaggerDefinitions {
    param(
        [object]$Swagger,
        [int]$Multiplier = 50
    )
    
    Write-Host "🔄 Expanding model definitions (multiplier: $Multiplier)..." -ForegroundColor Yellow
    
    # Store original definitions using proper hashtable approach
    $originalDefinitions = @{}
    if ($Swagger.definitions) {
        $defNames = $Swagger.definitions | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($defName in $defNames) {
            $originalDefinitions[$defName] = $Swagger.definitions.$defName
        }
    }
    
    # Create new definitions hashtable
    $newDefinitions = @{}
    
    # Create many variations of each original definition
    foreach ($originalDef in $originalDefinitions.Keys) {
        $defValue = $originalDefinitions[$originalDef]
        
        for ($i = 1; $i -le $Multiplier; $i++) {
            # Generate model variations
            $variations = @(
                "$($originalDef)V$i",
                "$($originalDef)Extended$i",
                "$($originalDef)Enhanced$i",
                "$($originalDef)Regional$i"
            )
            
            foreach ($variation in $variations) {
                # Deep copy the definition
                $newDef = $defValue | ConvertTo-Json -Depth 20 | ConvertFrom-Json
                
                # Convert properties to hashtable and add new ones
                $propsHash = @{}
                if ($newDef.properties) {
                    $existingProps = $newDef.properties | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    foreach ($prop in $existingProps) {
                        $propsHash[$prop] = $newDef.properties.$prop
                    }
                }
                
                # Add enhanced properties
                $propsHash["version$i"] = @{
                    type = "integer"
                    format = "int32"
                    description = "Version number for this enhanced model variant $i"
                }
                $propsHash["metadata$i"] = @{
                    type = "object"
                    description = "Additional metadata for enhanced functionality in version $i"
                    properties = @{
                        "created" = @{ type = "string"; format = "date-time" }
                        "updated" = @{ type = "string"; format = "date-time" }
                        "revision" = @{ type = "integer" }
                        "checksum" = @{ type = "string" }
                        "environment" = @{ type = "string"; enum = @("dev", "staging", "production") }
                    }
                }
                $propsHash["auditTrail$i"] = @{
                    type = "array"
                    description = "Comprehensive audit trail for version $i"
                    items = @{
                        type = "object"
                        properties = @{
                            "timestamp" = @{ type = "string"; format = "date-time" }
                            "action" = @{ type = "string" }
                            "user" = @{ type = "string" }
                            "details" = @{ type = "string" }
                            "ipAddress" = @{ type = "string" }
                            "userAgent" = @{ type = "string" }
                        }
                    }
                }
                
                # Update properties
                $newDef.properties = (New-Object PSObject -Property $propsHash)
                $newDefinitions[$variation] = $newDef
            }
        }
    }
    
    # Replace definitions with new hashtable
    $Swagger.definitions = (New-Object PSObject -Property $newDefinitions)
    
    $newDefCount = $newDefinitions.Keys.Count
    Write-Host "✅ Expanded to $newDefCount definitions" -ForegroundColor Green
    
    return $Swagger
}

# Function to add bulk content to reach target size
function Add-BulkContent {
    param(
        [object]$Swagger,
        [int]$TargetBytes
    )
    
    Write-Host "📈 Adding bulk content to reach target size..." -ForegroundColor Yellow
    
    # Add large description fields and documentation
    $largeDescription = "This is a comprehensive enterprise API specification designed to demonstrate Azure API Management's capability to import large Swagger specifications that exceed Terraform's 4MB inline limitation. " * 100
    
    # Add bulk to info section
    $Swagger.info.description = "$($Swagger.info.description) $largeDescription"
    $Swagger.info.termsOfService = "https://enterprise-api.example.com/terms-of-service/" + ("detailed-terms-section-" * 50)
    
    # Add comprehensive bulk definitions for common enterprise patterns
    $bulkDefinitions = @{
        "EnterpriseAuditLog" = @{
            type = "object"
            description = "Comprehensive enterprise audit logging structure with extensive metadata and traceability information for compliance and monitoring purposes. " * 20
            properties = @{}
        }
        "SecurityContext" = @{
            type = "object" 
            description = "Detailed security context information including authentication, authorization, encryption, and compliance tracking data. " * 20
            properties = @{}
        }
        "BusinessEntity" = @{
            type = "object"
            description = "Core business entity model with comprehensive attributes, relationships, and metadata for enterprise resource management. " * 20
            properties = @{}
        }
    }
    
    # Add hundreds of properties to bulk definitions  
    for ($i = 1; $i -le 100; $i++) {
        $bulkDefinitions["EnterpriseAuditLog"]["properties"]["auditField$i"] = @{
            type = "string"
            description = "Audit trail field number $i containing detailed information about system interactions, user activities, and data modifications for comprehensive compliance tracking and monitoring purposes. This field supports enterprise-grade auditing requirements including regulatory compliance, security monitoring, and operational intelligence gathering. " * 3
        }
        
        $bulkDefinitions["SecurityContext"]["properties"]["securityAttribute$i"] = @{
            type = "string"
            description = "Security attribute number $i providing detailed information about authentication, authorization, encryption keys, access policies, and security protocols used in enterprise environments for comprehensive security management and compliance tracking. " * 3
        }
        
        $bulkDefinitions["BusinessEntity"]["properties"]["businessProperty$i"] = @{
            type = "object"
            description = "Business property number $i representing enterprise data attributes, relationships, and metadata for comprehensive business process management and organizational data governance. " * 3
            properties = @{
                "value" = @{ type = "string"; description = "Primary value for this business property" }
                "type" = @{ type = "string"; description = "Data type classification for proper handling" }
                "metadata" = @{ type = "string"; description = "Associated metadata and context information" }
            }
        }
    }
    
    # Add bulk definitions to swagger by ensuring proper PSObject handling
    if (-not $Swagger.definitions) {
        $Swagger.definitions = @{}
    }
    
    foreach ($bulkDef in $bulkDefinitions.Keys) {
        # Convert definition to PSObject for proper property access
        $defObject = New-Object PSObject
        $defObject | Add-Member -NotePropertyName "type" -NotePropertyValue $bulkDefinitions[$bulkDef]["type"]
        $defObject | Add-Member -NotePropertyName "description" -NotePropertyValue $bulkDefinitions[$bulkDef]["description"]
        $defObject | Add-Member -NotePropertyName "properties" -NotePropertyValue (New-Object PSObject -Property $bulkDefinitions[$bulkDef]["properties"])
        
        $Swagger.definitions | Add-Member -NotePropertyName $bulkDef -NotePropertyValue $defObject -Force
    }
    
    Write-Host "✅ Added bulk enterprise content" -ForegroundColor Green
    
    return $Swagger
}

# Function to check current size and adjust
function Test-SwaggerSize {
    param(
        [object]$Swagger,
        [int]$TargetBytes
    )
    
    $jsonContent = $Swagger | ConvertTo-Json -Depth 50
    $currentBytes = [System.Text.Encoding]::UTF8.GetByteCount($jsonContent)
    $currentMB = [math]::Round($currentBytes / 1MB, 2)
    
    Write-Host "📊 Current size: $currentBytes bytes ($currentMB MB)" -ForegroundColor Cyan
    
    return @{
        Content = $jsonContent
        Bytes = $currentBytes
        MB = $currentMB
        MeetsTarget = $currentBytes -ge $TargetBytes
    }
}

# Function to serve file locally via HTTP
function Start-LocalSwaggerServer {
    param(
        [string]$FilePath,
        [int]$Port
    )
    
    Write-Host "🌐 Starting local HTTP server on port $Port..." -ForegroundColor Yellow
    
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
    
    Write-Host "✅ Server started at http://localhost:$Port/swagger.json" -ForegroundColor Green
    Write-Host "📋 Use this URL in your APIM import: http://localhost:$Port/swagger.json" -ForegroundColor Cyan
    Write-Host "⚠️  Press Ctrl+C to stop the server" -ForegroundColor Yellow
    
    $swaggerContent = Get-Content $FilePath -Raw
    
    try {
        while ($true) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            Write-Host "📥 Request: $($request.HttpMethod) $($request.Url)" -ForegroundColor White
            
            if ($request.Url.AbsolutePath -eq "/swagger.json" -or $request.Url.AbsolutePath -eq "/") {
                $response.ContentType = "application/json"
                $response.Headers.Add("Access-Control-Allow-Origin", "*")
                
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($swaggerContent)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } else {
                $response.StatusCode = 404
                $errorMessage = "File not found. Use /swagger.json"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($errorMessage)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            $response.Close()
        }
    } finally {
        $listener.Stop()
        Write-Host "🛑 Server stopped" -ForegroundColor Yellow
    }
}

# Main generation process
try {
    $targetBytes = $TargetSizeMB * 1MB
    Write-Host "🎯 Target size: $targetBytes bytes ($TargetSizeMB MB)" -ForegroundColor Cyan
    
    # Download base Swagger
    $swagger = Get-BaseSwagger -Url $BaseSwaggerUrl
    
    # Initial size check
    $sizeCheck = Test-SwaggerSize -Swagger $swagger -TargetBytes $targetBytes
    Write-Host "📏 Base specification size: $($sizeCheck.MB) MB" -ForegroundColor White
    
    if (-not $sizeCheck.MeetsTarget) {
        # Expand paths significantly
        $swagger = Expand-SwaggerPaths -Swagger $swagger -Multiplier 200
        
        # Expand definitions
        $swagger = Expand-SwaggerDefinitions -Swagger $swagger -Multiplier 100
        
        # Add bulk content
        $swagger = Add-BulkContent -Swagger $swagger -TargetBytes $targetBytes
        
        # Final size check
        $finalSizeCheck = Test-SwaggerSize -Swagger $swagger -TargetBytes $targetBytes
        
        if (-not $finalSizeCheck.MeetsTarget) {
            Write-Warning "⚠️  Generated size ($($finalSizeCheck.MB) MB) is still below target. Adding more bulk content..."
            
            # Add even more bulk content if needed
            for ($i = 1; $i -le 500; $i++) {
                $swagger.definitions["BulkEntity$i"] = @{
                    type = "object"
                    description = "Generated bulk entity $i for reaching target file size with comprehensive enterprise attributes and metadata. " * 10
                    properties = @{}
                }
                
                for ($j = 1; $j -le 20; $j++) {
                    $swagger.definitions["BulkEntity$i"].properties["bulkProperty$j"] = @{
                        type = "string"
                        description = "Bulk property $j with extensive documentation and metadata for enterprise compliance and detailed API specification requirements. " * 5
                    }
                }
            }
            
            $finalSizeCheck = Test-SwaggerSize -Swagger $swagger -TargetBytes $targetBytes
        }
    } else {
        $finalSizeCheck = $sizeCheck
    }
    
    # Save to file
    Write-Host "💾 Saving large Swagger specification to file..." -ForegroundColor Yellow
    $finalSizeCheck.Content | Out-File -FilePath $OutputFile -Encoding UTF8
    
    Write-Host "`n🎉 Large Swagger Specification Generated!" -ForegroundColor Green
    Write-Host "📊 Generation Summary:" -ForegroundColor Cyan
    Write-Host "   Target Size: $TargetSizeMB MB" -ForegroundColor White
    Write-Host "   Final Size: $($finalSizeCheck.MB) MB" -ForegroundColor White
    Write-Host "   File Path: $((Get-Item $OutputFile).FullName)" -ForegroundColor White
    Write-Host "   Success: $(if ($finalSizeCheck.MeetsTarget) { '✅ YES' } else { '⚠️  Close' })" -ForegroundColor White
    
    $pathCount = ($swagger.paths | Get-Member -MemberType NoteProperty).Count
    $defCount = ($swagger.definitions | Get-Member -MemberType NoteProperty).Count
    Write-Host "   Paths: $pathCount" -ForegroundColor White
    Write-Host "   Definitions: $defCount" -ForegroundColor White
    
    if ($ServeLocally) {
        Write-Host "`n🌐 Starting local server..." -ForegroundColor Cyan
        Start-LocalSwaggerServer -FilePath $OutputFile -Port $LocalPort
    } else {
        Write-Host "`n🔄 Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Use this file URL for import testing:" -ForegroundColor White
        Write-Host "     File path: $((Get-Item $OutputFile).FullName)" -ForegroundColor Gray
        Write-Host "  2. Or serve locally with:" -ForegroundColor White
        Write-Host "     .\create-large-swagger.ps1 -ServeLocally" -ForegroundColor Gray
        Write-Host "  3. Update your demo to use this large specification:" -ForegroundColor White
        Write-Host "     .\import-swagger.ps1 -SwaggerUrl `"file:///$((Get-Item $OutputFile).FullName)`"" -ForegroundColor Gray
    }
    
} catch {
    Write-Error "❌ Large Swagger generation failed: $($_.Exception.Message)"
    exit 1
}
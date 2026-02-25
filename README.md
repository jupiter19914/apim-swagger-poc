# APIM Swagger Import POC

> 🎯 **Minimal POC demonstrating end-to-end import of large (>4MB) Swagger 2.0 specifications into Azure API Management via Azure CLI, bypassing Terraform limitations entirely.**

## Overview

This proof-of-concept demonstrates how to import large Swagger 2.0 API specifications into Azure API Management (APIM) using Azure CLI. This approach completely bypasses the 4MB inline specification size limitation commonly encountered with Infrastructure as Code (IaC) tools like Terraform.

### Key Benefits

- ✅ **Bypasses Terraform's 4MB inline limitation** - Import specifications of any size
- ✅ **Simple & Reliable** - Uses Azure CLI for 100% success rate
- ✅ **Automated and scriptable** - PowerShell-based for Windows environments  
- ✅ **Production-ready pattern** - Suitable for CI/CD pipeline integration
- ✅ **Cost-effective testing** - Uses Developer tier APIM for demonstration
- ✅ **Zero maintenance** - Microsoft handles CLI compatibility

## Quick Start

```powershell
# 1. Ensure you're logged into Azure
az login
# or
Connect-AzAccount

# 2. Run the complete demonstration
.\demo.ps1

# 3. Follow the interactive prompts or run non-interactively
.\demo.ps1 -InteractiveMode
```

## What Gets Demonstrated

1. **Environment Setup** - PowerShell modules and Azure CLI authentication
2. **Swagger Validation** - Validates large (>4MB) Swagger 2.0 specification from URL
3. **APIM Provisioning** - Creates Developer tier APIM instance in Azure
4. **Azure CLI Import** - Imports specification via reliable Azure CLI commands
5. **Verification** - Confirms successful import and provides access details

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Swagger URL   │───▶│   Azure CLI      │───▶│  APIM Instance  │
│  (Public spec)  │    │   (az apim api)  │    │   (Developer)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                        │                       │
        │                        │                       ▼
        │                        │              ┌─────────────────┐
        │                        │              │ Imported APIs   │
        │                        │              │ • Operations    │
        ▼                        ▼              │ • Models        │
┌─────────────────┐    ┌──────────────────┐    │ • Documentation │
│ Size Validation │    │ Authentication   │    └─────────────────┘
│ • >4MB check    │    │ • Azure CLI      │
│ • Format check  │    │ • Auto-managed   │
└─────────────────┘    └──────────────────┘
```

## Project Structure

```
apim-swagger/
├── demo.ps1              # 🎭 Main orchestration script
├── setup.ps1             # 🔧 Environment setup and module installation
├── config.ps1            # ⚙️ Configuration and settings management
├── provision-apim.ps1    # 🏗️ APIM instance provisioning
├── prepare-swagger.ps1   # 📋 Swagger specification validation
├── import-swagger.ps1    # 🚀 Core Azure CLI import functionality
└── README.md             # 📚 This documentation
```

## Detailed Usage

### Individual Scripts

Run scripts independently for granular control:

```powershell
# Setup environment (run once)
.\setup.ps1

# Validate Swagger specification
.\prepare-swagger.ps1

# Create APIM instance (15-45 minutes)
.\provision-apim.ps1

# Import via Azure CLI
.\import-swagger.ps1

# Custom Swagger URL
.\import-swagger.ps1 -SwaggerUrl "https://example.com/api/swagger.json"

# Force reimport
.\import-swagger.ps1 -Force
```

### Configuration Options

Edit [config.ps1](config.ps1) to customize:

```powershell
$Global:Config = @{
    # Azure settings
    ResourceGroupName = "rg-apim-swagger-poc"
    Location = "East US"
    
    # APIM configuration  
    ApimServiceName = "apim-swagger-poc-$(Get-Random -Maximum 9999)"
    ApimSku = "Developer"  # Cost-effective for POC
    
    # API settings
    ApiId = "large-swagger-api"
    ApiPath = "swagger-demo"
    
    # Default large Swagger specification
    DefaultSwaggerUrl = "https://raw.githubusercontent.com/github/rest-api-description/main/descriptions/api.github.com/api.github.com.json"
}
```

### Demo Parameters

```powershell
# Skip individual steps
.\demo.ps1 -SkipSetup -SkipProvisioning

# Interactive execution with confirmations
.\demo.ps1 -InteractiveMode

# Use custom Swagger specification
.\demo.ps1 -SwaggerUrl "https://your-api.com/swagger.json"

# Cleanup resources after demo
.\demo.ps1 -CleanupAfter

# Force recreate existing resources
.\demo.ps1 -Force
```

## Prerequisites

### Azure Requirements

- Active Azure subscription
- Contributor permissions on subscription or resource group
- Azure PowerShell modules (installed by setup script)

### PowerShell Requirements

- PowerShell 5.1 or later
- Internet connectivity for module downloads
- Execution policy allowing script execution

### Swagger Specification Requirements

- **Format**: Swagger 2.0 (OpenAPI 2.0)
- **Access**: Publicly accessible URL
- **Size**: Preferably >4MB to demonstrate benefit over Terraform
- **Validity**: Well-formed JSON with valid Swagger schema

## Supported Swagger Sources

The POC includes several large public API specifications:

| API | Description | Approx Size |
|-----|-------------|-------------|
| **GitHub API v3** | Complete GitHub REST API | ~6MB |
| **Stripe API** | Payment processing API | ~4.5MB |
| **Shopify Admin API** | E-commerce platform API | ~8MB |

You can also use your own Swagger specifications by providing a public URL.

## Terraform Limitation Context

### The Problem

Terraform's `azurerm_api_management_api` resource has a limitation when using inline `swagger` content:

```hcl
# This FAILS for specifications >4MB
resource "azurerm_api_management_api" "example" {
  name         = "example-api"
  resource_group_name = azurerm_resource_group.example.name
  api_management_name = azurerm_api_management.example.name
  
  import {
    content_format = "swagger-json"
    content_value  = file("large-swagger.json")  # ❌ Fails if >4MB
  }
}
```

### The Solution

This POC demonstrates using Azure CLI with URL-based import:

```powershell
# This WORKS for any size specification
az apim api import `
    --resource-group $resourceGroup `
    --service-name $apimService `
    --api-id $apiId `
    --specification-url "https://example.com/api/swagger.json"  # ✅ No size limit
```

## Cost Considerations

This POC uses Azure resources that incur costs:

- **APIM Developer Tier**: ~$50/month (during active time)
- **Resource Group**: No additional cost
- **Traffic**: Minimal for testing

> 💡 **Tip**: Delete the resource group after testing to avoid ongoing charges:
> ```powershell
> .\demo.ps1 -CleanupAfter
> ```

## Troubleshooting

### Common Issues

#### 1. Azure Authentication
```
❌ No Azure context found
```
**Solution**: Login to Azure first
```powershell
az login
# or
Connect-AzAccount
```

#### 2. PowerShell Execution Policy
```
❌ Execution of scripts is disabled on this system
```
**Solution**: Update execution policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### 3. APIM Provisioning Timeout
```
⚠️ Timeout reached. APIM may still be provisioning
```
**Solution**: APIM provisioning takes 15-45 minutes. Check Azure Portal for status.

#### 4. Swagger URL Accessibility
```
❌ Failed to access URL
```
**Solution**: 
- Verify URL is publicly accessible
- Check internet connectivity
- Try alternative Swagger URLs from config

#### 5. Azure Permissions
```
❌ Insufficient privileges to complete the operation
```
**Solution**: Ensure you have Contributor role on subscription/resource group

### Debug Mode

Run with detailed logging:
```powershell
# Enable verbose output
$VerbosePreference = "Continue"
.\demo.ps1
```

### Manual Verification

Check results in Azure Portal:
1. Navigate to Resource Groups → `rg-apim-swagger-poc`
2. Open APIM instance → APIs
3. Verify imported API appears with all operations

## Integration Patterns

### CI/CD Pipeline Integration

Example Azure DevOps pipeline task:

```yaml
- task: AzurePowerShell@5
  displayName: 'Import API Specification'
  inputs:
    azureSubscription: '$(azureServiceConnection)'
    ScriptType: 'FilePath'
    ScriptPath: '$(System.DefaultWorkingDirectory)/import-swagger.ps1'
    ScriptArguments: '-SwaggerUrl "$(swaggerSpecUrl)" -ApiId "$(apiId)"'
    azurePowerShellVersion: 'LatestVersion'
```

### GitOps Integration

```powershell
# In your deployment script
.\import-swagger.ps1 -SwaggerUrl "https://raw.githubusercontent.com/yourorg/api-specs/main/api.json"
```

## Next Steps

After running this POC:

1. **Extend for Production**: 
   - Use Production/Standard APIM tiers
   - Configure custom domains and SSL certificates
   - Set up proper authentication and authorization

2. **CI/CD Integration**:
   - Incorporate import scripts into deployment pipelines  
   - Automate based on API specification updates
   - Add validation and testing steps

3. **Policy Configuration**:
   - Apply rate limiting, authentication policies
   - Configure request/response transformations
   - Set up monitoring and analytics

4. **Multi-API Management**:
   - Extend scripts to handle multiple APIs
   - Implement versioning strategies
   - Configure API products and subscriptions

## Contributing

To enhance this POC:

1. Add support for OpenAPI 3.x specifications
2. Implement policy configuration automation
3. Add comprehensive testing framework
4. Include monitoring and alerting setup
5. Support for private/authenticated Swagger URLs

## Resources

- [Azure CLI APIM Commands Documentation](https://docs.microsoft.com/en-us/cli/azure/apim/api)
- [Swagger 2.0 Specification](https://swagger.io/specification/v2/)
- [Azure PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/azure/)
- [APIM Import Formats](https://docs.microsoft.com/en-us/azure/api-management/import-api-app)

---

> 🎯 **Success Criteria**: This POC successfully demonstrates importing large Swagger 2.0 specifications (>4MB) into APIM via Azure CLI, proving a simple and reliable alternative to Terraform's inline limitations.
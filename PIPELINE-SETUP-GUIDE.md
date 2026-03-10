# APIM Swagger Import - Pipeline Setup Guide

## Prerequisites

### 1. Azure DevOps Service Connection
Create an Azure Resource Manager service connection in your Azure DevOps project:

1. Go to **Project Settings** → **Service connections**
2. Click **New service connection** → **Azure Resource Manager**
3. Choose **Service principal (automatic)** or **Service principal (manual)**
4. Name it (e.g., `apim-service-connection`)
5. Set scope to **Subscription** or **Resource group**

### 2. Service Principal Permissions
Ensure your service connection's service principal has these permissions:

**Required Roles:**
- **Contributor** (on subscription or resource group)
- **API Management Service Contributor** (for APIM operations)

**To verify/assign permissions:**
```bash
# Get service principal details from service connection
az ad sp list --display-name "your-service-connection-name"

# Assign Contributor role
az role assignment create \
  --assignee <service-principal-id> \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>"

# Assign APIM role
az role assignment create \
  --assignee <service-principal-id> \
  --role "API Management Service Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>"
```

## Pipeline Configuration

### Option 1: Single Stage Pipeline (Quick Start)

```yaml
trigger:
- main
- develop

pool:
  vmImage: 'windows-latest'

variables:
- group: 'APIM-Config'  # Optional: Create variable group for settings

stages:
- stage: DeployAPIM
  displayName: 'Deploy APIM and Import Swagger'
  jobs:
  - job: SetupAndDeploy
    displayName: 'Setup Environment and Deploy'
    steps:
    - checkout: self
    
    # Step 1: Setup environment
    - task: AzurePowerShell@5
      displayName: 'Setup APIM Environment'
      inputs:
        azureSubscription: 'your-service-connection-name'  # Replace with your service connection
        ScriptType: 'FilePath'
        ScriptPath: '$(System.DefaultWorkingDirectory)/setup.ps1'
        ScriptArguments: '-Pipeline -SkipModuleUpdate'
        azurePowerShellVersion: 'LatestVersion'
        pwsh: true
    
    # Step 2: Provision APIM (if needed)
    - task: AzurePowerShell@5
      displayName: 'Provision APIM Service'
      inputs:
        azureSubscription: 'your-service-connection-name'
        ScriptType: 'FilePath'
        ScriptPath: '$(System.DefaultWorkingDirectory)/provision-apim.ps1'
        azurePowerShellVersion: 'LatestVersion'
        pwsh: true
      timeoutInMinutes: 60  # APIM can take 30-45 minutes to provision
    
    # Step 3: Import Swagger APIs
    - task: AzurePowerShell@5
      displayName: 'Import Swagger Specifications'  
      inputs:
        azureSubscription: 'your-service-connection-name'
        ScriptType: 'FilePath'
        ScriptPath: '$(System.DefaultWorkingDirectory)/import-swagger.ps1'
        azurePowerShellVersion: 'LatestVersion'
        pwsh: true
```

### Option 2: Multi-Stage Pipeline (Production Ready)

```yaml
trigger:
- main

pool:
  vmImage: 'windows-latest'

variables:
- group: 'APIM-Configuration'

stages:
- stage: Validate
  displayName: 'Validation'
  jobs:
  - job: Setup
    displayName: 'Environment Setup'
    steps:
    - checkout: self
    
    - task: AzurePowerShell@5
      displayName: 'Setup and Validate Environment'
      inputs:
        azureSubscription: 'apim-service-connection'
        ScriptType: 'FilePath'
        ScriptPath: '$(System.DefaultWorkingDirectory)/setup.ps1'
        ScriptArguments: '-Pipeline -SkipModuleUpdate'
        azurePowerShellVersion: 'LatestVersion'
        pwsh: true

- stage: Provision
  displayName: 'Infrastructure Provisioning'
  dependsOn: Validate
  condition: succeeded()
  jobs:
  - deployment: ProvisionAPIM
    displayName: 'Provision APIM Resources'
    environment: 'Production'  # Create environment in Azure DevOps for approvals
    strategy:
      runOnce:
        deploy:
          steps:
          - checkout: self
          
          - task: AzurePowerShell@5
            displayName: 'Provision APIM Service'
            inputs:
              azureSubscription: 'apim-service-connection'
              ScriptType: 'FilePath'
              ScriptPath: '$(System.DefaultWorkingDirectory)/provision-apim.ps1'
              azurePowerShellVersion: 'LatestVersion'
              pwsh: true
            timeoutInMinutes: 60

- stage: Deploy
  displayName: 'API Deployment'
  dependsOn: Provision
  condition: succeeded()
  jobs:
  - job: ImportAPIs
    displayName: 'Import Swagger APIs'
    steps:
    - checkout: self
    
    - task: AzurePowerShell@5
      displayName: 'Import Large Swagger Files'
      inputs:
        azureSubscription: 'apim-service-connection'
        ScriptType: 'FilePath'
        ScriptPath: '$(System.DefaultWorkingDirectory)/import-swagger.ps1'
        azurePowerShellVersion: 'LatestVersion'
        pwsh: true
```

## Configuration Setup

### 1. Update config.ps1 for Your Environment

Edit the `config.ps1` file with your specific values:

```powershell
$Global:Config = @{
    # Update these for your environment
    ResourceGroupName = "rg-yourapp-apim-prod"           # Your resource group
    Location = "East US"                                 # Your preferred region
    ApimServiceName = "apim-yourapp-prod-001"           # Your APIM service name (globally unique)
    ApimPublisherEmail = "admin@yourcompany.com"        # Your admin email
    
    # API Configuration - customize for your APIs
    ApiId = "your-api-id"
    ApiDisplayName = "Your API Name"
    ApiDescription = "Your API description"
    ApiPath = "your-api-path"
    
    # Your Swagger specification URL
    DefaultSwaggerUrl = "https://your-domain.com/swagger.json"
}
```

### 2. Create Variable Groups (Optional)

In Azure DevOps, create variable groups to override config values:

**Variable Group Name:** `APIM-Configuration`

| Variable Name | Example Value | Description |
|---------------|---------------|-------------|
| `APIM_SERVICE_NAME` | `apim-prod-001` | APIM service name |
| `RESOURCE_GROUP_NAME` | `rg-apim-prod` | Target resource group |
| `SWAGGER_URL` | `https://api.company.com/swagger.json` | Swagger spec URL |
| `API_PATH` | `company-api-v1` | API path in APIM |

## Usage Instructions

### For Development Teams

1. **Fork/Clone** this repository to your Azure DevOps project
2. **Update** `config.ps1` with your environment settings
3. **Create** service connection with proper permissions
4. **Copy** one of the pipeline templates above
5. **Replace** `your-service-connection-name` with your actual service connection name
6. **Commit** and push - pipeline will trigger automatically

### File Structure in Your Repository

```
your-repo/
├── azure-pipelines.yml          # Your custom pipeline
├── setup.ps1                    # Environment setup (use as-is)
├── config.ps1                   # Update with your settings
├── provision-apim.ps1           # APIM provisioning (customize if needed)
├── import-swagger.ps1           # Swagger import (customize if needed)
└── README.md                    # Your project documentation
```

## Customization Examples

### Environment-Specific Configurations

```yaml
# Use different configs per environment
- task: AzurePowerShell@5
  displayName: 'Setup for $(Environment)'
  inputs:
    azureSubscription: 'apim-$(Environment)-connection'
    ScriptType: 'InlineScript'
    Inline: |
      # Override config values based on environment
      $env:APIM_SERVICE_NAME = "apim-$(Environment)-001"
      $env:RESOURCE_GROUP_NAME = "rg-apim-$(Environment)"
      
      # Run setup
      .\setup.ps1 -Pipeline -SkipModuleUpdate
    azurePowerShellVersion: 'LatestVersion'
    pwsh: true
```

### Multiple Swagger Files

```yaml
# Import multiple Swagger specifications
- task: AzurePowerShell@5
  displayName: 'Import Multiple APIs'
  inputs:
    azureSubscription: 'apim-service-connection'
    ScriptType: 'InlineScript'
    Inline: |
      $apis = @(
        @{ Name = "Users API"; Url = "https://api.company.com/users/swagger.json"; Path = "users" }
        @{ Name = "Orders API"; Url = "https://api.company.com/orders/swagger.json"; Path = "orders" }
        @{ Name = "Products API"; Url = "https://api.company.com/products/swagger.json"; Path = "products" }
      )
      
      foreach ($api in $apis) {
        Write-Host "Importing $($api.Name)..."
        # Add your import logic here
      }
    azurePowerShellVersion: 'LatestVersion'
    pwsh: true
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **"No Azure context found"** | Ensure using `AzurePowerShell@5` task, not `PowerShell@2` |
| **Permission denied** | Verify service principal has `Contributor` + `API Management Service Contributor` roles |
| **Module installation fails** | Add `-SkipModuleUpdate` parameter on Microsoft-hosted agents |
| **APIM provisioning timeout** | Increase `timeoutInMinutes` to 60+ for APIM tasks |
| **Swagger URL not accessible** | Ensure URL is publicly accessible or use network-accessible alternatives |

### Debug Steps

1. **Verify service connection:**
   ```yaml
   - task: AzurePowerShell@5
     inputs:
       azureSubscription: 'your-service-connection'
       ScriptType: 'InlineScript'
       Inline: |
         $context = Get-AzContext
         Write-Host "Account: $($context.Account.Id)"
         Write-Host "Subscription: $($context.Subscription.Name)"
   ```

2. **Check permissions:**
   ```yaml
   - task: AzurePowerShell@5
     inputs:
       azureSubscription: 'your-service-connection'
       ScriptType: 'InlineScript'
       Inline: |
         # Test resource group access
         Get-AzResourceGroup -Name "your-rg-name"
         
         # Test APIM access
         Get-AzApiManagement -ResourceGroupName "your-rg-name"
   ```

3. **Enable verbose logging:**
   Add to any PowerShell task:
   ```yaml
   ScriptArguments: '-Pipeline -SkipModuleUpdate -Verbose'
   ```

## Support

- **Azure DevOps Issues:** Check service connection and permissions
- **APIM Issues:** Verify Azure subscription quotas and region availability  
- **PowerShell Issues:** Ensure using `AzurePowerShell@5` with `pwsh: true`
- **Large Swagger Files:** This solution specifically handles >4MB files that fail in Terraform

## Next Steps

1. **Test locally** first: Run `.\setup.ps1` on your dev machine
2. **Start simple:** Use Option 1 pipeline template initially
3. **Add complexity:** Move to Option 2 when ready for production
4. **Monitor:** Add Application Insights or Azure Monitor integration
5. **Secure:** Implement proper RBAC and API policies in APIM
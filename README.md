# Terraform + GitHub Actions for Azure VM (Modularized + OIDC + Environment Separation)

**Languages: [English](README.md) | [日本語](README_ja.md)**

This repository provides a modularized configuration using Terraform and GitHub Actions to automatically deploy Azure virtual machines (Ubuntu 22.04 LTS). It supports **separation from staging to production environments**, enabling safe and gradual deployment.

## Configuration
- `providers.tf`: Provider and Backend configuration
- `variables.tf`: Variable definitions
- `main.tf`: Main resource definitions (Resource Group + conditional module calls)
- `outputs.tf`: Output values
- `modules/network/`: Network resource module (for VM)
- `modules/vm/`: Virtual machine module
- `modules/appservice/`: App Service module
- `.github/workflows/plan.yml`: Plan workflow (staging environment)
- `.github/workflows/apply.yml`: Apply workflow (staging environment)
- `.github/workflows/apply-production.yml`: Apply workflow (production environment)
- `.github/workflows/manage-staging.yml`: Staging environment management workflow (start/stop/destroy)

## Environment Separation Architecture

### Supported Environments
- **Staging**: Staging environment (production-equivalent testing)
- **Production**: Production environment (full operation)

### Workflow Configuration
```
PR Creation → Plan (Staging) → Review → Merge → Apply (Staging) → Testing → Production Deployment
```

### Deployment Flow
```
1. Developer → Create feature branch → Code changes
2. PR Creation → Automatically execute Plan in staging environment
3. Review → Approval → Merge
4. Automatically execute Apply in staging environment
5. Testing in staging environment
6. Manual deployment to production environment (with approval process)
```

## Module Configuration
```
modules/
├── network/
│   ├── main.tf      # VNet, Subnet, Public IP, NSG, NIC (for VM)
│   ├── variables.tf # Network module variables
│   └── outputs.tf   # Network module outputs
├── vm/
│   ├── main.tf      # Linux VM
│   ├── variables.tf # VM module variables
│   └── outputs.tf   # VM module outputs
└── appservice/
    ├── main.tf      # App Service Plan & App Service
    ├── variables.tf # App Service module variables
    └── outputs.tf   # App Service module outputs
```

## Prerequisites

### 1. Azure Subscription
- Azure subscription is required

### 2. OIDC Authentication Setup
To use OIDC authentication with GitHub Actions, create an Azure AD application and federation credentials:

```bash
# 1. Create Azure AD application
az ad app create --display-name "github-actions-terraform"

# 2. Create service principal
az ad sp create --id <app-id>

# 3. Create federation credentials
az ad app federated-credential create \
  --id <app-id> \
  --parameters "{\"name\":\"github-actions\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:<your-github-username>/<your-repo-name>:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

# 4. Grant necessary permissions
az role assignment create \
  --assignee <app-id> \
  --role "Contributor" \
  --scope /subscriptions/<subscription-id>
```

### 3. OIDC Authentication Configuration

#### Azure AD App Registration Creation
```bash
# Login with Azure CLI
az login

# Create App Registration
az ad app create --display-name "GitHub Actions Terraform"

# Get application ID
APP_ID=$(az ad app list --display-name "GitHub Actions Terraform" --query "[].appId" -o tsv)
echo "App ID: $APP_ID"

# Create service principal
az ad sp create --id $APP_ID

# Get service principal ID
SP_ID=$(az ad sp list --display-name "GitHub Actions Terraform" --query "[].id" -o tsv)
echo "Service Principal ID: $SP_ID"
```

#### Federation Credentials Configuration
```bash
# Set GitHub Actions OIDC token issuer
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{\"name\":\"github-actions\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

# Grant permissions to resource group
az role assignment create \
  --assignee $SP_ID \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP_NAME"
```

### 4. GitHub Repository Configuration

#### 4.1. Environment Creation
1. Go to GitHub repository `Settings` → `Environments`
2. Create the following environments with `New environment`:
   - `staging`
   - `production`

#### 4.2. Secrets Configuration
Register the following in repository Settings → Secrets and variables → Actions:

**Secrets:**
- `AZURE_CLIENT_ID`: Azure AD application client ID
- `AZURE_TENANT_ID`: Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID
- `SSH_PUBLIC_KEY`: SSH public key to register with VM

#### 4.3. Environment Variables Configuration

**Staging Environment:**
```
TF_VAR_PREFIX: "stg"
AZURE_LOCATION: "japaneast"
RESOURCE_TYPE: "both"
ADMIN_USERNAME: "azureuser"
VM_SIZE: "Standard_B2s"
APP_SERVICE_SKU_TIER: "Standard"
APP_SERVICE_SKU_SIZE: "S1"
```

**Production Environment:**
```
TF_VAR_PREFIX: "prod"
AZURE_LOCATION: "japaneast"
RESOURCE_TYPE: "both"
ADMIN_USERNAME: "azureuser"
VM_SIZE: "Standard_B4ms"
APP_SERVICE_SKU_TIER: "Premium"
APP_SERVICE_SKU_SIZE: "P1v2"
```

### 5. Backend Configuration (Recommended)
When storing remote state in Azure Storage:

**Add to Environment Variables:**
- `BACKEND_RESOURCE_GROUP_NAME`: Backend resource group name
- `BACKEND_STORAGE_ACCOUNT_NAME`: Backend storage account name
- `BACKEND_CONTAINER_NAME`: Backend container name
- `BACKEND_KEY`: State file name (default: terraform.tfstate)

## Benefits of Environment Separation

### 1. **Enhanced Security**
- Access control per environment
- Prevention of direct access to production environment
- Environment-specific credential management

### 2. **Risk Reduction**
- Changes in staging environment don't affect production
- Independent testing per environment
- Gradual deployment

### 3. **Operational Flexibility**
- Resource size optimization per environment
- Environment-specific configuration value management
- Staging and production separation

### 4. **Improved Team Collaboration**
- Responsibility separation per environment
- Safe parallel development
- Clear review process

## Local Usage

### 1. Authentication Configuration
```bash
# Login with Azure CLI
az login

# Or set authentication credentials with environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Initialize
terraform init

# Execute plan
terraform plan -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# Apply
terraform apply -auto-approve -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

### 2. GitHub Actions Automation (OIDC Authentication + Environment Separation)

#### Authentication Method: OpenID Connect (OIDC)
- **Security**: No long-term secrets, authentication with short-term tokens
- **Benefits**: 
  - No secret management required
  - Automatic token renewal
  - Higher security level
- **Configuration**: Azure AD App Registration integration with GitHub Actions

#### Plan Workflow (`plan.yml`)
- **Trigger**: Pull request creation/update
- **Execution Environment**: Staging
- **Execution Content**:
  - Format check (`terraform fmt -check`)
  - Validation (`terraform validate`)
  - Plan execution (`terraform plan`)
  - Post results as PR comments
- **PR Comment Content**:
  - PR number and title
  - Branch information
  - Environment information (Staging)
  - Resource type
  - Results of each check (with emojis)
  - Detailed plan output
  - Next steps explanation

#### Apply Workflow (`apply.yml`)
- **Trigger**: Push to main branch
- **Execution Environment**: Staging
- **Execution Content**:
  - Format check
  - Validation
  - Plan execution
  - Automatic application (`terraform apply`)
- **Security**: State lock functionality prevents simultaneous writes when using backend

#### Production Apply Workflow (`apply-production.yml`)
- **Trigger**: Manual execution (workflow_dispatch)
- **Execution Environment**: Production
- **Execution Content**:
  - Pre-check (approval confirmation)
  - Format check
  - Validation
  - Plan execution
  - Application after manual approval (`terraform apply`)
- **Security**: 
  - Manual approval process required
  - Strict production environment control
  - Final confirmation by approver

### 3. Local Terraform Execution

#### Basic Execution Steps (Local State)
```bash
# Initialize
terraform init

# Execute plan
terraform plan -var="resource_type=vm" -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# Apply
terraform apply -auto-approve -var="resource_type=vm" -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

#### Execution Steps When Using Backend
```bash
# Initialize (with backend configuration)
terraform init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=tfstateaccount123" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=terraform.tfstate"

# Execute plan
terraform plan -var="resource_type=vm" -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# Apply
terraform apply -auto-approve -var="resource_type=vm" -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

## Environment Separation Operational Flow

### 1. **Development Flow**
```
Developer → Create feature branch → Code changes → Create PR
↓
Auto-execution: Plan (Staging)
↓
Review → Approval → Merge
↓
Auto-execution: Apply (Staging)
↓
Testing in staging environment
↓
Manual deployment to production environment (with approval process)
```

### 2. **Environment-Specific Configuration Management**
- **Staging**: Production-equivalent resources, integration testing
- **Production**: Production environment, full operation

### 3. **Security Control**
- **Staging**: Accessible by reviewers and above
- **Production**: Accessible only by administrators, manual approval required

## Production Environment Deployment Method

### Production Deployment After Staging Completion

#### **Step 1: Staging Environment Verification**
1. Deployment completed in staging environment
2. Execute testing in staging environment
3. Confirm all functions work normally

#### **Step 2: Execute Production Deployment**
1. **Navigate to GitHub Actions page**
   - Click `Actions` tab in repository

2. **Select Production Deployment Workflow**
   - Select `Terraform Apply - Production`

3. **Execute Workflow**
   - Click `Run workflow` button

4. **Set Approval Parameters**
   - `Confirm production deployment`: `true`
   - `Staging environment has been verified and tested`: `true`
   - `Reason for production deployment`: Enter deployment reason

5. **Execute Deployment**
   - Click `Run workflow` to execute

#### **Step 3: Approval Process**
1. **Pre-check**
   - Staging environment verification
   - Deployment reason confirmation
   - Approver confirmation

2. **Plan Execution**
   - Change content confirmation in production environment
   - Detailed resource change confirmation

3. **Apply Execution**
   - Actual deployment after approval
   - Change application to production environment

#### **Step 4: Post-Deployment Verification**
1. **Resource Verification**
   - Resource status confirmation in Azure Portal
   - Application operation confirmation

2. **Monitoring and Logs**
   - Application log confirmation
   - Performance metrics monitoring

3. **Documentation Update**
   - Deployment history recording
   - Configuration change recording

### Approval Process Details

#### **Required Check Items**
- [ ] Deployment completed in staging environment
- [ ] Testing successful in staging environment
- [ ] Production deployment approved
- [ ] Deployment reason clear

#### **Security Control**
- **Production Environment Access**: Administrators only
- **Approval Process**: Manual approval required
- **Change Tracking**: Deployment reason recording
- **Audit Logs**: Deployment history retention

## Troubleshooting

### Common Issues and Solutions

#### 1. Environment Variables Not Reflected
- **Cause**: Environment Variables configuration error
- **Solution**: Check environment variables in GitHub repository Settings

#### 2. Permission Error Occurs
- **Cause**: OIDC authentication configuration issue
- **Solution**: Check Azure AD App Registration configuration

#### 3. Workflow Not Executing
- **Cause**: Environment configuration issue
- **Solution**: Check GitHub Environments configuration

#### 4. Cannot Deploy to Production Environment
- **Cause**: Production environment approval process
- **Solution**: Contact production environment approver

#### 5. Production Deployment Fails After Staging Completion
- **Cause**: Approval parameter configuration error
- **Solution**: Set all approval parameters to `true`

## Cost Management Features

### Staging Environment Cost Reduction

#### **Automatic Management Features**
- **Auto-stop**: Automatically stop staging environment at 8 PM on weekdays
- **Auto-start**: Automatically start staging environment at 8 AM on weekdays
- **Manual Control**: Start/stop/destroy manually as needed

#### **Management Options**

##### **1. Stop**
```yaml
Benefits:
- Resources are retained
- Fast restart
- Data is retained

Drawbacks:
- Some costs continue
- Storage costs occur
```

##### **2. Destroy**
```yaml
Benefits:
- Complete cost reduction
- Complete resource removal
- Maximum cost efficiency

Drawbacks:
- Time-consuming recreation
- Data is lost
- Configuration rebuild required
```

#### **Workflow Usage Method**

##### **Staging Environment Management**
1. Open **Actions** tab
2. Select **Manage Staging Environment**
3. Click **Run workflow**
4. Select action:
   - `start`: Start environment
   - `stop`: Stop environment
   - `destroy`: Destroy environment (confirmation required)

##### **Staging Environment Recreation**
After destroying staging environment, recreate using normal deployment workflow:
1. Open **Actions** tab
2. Select **Terraform Apply**
3. Click **Run workflow**
4. Deploy to staging environment

#### **Cost Comparison**
```yaml
# Staging Environment (Low-cost configuration)
VM_SIZE: "Standard_B2s"        # ~$0.05/hour
APP_SERVICE_SKU_TIER: "Standard"  # ~$0.02/hour

# Production Environment (High-cost configuration)
VM_SIZE: "Standard_B4ms"       # ~$0.20/hour
APP_SERVICE_SKU_TIER: "Premium"   # ~$0.10/hour
```

## Future Expansion Plans

- [ ] Environment-specific notification settings
- [ ] Rollback functionality addition
- [ ] Audit log enhancement
- [ ] Automated testing integration
- [ ] Cost monitoring dashboard
- [ ] Auto-scaling functionality

## Reference Links
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Azure Login](https://github.com/marketplace/actions/azure-login)
- [Azure AD OIDC with GitHub Actions](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Terraform App Service Examples](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service)

## Version Information
- **Terraform**: 1.9.0
- **AzureRM Provider**: ~> 4.40.0

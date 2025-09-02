# Azure Storage Backend セットアップガイド

**Languages: [English](backend-setup.md) | [日本語](backend-setup_ja.md)**

## 1. Azure Storage アカウントの作成

### Azure CLI を使用した作成

```bash
# リソースグループを作成（既存のものを使用する場合はスキップ）
az group create --name tfstate-rg --location japaneast

# ストレージアカウントを作成（名前は一意である必要があります）
az storage account create \
  --name tfstateaccount123 \
  --resource-group tfstate-rg \
  --location japaneast \
  --sku Standard_LRS \
  --encryption-services blob

# Blobコンテナを作成
az storage container create \
  --name tfstate \
  --account-name tfstateaccount123

# アクセスキーを取得
az storage account keys list \
  --resource-group tfstate-rg \
  --account-name tfstateaccount123
```

### 手動での作成

1. **Azure Portal**にログイン
2. **ストレージアカウント**を作成
   - リソースグループ: `tfstate-rg`
   - ストレージアカウント名: `tfstateaccount123`（一意の名前に変更）
   - 場所: `japaneast`
   - パフォーマンス: `Standard`
   - 冗長性: `LRS`
3. **Blobコンテナ**を作成
   - 名前: `tfstate`

## 2. バックエンド設定

### 方法1: コマンドラインで設定

```bash
# バックエンド設定で初期化
terraform init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=tfstateaccount123" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=terraform.tfstate"
```

### 方法2: 環境変数で設定

```bash
# 環境変数を設定
export ARM_ACCESS_KEY="your-storage-account-access-key"
export TF_VAR_backend_resource_group_name="tfstate-rg"
export TF_VAR_backend_storage_account_name="tfstateaccount123"
export TF_VAR_backend_container_name="tfstate"
export TF_VAR_backend_key="terraform.tfstate"

# 初期化
terraform init
```

### 方法3: providers.tf に直接記述（非推奨）

```hcl
terraform {
  required_version = ">= 1.9.0"

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateaccount123"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40.0"
    }
  }
}
```

## 3. 認証設定

### Azure CLI 認証（推奨）

```bash
# Azure CLIでログイン
az login

# サブスクリプションを設定
az account set --subscription "your-subscription-id"
```

### サービスプリンシパル認証

```bash
# 環境変数を設定
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
```

## 4. 使用例

### 基本的な実行

```bash
# 初期化（バックエンド設定付き）
terraform init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=tfstateaccount123" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=terraform.tfstate"

# プラン実行
terraform plan -var="resource_type=vm" -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# 適用
terraform apply -auto-approve -var="resource_type=vm" -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

### 複数環境での使用

```bash
# 開発環境
terraform init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=tfstateaccount123" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev/terraform.tfstate"

# 本番環境
terraform init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=tfstateaccount123" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=prod/terraform.tfstate"
```

## 5. セキュリティ考慮事項

### アクセス制御

```bash
# ストレージアカウントのアクセス制御を設定
az storage account update \
  --name tfstateaccount123 \
  --resource-group tfstate-rg \
  --enable-hierarchical-namespace true

# プライベートエンドポイントを設定（オプション）
az network private-endpoint create \
  --name tfstate-pe \
  --resource-group tfstate-rg \
  --vnet-name your-vnet \
  --subnet your-subnet \
  --private-connection-resource-id /subscriptions/your-subscription-id/resourceGroups/tfstate-rg/providers/Microsoft.Storage/storageAccounts/tfstateaccount123 \
  --group-id blob \
  --connection-name tfstate-connection
```

### 暗号化

- ストレージアカウントはデフォルトで暗号化されます
- カスタマーマネージドキーを使用することも可能です

## 6. トラブルシューティング

### よくある問題

1. **アクセス権限エラー**
   ```bash
   # ストレージアカウントのアクセスキーを確認
   az storage account keys list --resource-group tfstate-rg --account-name tfstateaccount123
   ```

2. **コンテナが存在しない**
   ```bash
   # コンテナを作成
   az storage container create --name tfstate --account-name tfstateaccount123
   ```

3. **認証エラー**
   ```bash
   # Azure CLIでログイン
   az login
   az account set --subscription "your-subscription-id"
   ```

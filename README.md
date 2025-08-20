# Terraform + GitHub Actions for Azure VM (モジュール化 + OIDC)

このリポジトリは、Terraform と GitHub Actions を使用して Azure の仮想マシン (Ubuntu 22.04 LTS) を自動デプロイするモジュール化された構成です。

## 構成
- `providers.tf`: Provider と Backend 設定
- `variables.tf`: 変数定義
- `main.tf`: メインリソース定義 (Resource Group + 条件付きモジュール呼び出し)
- `outputs.tf`: 出力値
- `modules/network/`: ネットワークリソースモジュール (VM用)
- `modules/vm/`: 仮想マシンモジュール
- `modules/appservice/`: App Serviceモジュール
- `.github/workflows/plan.yml`: Plan ワークフロー (PR トリガー)
- `.github/workflows/apply.yml`: Apply ワークフロー (main ブランチ トリガー)

## モジュール構成
```
modules/
├── network/
│   ├── main.tf      # VNet, Subnet, Public IP, NSG, NIC (VM用)
│   ├── variables.tf # ネットワークモジュール変数
│   └── outputs.tf   # ネットワークモジュール出力
├── vm/
│   ├── main.tf      # Linux VM
│   ├── variables.tf # VMモジュール変数
│   └── outputs.tf   # VMモジュール出力
└── appservice/
    ├── main.tf      # App Service Plan & App Service
    ├── variables.tf # App Serviceモジュール変数
    └── outputs.tf   # App Serviceモジュール出力
```

## 事前準備

### 1. Azure サブスクリプション
- Azure サブスクリプションが必要です

### 2. OIDC認証の設定
GitHub ActionsでOIDC認証を使用するため、Azure ADアプリケーションとフェデレーション認証情報を作成します：

```bash
# 1. Azure ADアプリケーションを作成
az ad app create --display-name "github-actions-terraform"

# 2. サービスプリンシパルを作成
az ad sp create --id <app-id>

# 3. フェデレーション認証情報を作成
az ad app federated-credential create \
  --id <app-id> \
  --parameters "{\"name\":\"github-actions\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:<your-github-username>/<your-repo-name>:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

# 4. 必要な権限を付与
az role assignment create \
  --assignee <app-id> \
  --role "Contributor" \
  --scope /subscriptions/<subscription-id>
```

### 3. OIDC認証設定

#### Azure AD App Registration の作成
```bash
# Azure CLIでログイン
az login

# App Registration を作成
az ad app create --display-name "GitHub Actions Terraform"

# アプリケーションIDを取得
APP_ID=$(az ad app list --display-name "GitHub Actions Terraform" --query "[].appId" -o tsv)
echo "App ID: $APP_ID"

# サービスプリンシパルを作成
az ad sp create --id $APP_ID

# サービスプリンシパルIDを取得
SP_ID=$(az ad sp list --display-name "GitHub Actions Terraform" --query "[].id" -o tsv)
echo "Service Principal ID: $SP_ID"
```

#### フェデレーション認証情報の設定
```bash
# GitHub Actions の OIDC トークン発行者を設定
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{\"name\":\"github-actions\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

# リソースグループへの権限を付与
az role assignment create \
  --assignee $SP_ID \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP_NAME"
```

### 4. GitHub リポジトリ設定
リポジトリの Settings → Secrets and variables → Actions に以下を登録：

**Secrets:**
- `AZURE_CLIENT_ID`: Azure ADアプリケーションのクライアントID
- `AZURE_TENANT_ID`: Azure ADテナントID
- `AZURE_SUBSCRIPTION_ID`: Azure サブスクリプションID
- `SSH_PUBLIC_KEY`: VMに登録するSSH公開鍵

**Variables (任意):**
- `RESOURCE_TYPE`: デプロイするリソースタイプ (vm, appservice, both) (デフォルト: vm)
- `AZURE_LOCATION`: Azureリージョン (デフォルト: japaneast)
- `ADMIN_USERNAME`: VM管理者ユーザー名 (デフォルト: azureuser)
- `VM_SIZE`: VMサイズ (デフォルト: Standard_B2s)
- `TF_VAR_PREFIX`: リソース名プレフィックス (デフォルト: tfvm)
- `APP_SERVICE_SKU_TIER`: App Service Plan SKU tier (デフォルト: Standard)
- `APP_SERVICE_SKU_SIZE`: App Service Plan SKU size (デフォルト: S1)
- `APP_SERVICE_LINUX_FX_VERSION`: App Service Linux FX version (デフォルト: DOCKER|nginx:latest)

### 5. Backend設定 (推奨)
リモートステートを Azure Storage に保存する場合：

**Variables に追加:**
- `BACKEND_RESOURCE_GROUP_NAME`: バックエンド用リソースグループ名
- `BACKEND_STORAGE_ACCOUNT_NAME`: バックエンド用ストレージアカウント名
- `BACKEND_CONTAINER_NAME`: バックエンド用コンテナ名
- `BACKEND_KEY`: ステートファイル名 (デフォルト: terraform.tfstate)

## ローカルでの使い方

### 1. 認証設定
```bash
# Azure CLIでログイン
az login

# または、環境変数で認証情報を設定
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# 初期化
terraform init

# プラン実行
terraform plan -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# 適用
terraform apply -auto-approve -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

### 2. GitHub Actions での自動化 (OIDC認証)

#### 認証方式: OpenID Connect (OIDC)
- **セキュリティ**: 長期間有効なシークレットを使用せず、短時間のトークンで認証
- **利点**: 
  - シークレット管理が不要
  - 自動的なトークン更新
  - より高いセキュリティレベル
- **設定**: Azure AD App Registration と GitHub Actions の連携

#### Plan ワークフロー (`plan.yml`)
- **トリガー**: プルリクエスト作成/更新時
- **実行内容**:
  - フォーマットチェック (`terraform fmt -check`)
  - バリデーション (`terraform validate`)
  - プラン実行 (`terraform plan`)
  - 結果をPRにコメント投稿
- **PRコメント内容**:
  - PR番号とタイトル
  - ブランチ情報
  - リソースタイプ
  - 各チェックの結果（絵文字付き）
  - プランの詳細出力
  - 次のステップの説明

#### Apply ワークフロー (`apply.yml`)
- **トリガー**: mainブランチへのプッシュ時
- **実行内容**:
  - フォーマットチェック
  - バリデーション
  - プラン実行
  - 自動適用 (`terraform apply`)
- **セキュリティ**: バックエンド使用時はステートロック機能で同時書き込みを防止

### 3. ローカルでのTerraform実行

#### 基本的な実行手順（ローカルステート）
```bash
# 初期化
terraform init

# プラン実行
terraform plan -var="resource_type=vm" -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

# 適用
terraform apply -auto-approve -var="resource_type=vm" -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

#### バックエンド使用時の実行手順
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

**詳細なバックエンド設定手順は `backend-setup.md` を参照してください。**

### 4. プルリクエストの作成方法

#### 基本的な手順
```bash
# 1. 新しいブランチを作成
git checkout -b feature/add-app-service

# 2. 変更をコミット
git add .
git commit -m "Add App Service module and configuration"

# 3. ブランチをプッシュ
git push origin feature/add-app-service

# 4. GitHubでプルリクエストを作成
# - ベースブランチ: main
# - 比較ブランチ: feature/add-app-service
```

#### プルリクエストのテンプレート
```markdown
## 変更内容
- [ ] VMの設定変更
- [ ] App Serviceの追加
- [ ] ネットワーク設定の変更
- [ ] その他

## リソースタイプ
- [ ] VM
- [ ] App Service  
- [ ] 両方

## テスト項目
- [ ] ローカルでterraform plan実行済み
- [ ] フォーマットチェック通過
- [ ] バリデーション通過

## 関連Issue
Closes #XXX
```

### 5. リソースタイプの選択

#### VM のみをデプロイ
```bash
# ローカル実行
terraform apply -var="resource_type=vm"

# GitHub Variables
RESOURCE_TYPE=vm
```

#### App Service のみをデプロイ
```bash
# ローカル実行
terraform apply -var="resource_type=appservice"

# GitHub Variables
RESOURCE_TYPE=appservice
```

#### VM と App Service の両方をデプロイ
```bash
# ローカル実行
terraform apply -var="resource_type=both"

# GitHub Variables
RESOURCE_TYPE=both
```



## バージョニング管理

### 1. Terraformバージョン
- `providers.tf`でTerraformとAzureRMプロバイダーのバージョンを固定
- GitHub ActionsでTerraform 1.9.0を使用

### 2. モジュールバージョン管理
各モジュールにバージョンタグを付けて管理：
```bash
git tag -a v1.0.0 -m "Initial release"
git push origin v1.0.0
```

### 3. 同時書き込み防止
- バックエンド使用時は自動的にステートロック機能が有効
- GitHub Actionsで`-lock-timeout=5m`を設定

## セキュリティ考慮事項

### 1. OIDC認証
- サービスプリンシパルのシークレットを保存する必要がない
- トークンベースの認証でより安全

### 2. 最小権限の原則
- 必要最小限の権限のみを付与
- リソースグループレベルでの権限付与を推奨

### 3. ネットワークセキュリティ
- SSHポート(22)のみを開放
- 必要に応じてソースIPアドレスを制限

## トラブルシューティング

### 1. OIDC認証エラー
```bash
# フェデレーション認証情報の確認
az ad app federated-credential list --id <app-id>

# 権限の確認
az role assignment list --assignee <app-id>
```

### 2. バックエンドエラー
```bash
# ストレージアカウントの確認
az storage account show --name <storage-account-name> --resource-group <resource-group-name>

# コンテナの確認
az storage container list --account-name <storage-account-name>
```

## 参考リンク
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Azure Login](https://github.com/marketplace/actions/azure-login)
- [Azure AD OIDC with GitHub Actions](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Terraform App Service Examples](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service)



## バージョン情報
- **Terraform**: 1.9.0
- **AzureRM Provider**: ~> 4.40.0

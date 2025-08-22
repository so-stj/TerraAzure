# Terraform + GitHub Actions for Azure VM (モジュール化 + OIDC + 環境分離)

このリポジトリは、Terraform と GitHub Actions を使用して Azure の仮想マシン (Ubuntu 22.04 LTS) を自動デプロイするモジュール化された構成です。**ステージングから本番環境への分離**に対応しており、安全で段階的なデプロイメントを実現します。

## 構成
- `providers.tf`: Provider と Backend 設定
- `variables.tf`: 変数定義
- `main.tf`: メインリソース定義 (Resource Group + 条件付きモジュール呼び出し)
- `outputs.tf`: 出力値
- `modules/network/`: ネットワークリソースモジュール (VM用)
- `modules/vm/`: 仮想マシンモジュール
- `modules/appservice/`: App Serviceモジュール
- `.github/workflows/plan.yml`: Plan ワークフロー (ステージング環境)
- `.github/workflows/apply.yml`: Apply ワークフロー (ステージング環境)
- `.github/workflows/apply-production.yml`: Apply ワークフロー (本番環境)
- `.github/workflows/manage-staging.yml`: ステージング環境管理ワークフロー (開始/停止/削除)

## 環境分離アーキテクチャ

### 対応環境
- **Staging**: ステージング環境（本番相当のテスト）
- **Production**: 本番環境（本格運用）

### ワークフロー構成
```
PR作成 → Plan (Staging) → レビュー → マージ → Apply (Staging) → テスト → 本番デプロイ
```

### デプロイメントフロー
```
1. 開発者 → フィーチャーブランチ作成 → コード変更
2. PR作成 → 自動的にステージング環境でPlan実行
3. レビュー → 承認 → マージ
4. 自動的にステージング環境でApply実行
5. ステージング環境でテスト
6. 本番環境への手動デプロイ（承認プロセス付き）
```

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

#### 4.1. 環境の作成
1. GitHubリポジトリの `Settings` → `Environments` に移動
2. `New environment` で以下の環境を作成：
   - `staging`
   - `production`

#### 4.2. Secrets設定
リポジトリの Settings → Secrets and variables → Actions に以下を登録：

**Secrets:**
- `AZURE_CLIENT_ID`: Azure ADアプリケーションのクライアントID
- `AZURE_TENANT_ID`: Azure ADテナントID
- `AZURE_SUBSCRIPTION_ID`: Azure サブスクリプションID
- `SSH_PUBLIC_KEY`: VMに登録するSSH公開鍵

#### 4.3. Environment Variables設定

**Staging環境:**
```
TF_VAR_PREFIX: "stg"
AZURE_LOCATION: "japaneast"
RESOURCE_TYPE: "both"
ADMIN_USERNAME: "azureuser"
VM_SIZE: "Standard_B2s"
APP_SERVICE_SKU_TIER: "Standard"
APP_SERVICE_SKU_SIZE: "S1"
```

**Production環境:**
```
TF_VAR_PREFIX: "prod"
AZURE_LOCATION: "japaneast"
RESOURCE_TYPE: "both"
ADMIN_USERNAME: "azureuser"
VM_SIZE: "Standard_B4ms"
APP_SERVICE_SKU_TIER: "Premium"
APP_SERVICE_SKU_SIZE: "P1v2"
```

### 5. Backend設定 (推奨)
リモートステートを Azure Storage に保存する場合：

**Environment Variables に追加:**
- `BACKEND_RESOURCE_GROUP_NAME`: バックエンド用リソースグループ名
- `BACKEND_STORAGE_ACCOUNT_NAME`: バックエンド用ストレージアカウント名
- `BACKEND_CONTAINER_NAME`: バックエンド用コンテナ名
- `BACKEND_KEY`: ステートファイル名 (デフォルト: terraform.tfstate)

## 環境分離の利点

### 1. **セキュリティ向上**
- 環境ごとのアクセス制御
- 本番環境への直接アクセス防止
- 環境固有の認証情報管理

### 2. **リスク軽減**
- ステージング環境での変更が本番に影響しない
- 環境ごとの独立したテスト
- 段階的なデプロイメント

### 3. **運用の柔軟性**
- 環境ごとに最適化されたリソースサイズ
- 環境固有の設定値管理
- ステージング・本番の分離

### 4. **チーム協働の改善**
- 環境ごとの責任分離
- 並行開発の安全性確保
- レビュープロセスの明確化

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

### 2. GitHub Actions での自動化 (OIDC認証 + 環境分離)

#### 認証方式: OpenID Connect (OIDC)
- **セキュリティ**: 長期間有効なシークレットを使用せず、短時間のトークンで認証
- **利点**: 
  - シークレット管理が不要
  - 自動的なトークン更新
  - より高いセキュリティレベル
- **設定**: Azure AD App Registration と GitHub Actions の連携

#### Plan ワークフロー (`plan.yml`)
- **トリガー**: プルリクエスト作成/更新時
- **実行環境**: Staging
- **実行内容**:
  - フォーマットチェック (`terraform fmt -check`)
  - バリデーション (`terraform validate`)
  - プラン実行 (`terraform plan`)
  - 結果をPRにコメント投稿
- **PRコメント内容**:
  - PR番号とタイトル
  - ブランチ情報
  - 環境情報（Staging）
  - リソースタイプ
  - 各チェックの結果（絵文字付き）
  - プランの詳細出力
  - 次のステップの説明

#### Apply ワークフロー (`apply.yml`)
- **トリガー**: mainブランチへのプッシュ時
- **実行環境**: Staging
- **実行内容**:
  - フォーマットチェック
  - バリデーション
  - プラン実行
  - 自動適用 (`terraform apply`)
- **セキュリティ**: バックエンド使用時はステートロック機能で同時書き込みを防止

#### Production Apply ワークフロー (`apply-production.yml`)
- **トリガー**: 手動実行（workflow_dispatch）
- **実行環境**: Production
- **実行内容**:
  - 事前チェック（承認確認）
  - フォーマットチェック
  - バリデーション
  - プラン実行
  - 手動承認後の適用 (`terraform apply`)
- **セキュリティ**: 
  - 手動承認プロセス必須
  - 本番環境の厳格な制御
  - 承認者による最終確認

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

## 環境分離の運用フロー

### 1. **開発フロー**
```
開発者 → フィーチャーブランチ作成 → コード変更 → PR作成
↓
自動実行: Plan (Staging)
↓
レビュー → 承認 → マージ
↓
自動実行: Apply (Staging)
↓
ステージング環境でテスト
↓
本番環境への手動デプロイ（承認プロセス付き）
```

### 2. **環境別の設定管理**
- **Staging**: 本番相当のリソース、統合テスト
- **Production**: 本番環境、本格運用

### 3. **セキュリティ制御**
- **Staging**: レビュアー以上アクセス可能
- **Production**: 管理者のみアクセス可能、手動承認必須

## 本番環境へのデプロイ方法

### ステージング完了後の本番デプロイ

#### **Step 1: ステージング環境の確認**
1. ステージング環境でデプロイが完了
2. ステージング環境でテストを実行
3. すべての機能が正常に動作することを確認

#### **Step 2: 本番環境へのデプロイ実行**
1. **GitHub Actionsページに移動**
   - リポジトリの `Actions` タブをクリック

2. **本番デプロイワークフローを選択**
   - `Terraform Apply - Production` を選択

3. **ワークフローを実行**
   - `Run workflow` ボタンをクリック

4. **承認パラメータを設定**
   - `Confirm production deployment`: `true`
   - `Staging environment has been verified and tested`: `true`
   - `Reason for production deployment`: デプロイ理由を入力

5. **デプロイ実行**
   - `Run workflow` をクリックして実行

#### **Step 3: 承認プロセス**
1. **事前チェック**
   - ステージング環境の確認
   - デプロイ理由の確認
   - 承認者の確認

2. **Plan実行**
   - 本番環境での変更内容確認
   - リソース変更の詳細確認

3. **Apply実行**
   - 承認後の実際のデプロイ
   - 本番環境への変更適用

#### **Step 4: デプロイ後の確認**
1. **リソースの確認**
   - Azure Portalでリソースの状態確認
   - アプリケーションの動作確認

2. **監視とログ**
   - アプリケーションログの確認
   - パフォーマンスメトリクスの監視

3. **ドキュメント更新**
   - デプロイ履歴の記録
   - 設定変更の記録

### 承認プロセスの詳細

#### **必須チェック項目**
- [ ] ステージング環境でデプロイが完了
- [ ] ステージング環境でテストが成功
- [ ] 本番デプロイが承認されている
- [ ] デプロイ理由が明確

#### **セキュリティ制御**
- **本番環境へのアクセス**: 管理者のみ
- **承認プロセス**: 手動承認必須
- **変更追跡**: デプロイ理由の記録
- **監査ログ**: デプロイ履歴の保持

## トラブルシューティング

### よくある問題と解決方法

#### 1. 環境変数が反映されない
- **原因**: Environment Variablesの設定ミス
- **解決**: GitHubリポジトリのSettingsで環境変数を確認

#### 2. 権限エラーが発生する
- **原因**: OIDC認証の設定不備
- **解決**: Azure AD App Registrationの設定を確認

#### 3. ワークフローが実行されない
- **原因**: 環境の設定不備
- **解決**: GitHub Environmentsの設定を確認

#### 4. 本番環境へのデプロイができない
- **原因**: 本番環境の承認プロセス
- **解決**: 本番環境の承認者に連絡

#### 5. ステージング完了後の本番デプロイが失敗する
- **原因**: 承認パラメータの設定ミス
- **解決**: すべての承認パラメータを `true` に設定

## コスト管理機能

### ステージング環境のコスト削減

#### **自動管理機能**
- **自動停止**: 平日夜8時にステージング環境を自動停止
- **自動開始**: 平日朝8時にステージング環境を自動開始
- **手動制御**: 必要に応じて手動で開始・停止・削除

#### **管理オプション**

##### **1. 停止 (Stop)**
```yaml
利点:
- リソースは保持される
- 再開が高速
- データは保持される

欠点:
- 一部のコストは継続
- ストレージコストは発生
```

##### **2. 削除 (Destroy)**
```yaml
利点:
- 完全なコスト削減
- リソースの完全削除
- 最大のコスト効率

欠点:
- 再作成に時間がかかる
- データは失われる
- 設定の再構築が必要
```

#### **ワークフロー使用方法**

##### **ステージング環境管理**
1. **Actions** タブを開く
2. **Manage Staging Environment** を選択
3. **Run workflow** をクリック
4. アクションを選択:
   - `start`: 環境を開始
   - `stop`: 環境を停止
   - `destroy`: 環境を削除（確認必須）

##### **ステージング環境再作成**
ステージング環境を削除した後は、通常のデプロイワークフローを使用して再作成できます：
1. **Actions** タブを開く
2. **Terraform Apply** を選択
3. **Run workflow** をクリック
4. ステージング環境にデプロイされます

#### **コスト比較**
```yaml
# ステージング環境（低コスト設定）
VM_SIZE: "Standard_B2s"        # 約$0.05/時間
APP_SERVICE_SKU_TIER: "Standard"  # 約$0.02/時間

# 本番環境（高コスト設定）
VM_SIZE: "Standard_B4ms"       # 約$0.20/時間
APP_SERVICE_SKU_TIER: "Premium"   # 約$0.10/時間
```

## 今後の拡張予定

- [ ] 環境別の通知設定
- [ ] ロールバック機能の追加
- [ ] 監査ログの強化
- [ ] 自動テストの統合
- [ ] コスト監視ダッシュボード
- [ ] 自動スケーリング機能

## 参考リンク
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Azure Login](https://github.com/marketplace/actions/azure-login)
- [Azure AD OIDC with GitHub Actions](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Terraform App Service Examples](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service)



## バージョン情報
- **Terraform**: 1.9.0
- **AzureRM Provider**: ~> 4.40.0

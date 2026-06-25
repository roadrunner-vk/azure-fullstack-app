# Azure Fullstack App

A cloud-native Todo application: **Vue.js** frontend, **FastAPI** backend, **Cosmos DB** database — deployed to **Azure Container Apps** with **Terraform** and **GitHub Actions**.

## Architecture

```
Browser → Frontend (Nginx + Vue SPA) → Backend (FastAPI) → Cosmos DB (MongoDB API)
```

- Frontend container: public ingress, serves static files, proxies `/api/*` to backend
- Backend container: internal-only ingress, handles CRUD operations
- Cosmos DB: serverless managed database (not containerized)

## Local Development

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

### Run locally
```bash
docker compose up --build
```
Open http://localhost:3000

## Deploy to Azure

### Step 1 — Install CLI tools

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [GitHub CLI](https://cli.github.com/) (optional)

### Step 2 — Create the GitHub repo

```bash
gh repo create roadrunner-vk/azure-fullstack-app --public --source=. --push
```

Or create it manually at https://github.com/new and push:
```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/roadrunner-vk/azure-fullstack-app.git
git branch -M main
git push -u origin main
```

### Step 3 — Create an Azure Service Principal

```bash
az login
az ad app create --display-name "github-azure-fullstack-app"
```

Note the `appId` from the output, then:

```bash
# Create a service principal
az ad sp create --id <APP_ID>

# Assign Contributor role to your subscription
az role assignment create \
  --assignee <APP_ID> \
  --role Contributor \
  --scope /subscriptions/85a62b12-aed4-43e5-8e2d-ae71fe2f3684

# Create a federated credential for GitHub Actions (OIDC — no secrets to rotate)
az ad app federated-credential create --id <APP_ID> --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:roadrunner-vk/azure-fullstack-app:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Also allow PR workflows
az ad app federated-credential create --id <APP_ID> --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:roadrunner-vk/azure-fullstack-app:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

### Step 4 — Add GitHub Secrets

Go to **GitHub repo → Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | The `appId` from Step 3 |
| `AZURE_TENANT_ID` | Your Azure AD tenant ID (`az account show --query tenantId -o tsv`) |
| `AZURE_SUBSCRIPTION_ID` | `85a62b12-aed4-43e5-8e2d-ae71fe2f3684` |

### Step 5 — Deploy infrastructure (first time, run locally)

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed

az login
terraform init
terraform plan
terraform apply
```

Note the `frontend_url` from the output — that's your live app URL.

### Step 6 — Build and push container images (first time)

```bash
# Get the ACR name from terraform output
ACR_NAME=$(terraform output -raw acr_name)

az acr login --name $ACR_NAME

# Build and push backend
docker build -t $ACR_NAME.azurecr.io/backend:initial ../backend
docker push $ACR_NAME.azurecr.io/backend:initial

# Build and push frontend
docker build -t $ACR_NAME.azurecr.io/frontend:initial ../frontend
docker push $ACR_NAME.azurecr.io/frontend:initial

# Update container apps with real images
az containerapp update --name ca-backend --resource-group rg-azure-fullstack-app \
  --image $ACR_NAME.azurecr.io/backend:initial

az containerapp update --name ca-frontend --resource-group rg-azure-fullstack-app \
  --image $ACR_NAME.azurecr.io/frontend:initial
```

### Step 7 — Open your app

```bash
terraform output frontend_url
```

Visit the URL in your browser. Done!

From now on, every push to `main` will automatically build and deploy via GitHub Actions.

## Project Structure

```
azure-fullstack-app/
├── backend/              # FastAPI application
│   ├── app/
│   │   ├── main.py       # App entry point
│   │   ├── models.py     # Pydantic schemas
│   │   ├── database.py   # MongoDB connection
│   │   ├── config.py     # Environment config
│   │   └── routes/
│   │       └── todos.py  # CRUD endpoints
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/             # Vue 3 + Vite
│   ├── src/
│   │   ├── components/
│   │   │   └── TodoApp.vue
│   │   ├── App.vue
│   │   └── main.js
│   ├── Dockerfile
│   ├── nginx.conf
│   └── package.json
├── infra/                # Terraform
│   ├── main.tf
│   ├── variables.tf
│   ├── providers.tf
│   └── outputs.tf
├── .github/workflows/    # CI/CD
│   ├── ci.yml            # PR checks
│   ├── deploy.yml        # Build & deploy on merge
│   └── infra.yml         # Terraform plan/apply
└── docker-compose.yml    # Local development
```

## Estimated Azure Costs

| Resource | Tier | ~Cost/month |
|----------|------|-------------|
| Container Apps | Consumption (scale to 0) | Free tier: 2M requests |
| Container Registry | Basic | ~$5 |
| Cosmos DB | Serverless | Pay per request (~$0 for learning) |
| Log Analytics | Pay-as-you-go | ~$0 for low volume |

**Total for light usage: ~$5/month**

## Tear Down

To avoid charges when done:
```bash
cd infra
terraform destroy
```

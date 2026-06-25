locals {
  # Sanitise name for resources that don't allow hyphens
  safe_name = replace(var.project_name, "-", "")
}

# ──────────────────────────────────────────────
# Resource Group
# ──────────────────────────────────────────────
resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project_name}"
  location = var.location
}

# ──────────────────────────────────────────────
# Log Analytics (required by Container Apps)
# ──────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.project_name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# ──────────────────────────────────────────────
# Container Apps Environment
# ──────────────────────────────────────────────
resource "azurerm_container_app_environment" "this" {
  name                       = "cae-${var.project_name}"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
}

# ──────────────────────────────────────────────
# Cosmos DB (MongoDB API, Serverless)
# ──────────────────────────────────────────────
resource "azurerm_cosmosdb_account" "this" {
  name                = "cosmos-${var.project_name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  offer_type          = "Standard"
  kind                = "MongoDB"

  capabilities {
    name = "EnableServerless"
  }

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.this.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_mongo_database" "this" {
  name                = "todoapp"
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
}

# ──────────────────────────────────────────────
# Container App — Backend (internal only)
# ──────────────────────────────────────────────
resource "azurerm_container_app" "backend" {
  name                         = "ca-backend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  secret {
    name  = "mongodb-url"
    value = azurerm_cosmosdb_account.this.primary_mongodb_connection_string
  }

  secret {
    name  = "openai-key"
    value = azurerm_cognitive_account.openai.primary_access_key
  }

  ingress {
    allow_insecure_connections = true
    external_enabled           = false
    target_port                = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "backend"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "MONGODB_URL"
        secret_name = "mongodb-url"
      }

      env {
        name  = "MONGODB_DB_NAME"
        value = "todoapp"
      }

      env {
        name        = "AZURE_OPENAI_KEY"
        secret_name = "openai-key"
      }

      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = azurerm_cognitive_account.openai.endpoint
      }

      env {
        name  = "AZURE_OPENAI_DEPLOYMENT"
        value = "gpt-4o-mini"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image
    ]
  }
}

# ──────────────────────────────────────────────
# Container App — Frontend (public)
# ──────────────────────────────────────────────

# ──────────────────────────────────────────────
# Azure OpenAI
# ──────────────────────────────────────────────
resource "azurerm_cognitive_account" "openai" {
  name                  = "oai-${var.project_name}"
  resource_group_name   = azurerm_resource_group.this.name
  location              = "swedencentral"
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "oai-${local.safe_name}"
}

resource "azurerm_cognitive_deployment" "gpt4o_mini" {
  name                 = "gpt-4o-mini"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

# ──────────────────────────────────────────────
# Container App — Frontend (public)
# ──────────────────────────────────────────────
resource "azurerm_container_app" "frontend" {
  name                         = "ca-frontend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "frontend"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "BACKEND_URL"
        value = "ca-backend"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      template[0].container[0].env
    ]
  }
}

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
# Container Registry
# ──────────────────────────────────────────────
resource "azurerm_container_registry" "this" {
  name                = "acr${local.safe_name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = true
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
    name  = "acr-password"
    value = azurerm_container_registry.this.admin_password
  }

  secret {
    name  = "mongodb-url"
    value = azurerm_cosmosdb_account.this.connection_strings[0]
  }

  registry {
    server               = azurerm_container_registry.this.login_server
    username             = azurerm_container_registry.this.admin_username
    password_secret_name = "acr-password"
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
resource "azurerm_container_app" "frontend" {
  name                         = "ca-frontend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.this.admin_password
  }

  registry {
    server               = azurerm_container_registry.this.login_server
    username             = azurerm_container_registry.this.admin_username
    password_secret_name = "acr-password"
  }

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
        value = azurerm_container_app.backend.ingress[0].fqdn
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image
    ]
  }
}

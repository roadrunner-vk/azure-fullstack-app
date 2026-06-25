output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "acr_login_server" {
  value = azurerm_container_registry.this.login_server
}

output "acr_name" {
  value = azurerm_container_registry.this.name
}

output "frontend_url" {
  value = "https://${azurerm_container_app.frontend.ingress[0].fqdn}"
}

output "backend_internal_fqdn" {
  value = azurerm_container_app.backend.ingress[0].fqdn
}

output "cosmosdb_connection_string" {
  value     = azurerm_cosmosdb_account.this.connection_strings[0]
  sensitive = true
}

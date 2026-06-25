output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "frontend_url" {
  value = "https://${azurerm_container_app.frontend.ingress[0].fqdn}"
}

output "backend_internal_fqdn" {
  value = azurerm_container_app.backend.ingress[0].fqdn
}

output "cosmosdb_connection_string" {
  value     = azurerm_cosmosdb_account.this.primary_mongodb_connection_string
  sensitive = true
}

output "openai_endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

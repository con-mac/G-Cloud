output "application_insights_id" {
  value = azurerm_application_insights.this.id
}

output "application_insights_instrumentation_key" {
  value = azurerm_application_insights.this.instrumentation_key
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}


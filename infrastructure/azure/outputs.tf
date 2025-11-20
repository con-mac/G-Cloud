output "resource_group_name" {
  value = module.resource_group.name
}

output "storage_account_name" {
  value = module.primary_storage.name
}

output "function_app_api_name" {
  value = module.api_function.name
}

output "function_app_pdf_name" {
  value = module.pdf_function.name
}

output "static_site_name" {
  value = module.static_site.name
}


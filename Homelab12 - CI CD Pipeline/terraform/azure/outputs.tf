output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_address" {
  value = azurerm_linux_virtual_machine.my_terraform_vm.public_ip_address
}

output "app_url" {
    value = "http://${azurerm_public_ip.my_terraform_public_ip.ip_address}:5000"
    description = "URL to access the Flask application"
}

output "ssh_command" {
    value = "ssh -i path/to/key ${var.username}@${azurerm_public_ip.my_terraform_public_ip.ip_address}"
    description = "SSH command to connect to VM"
}
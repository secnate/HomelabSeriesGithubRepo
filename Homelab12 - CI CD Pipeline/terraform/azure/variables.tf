variable "resource_group_location" {
  type        = string
  default     = "eastus2"
  description = "Location of the resource group."
}

variable "environment_name" {
  type        = string
  default     = "dev"
  description = "The name of the environment that this VM is to be deployed in"
}

variable "virtual_machine_size" {
  type        = string
  default     = "Standard_DS1_v2"
  description = "The size of the VM that is to be deployed"
}

variable "username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "azureadmin"
}

variable "source_image_reference" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })

  description = "The configuration information regarding the base OS image to be spun up in Azure"

  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "storage_account_name" {
  type        = string
  description = "The name of the storage account to be used for boot diagnostics"
  default     = "nathanstorageaccountdiag-${random_pet.server.id}"
}

variable "public_ssh_key_path" {
    description = "Public SSH key path"
    type = string
    default = "../../keys/azure-key.pub"
}
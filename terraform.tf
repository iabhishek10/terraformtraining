terraform {
    backend "azurerm"{
    resource_group_name = "remote-state"
    storage_account_name = "terraformtraining10"
    container_name = "tfstate"
    key = "web.terraform.tfstate"
    }
}

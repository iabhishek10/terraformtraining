data "azurerm_key_vault" "key_vault" {
    name = "learntf-vault-10"
    resource_group_name = "remote-state"
}

data "azurerm_key_vault_secret" "admin_password"{
    name = "webserver"
    key_vault_id = data.azurerm_key_vault.key_vault.id
}
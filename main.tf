provider "azurerm"{
    version = "=2.20.0"
    features{}
}

locals{
    web_server_name = var.environment == "production" ? "${var.web_server_name}-prd" : "${var.web_server_name}-dev"
    build_environment = var.environment == "production" ? "production" : "development"
}

resource "azurerm_resource_group" "web_server_rg" {
    name = var.web_server_rg
    location = var.web_server_location
        tags = {
        environment = local.build_environment
        build-version = var.terraform_script_version
    }
}

resource "azurerm_storage_account" "storage_account" {
    name = "tfbootdiagnostics"
    location = var.web_server_location
    resource_group_name = azurerm_resource_group.web_server_rg.name
    account_tier = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_virtual_network" "web_server_vnet" {
    name = "${var.resource_prefix}-vnet"
    location = var.web_server_location
    resource_group_name = azurerm_resource_group.web_server_rg.name
    #Passing space as a list so can use list
    address_space = [var.web_server_address_space]
}

/*resource "azurerm_subnet" "web_server_subnet" {
    name = "${var.resource_prefix}-subnet"
    resource_group_name = azurerm_resource_group.web_server_rg.name
    virtual_network_name = azurerm_virtual_network.web_server_vnet.name
    address_prefix = var.web_server_address_prefix
} */

resource "azurerm_subnet" "web_server_subnet" {
    for_each = var.web_server_subnet
    name = each.key
    resource_group_name = azurerm_resource_group.web_server_rg.name
    virtual_network_name = azurerm_virtual_network.web_server_vnet.name
    address_prefix = each.value
}

/*resource "azurerm_network_interface" "web_server_nic"{
    name = "${var.web_server_name}-${format("%02d", count.index)}-nic" 
    location = var.web_server_location
    resource_group_name = azurerm_resource_group.web_server_rg.name
    count = var.web_server_count
    ip_configuration {
        name = "${var.web_server_name}-ip"
        subnet_id = azurerm_subnet.web_server_subnet["web-server"].id
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = count.index <= 1 ? azurerm_public_ip.web_server_ip[count.index].id : null
    }

}*/

resource "azurerm_public_ip" "web_server_lb_public_ip"{
    name = "${var.resource_prefix}-public"
    location = var.web_server_location
    resource_group_name = azurerm_resource_group.web_server_rg.name
    allocation_method = var.environment == "production" ? "Static" : "Dynamic"
}

## NSG 
resource "azurerm_network_security_group" "web_server_nsg"{
    name = "${var.resource_prefix}-nsg"
    location = var.web_server_location
    resource_group_name = azurerm_resource_group.web_server_rg.name    
}

resource "azurerm_network_security_rule" "web_server_nsg_rule_http"{
    name = "RDP Inbound"
    priority = 110
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    resource_group_name = azurerm_resource_group.web_server_rg.name
    network_security_group_name = azurerm_network_security_group.web_server_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "web_server_sag"{
    network_security_group_id = azurerm_network_security_group.web_server_nsg.id
    subnet_id = azurerm_subnet.web_server_subnet["web-server"].id
}

resource "azurerm_virtual_machine_scale_set" "web_server_vm" {
    name = "${var.resource_prefix}-scale-set"
    location = var.web_server_location
    resource_group_name = azurerm_resource_group.web_server_rg.name 
    #network_interface_ids = [azurerm_network_interface.web_server_nic[count.index].id]
    
    upgrade_policy_mode = "manual"

    sku {
        name = "Standard_B1s"
        tier = "Standard"
        capacity = var.web_server_count
    }
    storage_profile_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer = "WindowsServer"
        sku = "2019-Datacenter"
        version = "latest"
    }
    storage_profile_os_disk{
        name                 = ""
        caching              = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
      }
    os_profile{
        computer_name_prefix = local.web_server_name
        admin_username = "webserver"
        admin_password = data.azurerm_key_vault_secret.admin_password.value
    }
    os_profile_windows_config {
        provision_vm_agent = true
        enable_automatic_upgrades  = true
    }
    
    boot_diagnostics {
        enabled = true
        storage_uri = azurerm_storage_account.storage_account.primary_blob_endpoint
    }

    network_profile {
        name = "web_server_network_profile"
        primary = true
        ip_configuration {
            name = local.web_server_name
            primary = true
            subnet_id = azurerm_subnet.web_server_subnet["web-server"].id
            load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id]
        }
    }

    extension {
        name = "${local.web_server_name}-extension"
        publisher = "Microsoft.Compute"
        type = "CustomScriptExtension"
        type_handler_version = "1.10"
        settings = <<SETTINGS
    {
        "fileUris": ["https://raw.githubusercontent.com/eltimmo/learning/master/azureInstallWebServer.ps1"],
        "commandToExecute": "start powershell -ExecutionPolicy Unrestricted -File azureInstallWebServer.ps1"
    }
    SETTINGS

    }
    
}

/*resource "azurerm_availability_set" "web_server_availability_set"{

    name = "${var.resource_prefix}-availability-set"
    location = var.web_server_location
    resource_group_name = azurerm_resource_group.web_server_rg.name  
    managed = true
    platform_fault_domain_count = 2
}*/

# resource "azurerm_image" "web-server-vm-inage" {
#   name                      = "vm-image-created01"
#   location                  = "East US"
#   resource_group_name       = azurerm_resource_group.web_server_rg.name
#   source_virtual_machine_id = "/subscriptions/d83472e0-94c2-438f-bfda-098b5d7f22cb/resourceGroups/web-rg001/providers/Microsoft.Compute/images/web-01-01-vm-image-20200803232914"
# }

resource "azurerm_lb" "web_server_lb" {
    name = "${var.resource_prefix}-lb"
    location = var.web_server_location
    resource_group_name = azurerm_resource_group.web_server_rg.name

    frontend_ip_configuration {
        name                 = "${var.resource_prefix}-lb-frontend-ip"
        public_ip_address_id = azurerm_public_ip.web_server_lb_public_ip.id
    }
}

resource "azurerm_lb_backend_address_pool" "web_server_lb_backend_pool"{
    name = "${var.resource_prefix}-lb-backend-pool"
    resource_group_name = azurerm_resource_group.web_server_rg.name
    loadbalancer_id = azurerm_lb.web_server_lb.id
}

resource "azurerm_lb_probe" "web_server_lb_http_probe" {
    name = "${var.resource_prefix}-lb_http_probe"
    resource_group_name = azurerm_resource_group.web_server_rg.name
    loadbalancer_id = azurerm_lb.web_server_lb.id
    protocol = "tcp"
    port = "80"
}

resource "azurerm_lb_rule" "web_server_lb_http_rule" {
    name = "${var.resource_prefix}-lb-http-rule"
    resource_group_name = azurerm_resource_group.web_server_rg.name
    loadbalancer_id = azurerm_lb.web_server_lb.id
    protocol = "tcp"
    frontend_port = "80"
    backend_port = "80"
    frontend_ip_configuration_name = "${var.resource_prefix}-lb-frontend-ip"
    probe_id = azurerm_lb_probe.web_server_lb_http_probe.id
    backend_address_pool_id = azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id

}
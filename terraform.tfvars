web_server_location = "eastus"
web_server_rg = "web-rg001"
resource_prefix = "web-server"
web_server_address_space = "1.0.0.0/22"
web_server_address_prefix = "1.0.1.0/24"
web_server_name = "web"
environment = "development"
web_server_count = 2
web_server_env_count = 2
web_server_subnet = {
    web-server = "1.0.1.0/24"
    AzureBastionsSubnet = "1.0.2.0/24"
}
terraform_script_version = "1.0.0"
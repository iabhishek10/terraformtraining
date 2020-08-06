variable "web_server_location"{
    type = string
}

variable "web_server_rg"{
    type = string
}

variable "resource_prefix"{
    type = string
}

variable "web_server_address_space"{
    type = string
}

variable "web_server_address_prefix"{
    type = string
}

variable "web_server_name" {
    type = string
}

variable "environment" {
    type = string
}

variable "web_server_count" {
    type = string
}

variable "web_server_env_count" {
    type = string
}

variable "web_server_subnet"{
    type = map
}

variable "terraform_script_version" {
    type = string
}
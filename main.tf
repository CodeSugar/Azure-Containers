terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "ee_..."
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = "East US"
}

resource "azurerm_storage_account" "caddy" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  tags = {
    environment = "poc"
    purpose     = "caddy-volumes"
  }
}

resource "azurerm_storage_share" "caddy_config" {
  name                 = "proxy-caddyfile"
  storage_account_name = azurerm_storage_account.caddy.name
  quota                = 1
}

resource "azurerm_storage_share" "caddy_data" {
  name                 = "proxy-data"
  storage_account_name = azurerm_storage_account.caddy.name
  quota                = 1
}

resource "azurerm_storage_share" "caddy_config_dir" {
  name                 = "proxy-config"
  storage_account_name = azurerm_storage_account.caddy.name
  quota                = 1
}

resource "azurerm_storage_share" "grafana_storage" {
  name                 = "grafana-storage"
  storage_account_name = azurerm_storage_account.caddy.name
  quota                = 5
}

resource "azurerm_storage_share_file" "caddyfile" {
  name             = "Caddyfile"
  storage_share_id = azurerm_storage_share.caddy_config.id
  source           = "${path.module}/Caddyfile"
}

resource "azurerm_container_group" "my_app" {
  name                = var.container_group_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  ip_address_type     = "Public"
  dns_name_label      = var.dns_name_label
  os_type             = "Linux"

  image_registry_credential {
    username = "code_..."
    password = "dckr_pat_..."
    server = "index.docker.io"
  }

  container {
    name   = "reverse-proxy"
    image  = "caddy:2.6"
    cpu    = "1.0"
    memory = "1.0"

    ports {
      port     = 80
      protocol = "TCP"
    }

    ports {
      port     = 443
      protocol = "TCP"
    }

    volume {
      name       = "proxy-caddyfile"
      mount_path = "/etc/caddy"

      storage_account_name = azurerm_storage_account.caddy.name
      storage_account_key  = azurerm_storage_account.caddy.primary_access_key
      share_name          = azurerm_storage_share.caddy_config.name
    }

    volume {
      name       = "proxy-data"
      mount_path = "/data"

      storage_account_name = azurerm_storage_account.caddy.name
      storage_account_key  = azurerm_storage_account.caddy.primary_access_key
      share_name          = azurerm_storage_share.caddy_data.name
    }

    volume {
      name       = "proxy-config"
      mount_path = "/config"

      storage_account_name = azurerm_storage_account.caddy.name
      storage_account_key  = azurerm_storage_account.caddy.primary_access_key
      share_name          = azurerm_storage_share.caddy_config_dir.name
    }
  }

  container {
    name   = "my-app"
    image  = "mcr.microsoft.com/azuredocs/aci-helloworld"
    cpu    = "1.0"
    memory = "1.0"

    ports {
      port     = 5000
      protocol = "TCP"
    }

    environment_variables = {
      PORT = "5000"
    }
  }

  container {
    name   = "grafana"
    image  = "grafana/grafana:latest"
    cpu    = "1.0"
    memory = "1.0"

    ports {
      port     = 3000
      protocol = "TCP"
    }

    environment_variables = {
      GF_SECURITY_ADMIN_USER     = "admin_..."
      GF_SECURITY_ADMIN_PASSWORD = "hn_..."
      GF_SERVER_DOMAIN = "my-app-8dh36a.eastus.azurecontainer.io"
      GF_SERVER_ROOT_URL = "https://my-app-8dh36a.eastus.azurecontainer.io/grafana/"
    }

    volume {
      name       = "grafana-storage"
      mount_path = "/var/lib/grafana"

      storage_account_name = azurerm_storage_account.caddy.name
      storage_account_key  = azurerm_storage_account.caddy.primary_access_key
      share_name          = azurerm_storage_share.grafana_storage.name
    }
  }

  exposed_port {
    port     = 80
    protocol = "TCP"
  }

  exposed_port {
    port     = 443
    protocol = "TCP"
  }

  tags = {
    environment = "poc"
    purpose     = "caddy-reverse-proxy"
  }
}

output "container_group_fqdn" {
  description = "The FQDN of the container group"
  value       = azurerm_container_group.my_app.fqdn
}

output "container_group_ip_address" {
  description = "The IP address of the container group"
  value       = azurerm_container_group.my_app.ip_address
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.caddy.name
}
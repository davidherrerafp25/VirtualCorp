terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.112.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true
}

resource "proxmox_virtual_environment_container" "dhcp01" {
  node_name     = var.proxmox_node
  vm_id         = var.container_id
  unprivileged  = true
  started       = true
  start_on_boot = true

  features {
    nesting = true
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 6
  }

  operating_system {
    template_file_id = var.container_template
    type             = "debian"
  }

  initialization {
    hostname = "dhcp01"

    dns {
      servers = ["8.8.8.8"]
    }

    ip_config {
      ipv4 {
        address = var.container_ip
        gateway = var.container_gateway
      }
    }

    user_account {
      keys = [
        for key in var.ssh_public_keys :
        trimspace(file("${path.module}/${key}"))
      ]
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.container_bridge
  }
}

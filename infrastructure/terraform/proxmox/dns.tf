resource "proxmox_virtual_environment_container" "dns01" {
  node_name     = var.proxmox_node
  vm_id         = 204
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
    hostname = "dns01"

    ip_config {
      ipv4 {
        address = "dhcp"
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
    name        = "eth0"
    bridge      = var.container_bridge
    mac_address = "02:00:00:00:00:89"
  }
}

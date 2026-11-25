locals {
  ansible_inventory = {
    all = {
      children = {
        proxmox_lxc = {
          children = {
            terraform_services = {
              hosts = {
                dhcp01 = {
                  hostname          = "dhcp01"
                  vcorp_mac_address = lower(proxmox_virtual_environment_container.dhcp01.network_interface[0].mac_address)
                  vcorp_network     = "privada"
                  vcorp_ipv4_cidr   = var.container_ip
                  ansible_host      = split("/", var.container_ip)[0]
                }
                dns01 = {
                  hostname          = "dns01"
                  vcorp_mac_address = lower(proxmox_virtual_environment_container.dns01.network_interface[0].mac_address)
                  vcorp_network     = "privada"
                }
              }
            }
            kea_dhcp = {
              hosts = {
                dhcp01 = {}
              }
            }
            bind_dns = {
              hosts = {
                dns01 = {}
              }
            }
          }
        }
      }
    }
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../../../automation/ansible/inventories/proxmox_lxc.yml"
  content         = yamlencode(local.ansible_inventory)
  file_permission = "0644"

  depends_on = [
    proxmox_virtual_environment_container.dhcp01,
    proxmox_virtual_environment_container.dns01
  ]
}

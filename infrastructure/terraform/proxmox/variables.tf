variable "proxmox_endpoint" {
  type    = string
  default = "https://10.11.0.133:8006/"
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "pve01"
}

variable "container_id" {
  type    = number
  default = 201
}

variable "container_ip" {
  type    = string
  default = "10.11.0.136/26"
}

variable "container_gateway" {
  type    = string
  default = "10.11.0.129"
}

variable "container_bridge" {
  type    = string
  default = "vmbr0"
}

variable "container_template" {
  type    = string
  default = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "ssh_public_keys" {
  type = list(string)
  default = [
    "../../../configs/ssh/vcorp_sysadmin.pub",
    "../../../configs/ssh/vcorp_auditor.pub"
  ]
}

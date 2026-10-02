variable "proxmox_host" {
  description = "Name of the proxmost host inside the proxmox datacenter"
  type        = string
  default     = "proxmox"
}

# master variables
variable "master_hostname" {
  description = "Talos Master VM's to be created"
  type        = list(string)
  default     = ["kmaster1", "kmaster2", "kmaster3"]
}

variable "master_vmid" {
  description = "Starting ID for Master VM's"
  type        = number
  default     = 300
}

variable "master_mac" {
  description = "MAC's for Master VM's"
  type        = list(string)
  default     = ["BC:24:11:7A:3E:91", "BC:24:11:7A:C4:2D", "BC:24:11:7A:58:F7"]
}

# Worker variables
variable "worker_hostname" {
  description = "Talos Worker VM's to be created"
  type        = list(string)
  default     = ["kworker1", "kworker2", "kworker3"]
}

variable "worker_vmid" {
  description = "Starting ID for Worker VM's"
  type        = number
  default     = 303
}

variable "worker_mac" {
  description = "MAC's for Worker VM's"
  type        = list(string)
  default     = ["BC:24:11:7A:E1:6B", "BC:24:11:7A:92:34", "BC:24:11:7A:AF:D8"]
}

locals {
  proxmox_secrets = jsondecode(data.doppler_secrets.home-cluster.map.PROXMOX)
}

locals {
  talos_images = yamldecode(
    file("${path.module}/../../../talos/talenv.yaml")
  ).talosImages

  talos_iso_names = {
    for role, image_url in local.talos_images :
    role => "talos-${substr(regex("[0-9a-f]{64}", image_url), 0, 8)}-secureboot.iso"
  }
}

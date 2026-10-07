terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc10"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = "1.22.0"
    }
  }
  required_version = ">=1.3.0"
}

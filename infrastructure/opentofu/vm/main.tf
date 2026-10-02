provider "doppler" {}

data "doppler_secrets" "home-cluster" {}

provider "proxmox" {
  pm_api_url          = "https://192.168.0.3:8006/api2/json"
  pm_api_token_id     = local.proxmox_secrets.token_id
  pm_api_token_secret = local.proxmox_secrets.token_secret
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "talos_master" {
  count = length(var.master_hostname)
  name  = var.master_hostname[count.index]

  target_node = var.proxmox_host
  vmid        = var.master_vmid + count.index

  agent              = 1
  os_type            = "linux"
  qemu_os            = "l26"
  bios               = "ovmf"
  balloon            = 0
  memory             = 16384
  scsihw             = "virtio-scsi-pci"
  boot               = "order=sata0;sata2"
  power_state           = "running"
  start_at_node_boot = true
  skip_ipv6          = true
  tags               = "k8s,talos,controlplane"

  startup_shutdown {
    order            = 15
    shutdown_timeout = 30
    startup_delay    = 30
  }

  cpu {
    cores   = 3
    sockets = 2
    type    = "IvyBridge"
  }

  disks {
    sata {
      sata0 {
        disk {
          cache   = "writethrough"
          discard = true
          emulatessd = true
          size    = "64G"
          storage = "local-lvm"
        }
      }
      sata1 {
        disk {
          cache   = "writethrough"
          discard = true
          emulatessd = true
          size    = "32G"
          storage = "local-lvm"
        }
      }
      sata2 {
        cdrom {
          iso = "local:iso/${local.talos_iso_names.controlplane}"
        }
      }
    }
  }

  efidisk {
    efitype           = "4m"
    storage           = "local-lvm"
    pre_enrolled_keys = false
  }

  tpm_state {
    storage = "local-lvm"
    version = "v2.0"
  }

  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    mtu     = 1
    tag     = 20
    macaddr = var.master_mac[count.index]
  }
}

resource "proxmox_vm_qemu" "talos_worker" {
  count = length(var.worker_hostname)
  name  = var.worker_hostname[count.index]

  target_node = var.proxmox_host
  vmid        = var.worker_vmid + count.index

  agent              = 1
  os_type            = "linux"
  qemu_os            = "l26"
  bios               = "ovmf"
  balloon            = 0
  memory             = 20480
  scsihw             = "virtio-scsi-pci"
  boot               = "order=sata0;sata3"
  power_state           = "running"
  start_at_node_boot = true
  skip_ipv6          = true
  tags               = "k8s,talos,worker"

  startup_shutdown {
    order            = 15
    shutdown_timeout = 30
    startup_delay    = 30
  }

  cpu {
    cores   = 2
    sockets = 2
    type    = "IvyBridge"
  }

  disks {
    sata {
      sata0 {
        disk {
          cache   = "writethrough"
          discard = true
          emulatessd = true
          size    = "64G"
          storage = "local-lvm"
        }
      }
      sata1 {
        disk {
          cache   = "writethrough"
          discard = true
          emulatessd = true
          size    = "256G"
          storage = "local-lvm"
        }
      }
      sata2 {
        disk {
          cache   = "writethrough"
          discard = true
          emulatessd = true
          size    = "32G"
          storage = "local-lvm"
        }
      }
      sata3 {
        cdrom {
          iso = "local:iso/${local.talos_iso_names.worker}"
        }
      }
    }
  }

  efidisk {
    efitype           = "4m"
    storage           = "local-lvm"
    pre_enrolled_keys = false
  }

  tpm_state {
    storage = "local-lvm"
    version = "v2.0"
  }

  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    mtu     = 1
    tag     = 20
    macaddr = var.worker_mac[count.index]
  }
}

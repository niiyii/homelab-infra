terraform {
  required_version = ">= 1.0.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc4"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}

# Cloud-init template (Ubuntu 24.04)
# Download and create template first:
# wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
# qm create 9000 --memory 2048 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci
# qm set 9000 --scsi0 local-lvm:0,import-from=/path/to/noble-server-cloudimg-amd64.img
# qm set 9000 --ide2 local-lvm:cloudinit --boot order=scsi0 --serial0 socket --vga serial0
# qm template 9000

resource "proxmox_vm_qemu" "elk_stack" {
  name        = "elk-stack"
  target_node = var.proxmox_node
  clone       = var.template_name
  agent       = 1
  os_type     = "cloud-init"

  cores   = 2
  sockets = 1
  memory  = 20480 # 20GB RAM for ELK

  scsihw = "virtio-scsi-pci"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = "60G"
          storage = var.storage_pool
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Cloud-init settings
  ipconfig0  = "ip=${var.elk_ip}/24,gw=${var.gateway}"
  nameserver = var.dns_server
  ciuser     = var.vm_user
  sshkeys    = var.ssh_public_key

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io docker-compose-v2",
      "sudo usermod -aG docker ${var.vm_user}",
      "sudo systemctl enable docker",
    ]

    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.ssh_private_key_path)
      host        = var.elk_ip
    }
  }
}

resource "proxmox_vm_qemu" "support_stack" {
  name        = "support-stack"
  target_node = var.proxmox_node
  clone       = var.template_name
  agent       = 1
  os_type     = "cloud-init"

  cores   = 2
  sockets = 1
  memory  = 10240 # 10GB RAM

  scsihw = "virtio-scsi-pci"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = "30G"
          storage = var.storage_pool
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  ipconfig0  = "ip=${var.support_ip}/24,gw=${var.gateway}"
  nameserver = var.dns_server
  ciuser     = var.vm_user
  sshkeys    = var.ssh_public_key

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io docker-compose-v2",
      "sudo usermod -aG docker ${var.vm_user}",
      "sudo systemctl enable docker",
    ]

    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.ssh_private_key_path)
      host        = var.support_ip
    }
  }
}

output "elk_vm_ip" {
  value = var.elk_ip
}

output "support_vm_ip" {
  value = var.support_ip
}

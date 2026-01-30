variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "template_name" {
  description = "Name of the cloud-init template"
  type        = string
  default     = "ubuntu-cloud-template"
}

variable "storage_pool" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "elk_ip" {
  description = "Static IP for ELK VM"
  type        = string
}

variable "support_ip" {
  description = "Static IP for Support VM"
  type        = string
}

variable "gateway" {
  description = "Network gateway"
  type        = string
}

variable "dns_server" {
  description = "DNS server"
  type        = string
  default     = "1.1.1.1"
}

variable "vm_user" {
  description = "Default VM user"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

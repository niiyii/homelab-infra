variable "tenancy_ocid" {
  description = "Oracle Cloud tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "Oracle Cloud user OCID"
  type        = string
}

variable "fingerprint" {
  description = "API key fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to Oracle Cloud private key"
  type        = string
}

variable "region" {
  description = "Oracle Cloud region"
  type        = string
  default     = "eu-amsterdam-1"
}

variable "compartment_id" {
  description = "Compartment OCID (usually same as tenancy for personal accounts)"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

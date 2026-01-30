terraform {
  required_version = ">= 1.0.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Get availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Create VCN
resource "oci_core_vcn" "homelab_vcn" {
  compartment_id = var.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "homelab-vcn"
  dns_label      = "homelabvcn"
}

# Internet Gateway
resource "oci_core_internet_gateway" "homelab_igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab_vcn.id
  display_name   = "homelab-igw"
  enabled        = true
}

# Route Table
resource "oci_core_route_table" "homelab_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab_vcn.id
  display_name   = "homelab-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.homelab_igw.id
  }
}

# Security List
resource "oci_core_security_list" "homelab_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab_vcn.id
  display_name   = "homelab-sl"

  # Allow SSH
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow Jellyfin HTTP
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 8096
      max = 8096
    }
  }

  # Allow Jellyfin HTTPS
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 8920
      max = 8920
    }
  }

  # Allow all outbound
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Subnet
resource "oci_core_subnet" "homelab_subnet" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.homelab_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "homelab-subnet"
  dns_label         = "homelabsub"
  route_table_id    = oci_core_route_table.homelab_rt.id
  security_list_ids = [oci_core_security_list.homelab_sl.id]
}

# Get latest Oracle Linux image (Always Free eligible)
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Jellyfin Instance (ARM - Always Free)
resource "oci_core_instance" "jellyfin" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "jellyfin-server"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.oracle_linux.images[0].id
    boot_volume_size_in_gbs = 100
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.homelab_subnet.id
    assign_public_ip = true
    display_name     = "jellyfin-vnic"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
      #!/bin/bash
      # Update system
      dnf update -y
      
      # Install Docker
      dnf install -y dnf-utils
      dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      systemctl enable docker
      systemctl start docker
      
      # Add opc user to docker group
      usermod -aG docker opc
      
      # Install Tailscale
      curl -fsSL https://tailscale.com/install.sh | sh
      
      # Create directories
      mkdir -p /opt/jellyfin/{config,cache}
      mkdir -p /opt/beats
      chown -R opc:opc /opt/jellyfin /opt/beats
    EOF
    )
  }
}

output "jellyfin_public_ip" {
  value = oci_core_instance.jellyfin.public_ip
}

output "jellyfin_private_ip" {
  value = oci_core_instance.jellyfin.private_ip
}

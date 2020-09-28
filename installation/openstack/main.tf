## - terraform -
#

terraform {
  required_providers {
    openstack = {
      source = "terraform-providers/openstack"
    }
    random = {
      source = "hashicorp/random"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = ">= 0.13"
}

## - used variables for this stack -
#

variable "prefix" {
  description = "Prefix for OpenStack objects"
  default     = "example"
  type        = string
}
variable "ssh_username" {
  description = "ssh username"
  default     = "ubuntu"
  type        = string
}

variable "availability_zone" {
  description = "OpenStack Nova availability_zone"
  type        = string
}
variable "tenant_network" {
  description = "OpenStack Neutron network for Nova instances"
  type        = string
}
variable "pool_name" {
  description = "OpenStack Neutron external pool"
  type        = string
}
variable "ssh_public_key_file" {
  description = "SSH private key file used to access instances"
  default     = "~/.ssh/id_rsa.pub"
  type        = string
}

variable "jumphost_image_name" {
  description = "OpenStack Glance image name"
  type        = string
}
variable "jumphost_flavor_name" {
  description = "OpenStack Nova flavor"
  type        = string
}
variable "jumphost_security_groups" {
  description = "OpenStack Security Groups for the master nodes"
  default     = "default"
}

variable "master_image_name" {
  description = "OpenStack Glance image name"
  type        = string
}
variable "master_flavor_name" {
  description = "OpenStack Nova flavor"
  type        = string
}
variable "master_security_groups" {
  description = "OpenStack Security Groups for the master nodes"
  default     = "default"
}

variable "ingress_image_name" {
  description = "OpenStack Glance image name"
  type        = string
}
variable "ingress_flavor_name" {
  description = "OpenStack Nova flavor"
  type        = string
}
variable "ingress_security_groups" {
  description = "OpenStack Security Groups for the ingress node(s)"
  default     = "default"
}

variable "worker_count" {
  description = "Amount of worker nodes"
  default     = "1"
  type        = number
}
variable "worker_image_name" {
  description = "OpenStack Glance image name"
  type        = string
}
variable "worker_flavor_name" {
  description = "OpenStack Nova flavor name"
  type        = string
}
variable "worker_security_groups" {
  description = "OpenStack Security Groups for the worker nodes"
  default     = "default"
}

## - password and tokens -
#

resource "random_password" "user_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "k3s_token" {
  length           = 24
  special          = true
  override_special = "_%@"
}

## - master node(s) -
#

data "template_file" "cloudinit_master" {
  template = file("${path.module}/template.d/cloudinit-master.tpl")
  vars = {
    SSH_PUB_KEY   = file(var.ssh_public_key_file)
    SSH_USERNAME  = var.ssh_username
    USER_PASSWORD = random_password.user_password.result
    K3S_TOKEN     = random_password.k3s_token.result
  }
}
resource "openstack_compute_instance_v2" "master" {
  name              = "${var.prefix}-master"
  image_name        = var.master_image_name
  flavor_name       = var.master_flavor_name
  security_groups   = [var.master_security_groups]
  user_data         = data.template_file.cloudinit_master.rendered
  availability_zone = var.availability_zone
  config_drive      = false
  network {
    name = var.tenant_network
  }
}

## - the jumphost node -
# 
resource "openstack_networking_floatingip_v2" "jumphost_fip" {
  pool = var.pool_name
}
resource "openstack_compute_floatingip_associate_v2" "jumphost_fip_bind" {
  floating_ip = openstack_networking_floatingip_v2.jumphost_fip.address
  instance_id = openstack_compute_instance_v2.jumphost.id
}
resource "openstack_compute_secgroup_v2" "jumphost_secgroup" {
  name        = "${var.prefix}-sg-jumphost"
  description = "Security group (managed by terraform)"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

data "template_file" "cloudinit_jumphost" {
  template = file("${path.module}/template.d/cloudinit-jumphost.tpl")
  vars = {
    SSH_PUB_KEY   = file(var.ssh_public_key_file)
    SSH_USERNAME  = var.ssh_username
    USER_PASSWORD = random_password.user_password.result
  }
}
resource "openstack_compute_instance_v2" "jumphost" {
  name              = "${var.prefix}-jumphost"
  image_name        = var.jumphost_image_name
  flavor_name       = var.jumphost_flavor_name
  security_groups   = [var.jumphost_security_groups, openstack_compute_secgroup_v2.jumphost_secgroup.id]
  user_data         = data.template_file.cloudinit_jumphost.rendered
  availability_zone = var.availability_zone
  config_drive      = false
  network {
    name = var.tenant_network
  }
}

output "jumphost" {
  value = openstack_networking_floatingip_v2.jumphost_fip.address
}
output "username" {
  value = var.ssh_username
}

## - the ingress node / loadbalancer -
# 
resource "openstack_networking_floatingip_v2" "ingress_fip" {
  pool = var.pool_name
}
resource "openstack_compute_floatingip_associate_v2" "ingress_fip_bind" {
  floating_ip = openstack_networking_floatingip_v2.ingress_fip.address
  instance_id = openstack_compute_instance_v2.ingress.id
}
resource "openstack_compute_secgroup_v2" "ingress_secgroup" {
  name        = "${var.prefix}-sg-ingress"
  description = "Security group (managed by terraform)"

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

data "template_file" "cloudinit_ingress" {
  template = file("${path.module}/template.d/cloudinit-ingress.tpl")
  vars = {
    SSH_PUB_KEY   = file(var.ssh_public_key_file)
    SSH_USERNAME  = var.ssh_username
    USER_PASSWORD = random_password.user_password.result
    K3S_TOKEN     = random_password.k3s_token.result
    MASTER        = openstack_compute_instance_v2.master.access_ip_v4
  }
}
resource "openstack_compute_instance_v2" "ingress" {
  name              = "${var.prefix}-ingress"
  image_name        = var.ingress_image_name
  flavor_name       = var.ingress_flavor_name
  security_groups   = [var.ingress_security_groups, openstack_compute_secgroup_v2.ingress_secgroup.id]
  user_data         = data.template_file.cloudinit_ingress.rendered
  availability_zone = var.availability_zone
  config_drive      = false
  network {
    name = var.tenant_network
  }
}

output "ingress" {
  value = openstack_networking_floatingip_v2.ingress_fip.address
}

## - the worker node(s) -
#

data "template_file" "cloudinit_worker" {
  template = file("${path.module}/template.d/cloudinit-worker.tpl")
  vars = {
    SSH_PUB_KEY   = file(var.ssh_public_key_file)
    SSH_USERNAME  = var.ssh_username
    USER_PASSWORD = random_password.user_password.result
    K3S_TOKEN     = random_password.k3s_token.result
    MASTER        = openstack_compute_instance_v2.master.access_ip_v4
  }
}
resource "openstack_compute_instance_v2" "worker" {
  count             = var.worker_count
  name              = "${var.prefix}-worker${count.index}"
  image_name        = var.worker_image_name
  flavor_name       = var.worker_flavor_name
  security_groups   = [var.worker_security_groups]
  user_data         = data.template_file.cloudinit_worker.rendered
  availability_zone = var.availability_zone
  config_drive      = false
  network {
    name = var.tenant_network
  }
}

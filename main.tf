terraform {
  required_providers {
    linode = {
      source = "linode/linode"
    }
  }
}

# Token must be provided via LINODE_TOKEN env var
provider "linode" {}

resource "linode_instance" "manager" {
  type            = var.worker_size
  region          = var.region
  private_ip      = true
  label           = "d8x-cluster-manager"
  image           = "linode/ubuntu22.04"
  booted          = true
  authorized_keys = var.authorized_keys

  #   interface {
  #     purpose = "vlan"
  #     label   = "d8x-cluster-vlan"
  #   }
}

resource "linode_instance" "nodes" {
  count = var.num_workers

  type            = var.worker_size
  region          = var.region
  private_ip      = true
  label           = "d8x-cluster-worker-${count.index + 1}"
  image           = "linode/ubuntu22.04"
  booted          = true
  authorized_keys = var.authorized_keys

  #   interface {
  #     purpose = "vlan"
  #     label   = "d8x-cluster-vlan"
  #   }

}

# Geneate ansible inventory
resource "local_file" "hosts_cfg" {
  depends_on = [linode_instance.manager, linode_instance.nodes]
  content = templatefile("inventory.tpl",
    {
      manager_public_ip   = linode_instance.manager.ip_address
      manager_private_ip  = linode_instance.manager.private_ip_address
      workers_public_ips  = linode_instance.nodes.*.ip_address
      workers_private_ips = linode_instance.nodes.*.private_ip_address
    }
  )
  filename = "hosts.cfg"
}

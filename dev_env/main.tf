terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

variable "hcloud_token" {
  description = "Token API Hetzner Cloud"
  type        = string
  sensitive   = true
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_server" "dev_machine" {
  name        = "fintech-dev-docker"
  image       = "ubuntu-22.04"
  server_type = "cpx22" # 3 vCPU, 4GB RAM (Cukup buat ngangkat Postgres + Mongo + Quickwit)
  location    = "hel1"  # Server Finland
  
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  # Script ini otomatis jalan buat nginstall Docker saat mesin pertama kali nyala
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io docker-compose
              systemctl start docker
              systemctl enable docker
              EOF
}

output "server_ip_public" {
  value       = hcloud_server.dev_machine.ipv4_address
  description = "IP buat dicolok ke SSH dan DBeaver"
}
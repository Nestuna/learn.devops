terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
  }
  required_version = ">= 0.13"
}

provider "scaleway" {
  project_id = "6ff3b4a2-6d73-40bf-85f7-4074b99a4f37"
  access_key = "SCW2SW4PMX1R6FXZ59GC"
  secret_key = "aadbca4f-9674-4790-8f1d-e5144a3852cb"
}


resource "scaleway_rdb_instance" "main" {
  name           = "test-rdb"
  node_type      = "db-dev-s"
  engine         = "PostgreSQL-12"
  is_ha_cluster  = false
  disable_backup = true
  user_name      = "astuna"
  password       = "Efrei!2021"
}

resource "scaleway_instance_ip" "public_ip" {
  count =  2
  zone = "fr-par-1"
}

locals {
  database_uri = "postgres://${scaleway_rdb_instance.main.user_name}:${scaleway_rdb_instance.main.password}@${scaleway_rdb_instance.main.endpoint_ip}:${scaleway_rdb_instance.main.endpoint_port}/${scaleway_rdb_instance.main.name}"
}

data "scaleway_instance_image" "server-web" {
  architecture = "x86_64"
  name         = "server-web"
}
resource "scaleway_instance_server" "web" {
  count = 2
  name  = "server-0${count.index + 1}"
  type  = "DEV1-S"
  image = data.scaleway_instance_image.server-web.id
  ip_id = scaleway_instance_ip.public_ip[count.index].id
  user_data = {
    DATABASE_URI = local.database_uri
  }
}

resource "scaleway_lb_ip" "ip" {
}

resource "scaleway_lb" "base" {
  name = "test-lb"
  ip_id  = scaleway_lb_ip.ip.id
  zone = "fr-par-1"
  type   = "LB-S"
}

resource "scaleway_lb_backend" "backend01" {
  lb_id            = scaleway_lb.base.id
  name             = "backend"
  forward_protocol = "http"
  forward_port     = "80"
  server_ips = [for public_ip in scaleway_instance_ip.public_ip : public_ip.address]
}

resource "scaleway_lb_frontend" "frontend01" {
  lb_id        = scaleway_lb.base.id
  backend_id   = scaleway_lb_backend.backend01.id
  name         = "frontend01"
  inbound_port = "80"
}
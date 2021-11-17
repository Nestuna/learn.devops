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
  zone = "fr-par-1"
}

locals {
  database_uri = "postgres://${scaleway_rdb_instance.main.user_name}:${scaleway_rdb_instance.main.password}@${scaleway_rdb_instance.main.endpoint_ip}:${scaleway_rdb_instance.main.endpoint_port}/${scaleway_rdb_instance.main.name}"
}
resource "scaleway_instance_server" "web" {
  name  = "server-01"
  type  = "DEV1-S"
  image = "ubuntu_focal"
  ip_id = scaleway_instance_ip.public_ip.id
  user_data = {
    DATABASE_URI = local.database_uri
  }
    provisioner "remote-exec" {
      inline = [
        "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
        "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
        "apt update",
        "apt install -y docker-ce docker-ce-cli containerd.io",
        "docker run -d --name app -e DATABASE_URI='$(scw-userdata DATABASE_URI)' -p 80:8080 --restart=always rg.fr-par.scw.cloud/efrei-devops/app:latest"
      ]
  }
    connection {
    type     = "ssh"
    user     = "root"
    host     = "${scaleway_instance_ip.public_ip.address}"
    private_key = "${file("~/.ssh/id_github")}"
  }
}
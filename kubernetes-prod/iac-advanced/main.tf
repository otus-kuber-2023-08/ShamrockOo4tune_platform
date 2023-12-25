locals {
  folder_id = "b1gjap7i9e06sdcbetb4"
}

resource "yandex_vpc_network" "kubernetes-prod" {
  name = "kubernetes-prod"
}

resource "yandex_vpc_subnet" "kubernetes-prod" {
  name           = "kubeadm-prod"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.kubernetes-prod.id
  v4_cidr_blocks = ["192.168.10.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_gateway" "egress" {
  name = "egress"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "rt"
  network_id = yandex_vpc_network.kubernetes-prod.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.egress.id
  }
}

resource "yandex_lb_network_load_balancer" "api-server-balancer" {
  name = "api-server-balancer"

  listener {
    name = "api-server-port"
    port = 6443
    external_address_spec {
      address    = "178.154.206.101"
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.master-nodes.id
    healthcheck {
      name = "http"
      tcp_options {
        port = 6443
      }
    }
  }
}

resource "yandex_lb_target_group" "master-nodes" {
  name = "master-nodes"

  target {
    subnet_id = yandex_vpc_subnet.kubernetes-prod.id
    address   = yandex_compute_instance.master[0].network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.kubernetes-prod.id
    address   = yandex_compute_instance.master[1].network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.kubernetes-prod.id
    address   = yandex_compute_instance.master[2].network_interface.0.ip_address
  }
}

resource "yandex_compute_instance" "master" {
  count    = 3
  name     = "master-${count.index + 1}"
  hostname = "master-${count.index + 1}"
  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd85an6q1o26nf37i2nl"
      size     = 20
    }
  }

  network_interface {
    ip_address = "192.168.10.1${count.index + 1}"
    ipv6       = false
    nat        = false
    subnet_id  = yandex_vpc_subnet.kubernetes-prod.id
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "worker" {
  count    = 2
  name     = "worker-${count.index + 1}"
  hostname = "worker-${count.index + 1}"

  resources {
    cores         = 2
    memory        = 8
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd85an6q1o26nf37i2nl"
      size     = 20
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.kubernetes-prod.id
    nat        = false
    ip_address = "192.168.10.2${count.index + 1}"
    ipv6       = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "bastion" {
  name     = "bastion"
  hostname = "bastion"
  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd85an6q1o26nf37i2nl"
      size     = 20
    }
  }

  network_interface {
    ip_address     = "192.168.10.10"
    ipv6           = false
    nat            = true
    nat_ip_address = "62.84.117.139"
    subnet_id      = yandex_vpc_subnet.kubernetes-prod.id
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

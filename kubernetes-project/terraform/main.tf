resource "yandex_vpc_network" "platform" {
  name = "platform"
}

resource "yandex_vpc_gateway" "egress" {
  name = "egress"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "rt" {
  name       = "rt"
  network_id = yandex_vpc_network.platform.id
  depends_on = [
    yandex_vpc_network.platform,
    yandex_vpc_gateway.egress,
  ]

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.egress.id
  }
}

resource "yandex_vpc_subnet" "platform-subnet-1" {
  name           = "platform-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.platform.id
  v4_cidr_blocks = ["192.168.10.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "platform-subnet-2" {
  name           = "platform-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.platform.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_subnet" "platform-subnet-3" {
  name           = "platform-subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.platform.id
  v4_cidr_blocks = ["192.168.30.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

resource "yandex_vpc_address" "platform_public_ip_1" {
  name                = "platform_public_ip_1"
  deletion_protection = false
  external_ipv4_address {
    zone_id = var.zone
  }
}

resource "yandex_vpc_address" "platform_public_ip_2" {
  name                = "platform_public_ip_2"
  deletion_protection = false
  external_ipv4_address {
    zone_id = var.zone
  }
}

resource "yandex_lb_network_load_balancer" "platform-api-server" {

  name = "platform-api-server"
  type = "internal"

  listener {
    name = "platform-api-server"
    port = 6443
    internal_address_spec {
      subnet_id  = yandex_vpc_subnet.platform-subnet-1.id
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.k8s-master-nodes.load_balancer.0.target_group_id
    healthcheck {
      name = "kube-api-liveness-probe"
      # TODO implement plaintext http endpoint for liveness checks
      tcp_options {
        port = 6443
      }
    }
  }
}

resource "yandex_lb_network_load_balancer" "platform-ingress" {
  name = "platform-ingress"

  listener {
    name        = "platform-ingress-http"
    port        = 80
    target_port = 30080
    external_address_spec {
      address    = yandex_vpc_address.platform_public_ip_2.external_ipv4_address[0].address
      ip_version = "ipv4"
    }
  }

  listener {
    name        = "platform-ingress-https"
    port        = 443
    target_port = 30443
    external_address_spec {
      address    = yandex_vpc_address.platform_public_ip_2.external_ipv4_address[0].address
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.k8s-worker-nodes.load_balancer.0.target_group_id
    healthcheck {
      name = "ingress-probe"
      tcp_options {
        port = 30080
      }
    }
  }
}

resource "yandex_iam_service_account" "admin" {
  name = "admin"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = var.folder_id
  role      = "editor"
  members   = ["serviceAccount:${yandex_iam_service_account.admin.id}"]
}

resource "yandex_compute_instance_group" "k8s-master-nodes" {
  name               = "k8s-master-nodes"
  service_account_id = yandex_iam_service_account.admin.id

  instance_template {
    platform_id = "standard-v2" // ru-central1-d doesn't provide standard-v1
    name        = "master{instance.index}"
    hostname    = "master{instance.index}"

    resources {
      cores         = 2
      memory        = 4
      core_fraction = 20
    }

    boot_disk {
      initialize_params {
        image_id = var.image_id
        size     = 20
        type     = "network-ssd"
      }
    }

    network_interface {
      network_id = yandex_vpc_network.platform.id
      subnet_ids = [
        yandex_vpc_subnet.platform-subnet-1.id,
        yandex_vpc_subnet.platform-subnet-2.id,
        yandex_vpc_subnet.platform-subnet-3.id,
      ]
      nat = false
    }

    metadata = {
      user-data : "#cloud-config\nusers:\n  - name: ansible\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${tls_private_key.ssh_key.public_key_openssh}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = [
      "ru-central1-a",
      "ru-central1-b",
      "ru-central1-d",
    ]
  }

  deploy_policy {
    max_unavailable = 3
    max_creating    = 3
    max_expansion   = 3
    max_deleting    = 3
  }

  load_balancer {
    target_group_name = "k8s-master-nodes"
  }
}

resource "yandex_compute_instance_group" "k8s-worker-nodes" {
  name               = "k8s-worker-nodes"
  service_account_id = yandex_iam_service_account.admin.id

  instance_template {
    platform_id = "standard-v2"
    name        = "worker{instance.index}"
    hostname    = "worker{instance.index}"

    resources {
      cores         = 2
      memory        = 8
      core_fraction = 20
    }

    boot_disk {
      initialize_params {
        image_id = var.image_id
        size     = 20
      }
    }

    network_interface {
      network_id = yandex_vpc_network.platform.id
      subnet_ids = [
        yandex_vpc_subnet.platform-subnet-1.id,
        yandex_vpc_subnet.platform-subnet-2.id,
        yandex_vpc_subnet.platform-subnet-3.id,
      ]
      nat = false
    }

    metadata = {
      user-data : "#cloud-config\nusers:\n  - name: ansible\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${tls_private_key.ssh_key.public_key_openssh}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = [
      "ru-central1-a",
      "ru-central1-b",
      "ru-central1-d",
    ]
  }

  deploy_policy {
    max_unavailable = 3
    max_creating    = 3
    max_expansion   = 3
    max_deleting    = 3
  }

  load_balancer {
    target_group_name = "k8s-worker-nodes"
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
      image_id = var.image_id
      size     = 20
    }
  }

  network_interface {
    ip_address     = "192.168.10.3"
    ipv6           = false
    nat            = true
    nat_ip_address = yandex_vpc_address.platform_public_ip_1.external_ipv4_address[0].address
    subnet_id      = yandex_vpc_subnet.platform-subnet-1.id
  }

  metadata = {
    user-data : "#cloud-config\nusers:\n  - name: ansible\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${tls_private_key.ssh_key.public_key_openssh}"
  }
}

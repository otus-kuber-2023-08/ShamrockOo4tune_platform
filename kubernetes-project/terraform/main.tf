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

  listener {
    name = "platform-api-server"
    port = 6443
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

  attached_target_group {
    target_group_id = yandex_compute_instance_group.k8s-master-nodes.load_balancer.0.target_group_id
    healthcheck {
      name = "kube-api-liveness-probe"
      # TODO implement plaintext http endpoint for liveness checks
      healthy_threshold = 2
      tcp_options {
        port = 6443
      }
    }
  }
}

resource "yandex_compute_instance_group" "k8s-master-nodes" {
  name               = "k8s-master-nodes"
  service_account_id = yandex_iam_service_account.admin.id

  instance_template {
    platform_id = var.platform_id
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
      nat  = false
      ipv6 = false
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
    platform_id = var.platform_id
    name        = "worker{instance.index}"
    hostname    = "worker{instance.index}"

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
      network_id = yandex_vpc_network.platform.id
      subnet_ids = [
        yandex_vpc_subnet.platform-subnet-1.id,
        yandex_vpc_subnet.platform-subnet-2.id,
        yandex_vpc_subnet.platform-subnet-3.id,
      ]
      nat  = false
      ipv6 = false
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
  name        = "bastion"
  hostname    = "bastion"
  platform_id = var.platform_id
  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id_bastion
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

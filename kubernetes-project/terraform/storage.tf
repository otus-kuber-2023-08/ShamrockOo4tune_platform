resource "yandex_compute_instance_group" "ceph-cluster" {
  name               = "ceph-cluster"
  service_account_id = yandex_iam_service_account.admin.id

  instance_template {
    platform_id = "standard-v2"
    name        = "ceph{instance.index}"
    hostname    = "ceph{instance.index}"

    resources {
      cores         = 2
      memory        = 4 * 2 //each osd will need 4GiB, but tariff plan allows max 8Gib for 20% CPU instabce
      core_fraction = 20
    }

    boot_disk {
      initialize_params {
        image_id = var.image_id_storages
        size     = 20
      }
    }

    secondary_disk {
      name = "sdd{instance.index}1"
      initialize_params {
        image_id = var.image_id_storages
        size     = 15
        type     = "network-ssd"
      }
    }

    secondary_disk {
      name = "sdd{instance.index}2"
      initialize_params {
        image_id = var.image_id_storages
        size     = 15
        type     = "network-ssd"
      }
    }

    secondary_disk {
      name = "sdd{instance.index}3"
      initialize_params {
        image_id = var.image_id_storages
        size     = 15
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
      //ip_address = "192.168.{instance.index}0.30"
    }

    # metadata = {
    #   ssh-keys = "ubuntu:${file(var.ssh_private_key_path)}"
    # }
    metadata = {
      user-data : "#cloud-config\nusers:\n  - name: ansible\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${tls_private_key.ssh_key.public_key_openssh}"
    }
  }

  scale_policy {
    fixed_scale {
      size = var.ceph_count
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
}

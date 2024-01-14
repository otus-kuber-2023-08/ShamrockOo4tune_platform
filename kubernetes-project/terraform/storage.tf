# Не нашел возможности задавать динамически количество и достигать нужного мне
# результата. Реализации с вариациями count/for each/compute_instance_group меня
# не удовлетворяют своим несоответствующим моим задумкам результатом, поэтому,
# ХОЧУ и БУДУ использовать не DRY подход. 
# Основное разочарование связано с тем что при создании compute_instance_group,
# т.е. - основной вариант который должен был бы обеспечить мою потребность,
# у создаваемых инстансов корневой раздел "/" монтируется вовсе не на 
# загрузочный hdd диск, а на случайный sdd. И очистить их разделы потом, для 
# передачи в OSD автоматизированным способом не получается без изобретения 
# сложных и кривых костылей, которые требуют экспертных знаний в области работы 
# с дисками и фс

resource "yandex_compute_disk" "ssd_for_ceph1" {
  count     = var.ceph == true ? 3 : 0
  folder_id = var.folder_id
  name      = "ssd-1-${count.index + 1}"
  type      = "network-ssd"
  zone      = "ru-central1-a"
  size      = 15
}

resource "yandex_compute_disk" "ssd_for_ceph2" {
  count     = var.ceph == true ? 3 : 0
  folder_id = var.folder_id
  name      = "ssd-2-${count.index + 1}"
  type      = "network-ssd"
  zone      = "ru-central1-b"
  size      = 15
}

resource "yandex_compute_disk" "ssd_for_ceph3" {
  count     = var.ceph == true ? 3 : 0
  folder_id = var.folder_id
  name      = "ssd-3-${count.index + 1}"
  type      = "network-ssd"
  zone      = "ru-central1-d"
  size      = 15
}

resource "yandex_compute_instance" "ceph1" {
  count                     = var.ceph == true ? 1 : 0
  folder_id                 = var.folder_id
  name                      = "ceph1"
  hostname                  = "ceph1"
  allow_stopping_for_update = true
  platform_id               = var.platform_id
  zone                      = "ru-central1-a"

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
    disk_id = yandex_compute_disk.ssd_for_ceph1[0].id
  }

  secondary_disk {
    disk_id = yandex_compute_disk.ssd_for_ceph1[1].id
  }

  secondary_disk {
    disk_id = yandex_compute_disk.ssd_for_ceph1[2].id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.platform-subnet-1.id
    nat       = false
    ipv6      = false
  }

  metadata = {
    user-data : "#cloud-config\nusers:\n  - name: ansible\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${tls_private_key.ssh_key.public_key_openssh}"
  }
}

resource "yandex_compute_instance" "ceph2" {
  count                     = var.ceph == true ? 1 : 0
  folder_id                 = var.folder_id
  name                      = "ceph2"
  hostname                  = "ceph2"
  allow_stopping_for_update = true
  platform_id               = var.platform_id
  zone                      = "ru-central1-b"

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
    disk_id = yandex_compute_disk.ssd_for_ceph2[0].id
  }

  secondary_disk {
    disk_id = yandex_compute_disk.ssd_for_ceph2[1].id
  }

  secondary_disk {
    disk_id = yandex_compute_disk.ssd_for_ceph2[2].id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.platform-subnet-2.id
    nat       = false
    ipv6      = false
  }

  metadata = {
    user-data : "#cloud-config\nusers:\n  - name: ansible\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${tls_private_key.ssh_key.public_key_openssh}"
  }
}

resource "yandex_compute_instance" "ceph3" {
  count                     = var.ceph == true ? 1 : 0
  folder_id                 = var.folder_id
  name                      = "ceph3"
  hostname                  = "ceph3"
  allow_stopping_for_update = true
  platform_id               = var.platform_id
  zone                      = "ru-central1-d"

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
    disk_id = yandex_compute_disk.ssd_for_ceph3[0].id
  }

  secondary_disk {
    disk_id = yandex_compute_disk.ssd_for_ceph3[1].id
  }

  secondary_disk {
    disk_id = yandex_compute_disk.ssd_for_ceph3[2].id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.platform-subnet-3.id
    nat       = false
    ipv6      = false
  }

  metadata = {
    user-data : "#cloud-config\nusers:\n  - name: ansible\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${tls_private_key.ssh_key.public_key_openssh}"
  }
}

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

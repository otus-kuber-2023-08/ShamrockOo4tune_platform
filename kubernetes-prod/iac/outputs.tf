output "master_public_ip" {
  value = yandex_compute_instance.master.network_interface.0.nat_ip_address
}

output "master_private_ip" {
  value = yandex_compute_instance.master.network_interface.0.ip_address
}

output "master_hostname" {
  value = yandex_compute_instance.master.hostname
}

output "worker_nodes_private_ips" {
  value = yandex_compute_instance.worker[*].network_interface[0].ip_address
}

output "worker_nodes_hostnames" {
  value = yandex_compute_instance.worker[*].hostname
}

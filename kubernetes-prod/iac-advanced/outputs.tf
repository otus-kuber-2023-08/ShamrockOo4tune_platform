output "master_nodes_private_ips" {
  value = yandex_compute_instance.master[*].network_interface[0].ip_address
}

output "master_nodes_hostnames" {
  value = yandex_compute_instance.master[*].hostname
}

output "worker_nodes_private_ips" {
  value = yandex_compute_instance.worker[*].network_interface[0].ip_address
}

output "worker_nodes_hostnames" {
  value = yandex_compute_instance.worker[*].hostname
}

output "bastion_public_ip" {
  value = yandex_compute_instance.bastion.network_interface.0.nat_ip_address
}

output "bastion_private_ip" {
  value = yandex_compute_instance.bastion.network_interface[0].ip_address
}

output "bastion_hostname" {
  value = yandex_compute_instance.bastion.hostname
}

output "loadbalancer_public_ip" {
  value = [for s in yandex_lb_network_load_balancer.api-server-balancer.listener : s.external_address_spec.*.address].0[0]
}

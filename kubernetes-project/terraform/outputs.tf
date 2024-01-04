output "master_nodes_private_ips" {
  value = yandex_compute_instance_group.k8s-master-nodes.instances.*.network_interface.0.ip_address
}

output "master_nodes_hostnames" {
  value = yandex_compute_instance_group.k8s-master-nodes.instances.*.fqdn
}

output "worker_nodes_private_ips" {
  value = yandex_compute_instance_group.k8s-worker-nodes.instances.*.network_interface.0.ip_address
}

output "worker_nodes_hostnames" {
  value = yandex_compute_instance_group.k8s-worker-nodes.instances.*.fqdn
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

output "api-server_balancer_ip" {
  value = [for s in yandex_lb_network_load_balancer.platform-api-server.listener : s.internal_address_spec.*.address].0[0]
}

output "platform_ingress_ip" {
  value = [for s in yandex_lb_network_load_balancer.platform-ingress.listener : s.external_address_spec.*.address].0[0]
}

output "private_key" {
  value     = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}

output "public_key" {
  value     = tls_private_key.ssh_key.public_key_openssh
  sensitive = false
}

output "ceph1_hostname" {
  value = yandex_compute_instance.ceph1.fqdn
}

output "ceph1_private_ip" {
  value = yandex_compute_instance.ceph1.network_interface[0].ip_address
}

output "ceph2_hostname" {
  value = yandex_compute_instance.ceph2.fqdn
}

output "ceph2_private_ip" {
  value = yandex_compute_instance.ceph2.network_interface[0].ip_address
}

output "ceph3_hostname" {
  value = yandex_compute_instance.ceph3.fqdn
}

output "ceph3_private_ip" {
  value = yandex_compute_instance.ceph3.network_interface[0].ip_address
}

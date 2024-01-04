resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "public_key" {
  count    = var.save_ssh_keys_locally ? 1 : 0
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "./ansible/ansible_rsa.pub"
}

resource "local_sensitive_file" "private_key" {
  count                = var.save_ssh_keys_locally ? 1 : 0
  content              = tls_private_key.ssh_key.private_key_pem
  filename             = "./ansible/ansible_rsa"
  file_permission      = "0600"
  directory_permission = "0755"
}

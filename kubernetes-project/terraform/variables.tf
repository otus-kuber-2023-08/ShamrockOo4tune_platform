variable "cloud_id" {
  description = "ID of the private cloud in YC"
  type        = string
}

variable "folder_id" {
  description = "ID of the folder in the private YC cloud"
  type        = string
}

variable "image_id" {
  description = "The id of the compute instance image"
  type        = string
}

variable "image_id_storages" {
  description = "The id of the compute instance image for storage cluster"
  type        = string
}

variable "sa_key_file_path" {
  description = "Path to yc service account key file i.e. '/path/to/key.json'"
  type        = string
}

variable "save_ssh_keys_locally" {
  description = "Save generated SSH key pair locally in ./ansible_rsa"
  type        = bool
  default     = true
}

variable "ssh_private_key_path" {
  description = "Path to ssh private key used to access bastion"
  type        = string
}

variable "zone" {
  description = "Availability zone in YC cloud"
  type        = string
  default     = "ru-central1-a"
}

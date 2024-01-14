variable "ceph" {
  description = "Provide ceph cluster or not"
  type        = bool
  default     = true
}

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

variable "image_id_bastion" {
  description = "The id of the 'bastion jump host' compute instance image"
  default     = "fd88m3uah9t47loeseir"
  type        = string
}

variable "image_id_storages" {
  description = "The id of the compute instance image for storage cluster"
  type        = string
}

variable "masters_qty" {
  description = "Qty of master nodes for k8s cluster. Change to this most probably will break CI"
  type        = number
  default     = 3
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

variable "platform_id" {
  description = "Yandex compute instance platform_id"
  default     = "standard-v2"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to ssh private key used to access bastion"
  type        = string
}

variable "workers_qty" {
  description = "Qty of worker nodes for k8s cluster. Change to this most probably will break CI"
  type        = number
  default     = 3
}

variable "zone" {
  description = "Availability zone in YC cloud"
  type        = string
  default     = "ru-central1-a"
}

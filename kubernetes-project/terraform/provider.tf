provider "yandex" {
  service_account_key_file = file(var.sa_key_file_path)
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

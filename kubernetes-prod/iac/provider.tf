provider "yandex" {
  service_account_key_file = file("/home/anduser/yc-terraform/key.json")
  cloud_id                 = "b1g5gomhkmb5u0t44tkv"
  folder_id                = "b1gjap7i9e06sdcbetb4"
  zone                     = "ru-central1-a"
}

terraform {
  required_version = ">= 1.1.6"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "> 0.90.0"
    }
  }

  backend "s3" {
    endpoint = "storage.yandexcloud.net"
    bucket   = "shamrock004tune-tfstate"
    region   = "ru-central1"
    key      = "iac.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true

    dynamodb_endpoint = "https://docapi.serverless.yandexcloud.net/ru-central1/b1g5gomhkmb5u0t44tkv/etnssbav3m7e6bdvfli8"
    dynamodb_table    = "lock-tfstate"
  }
}

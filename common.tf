// common configuration items

data "ignition_filesystem" "root" {
  name = "root"
  path = "/sysroot"
}

data "ignition_systemd_unit" "update-engine" {
  name = "update-engine.service"
  mask = "${!var.enable_container_linux_update-engine}"
}

data "ignition_systemd_unit" "locksmithd" {
  name = "locksmithd.service"
  mask = "${!var.enable_container_linux_locksmithd}"
}

data "ignition_file" "s3-iam-get" {
  mode       = 0755
  filesystem = "root"
  path       = "/opt/bin/s3-iam-get"

  source {
    source       = "https://raw.githubusercontent.com/kz8s/s3-iam-get/master/s3-iam-get"
    verification = "sha512-e77a8c593fc4b401ea93ecf9a91a8a4b20b57e8c6323156396c7dabec8c95e0cf1677f9e884b76f7730a7ebf4d68534e721cbdfd96a1a169d695cf3e8fbc9735"
  }
}

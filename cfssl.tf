// common items
resource "random_id" "cfssl-auth-key-unused" {
  byte_length = 16
}

resource "random_id" "cfssl-auth-key-client" {
  byte_length = 16
}

resource "random_id" "cfssl-auth-key-apiserver" {
  byte_length = 16
}

data "ignition_systemd_unit" "locksmithd_cfssl" {
  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_cfssl
}

// used by clients
data "template_file" "cfssl-client-config" {
  template = file("${path.module}/resources/cfssl-client-config.json")

  vars = {
    cfssl_server_endpoint = var.cfssl_server_address
    cfssl_auth_key        = random_id.cfssl-auth-key-client.hex
  }
}

data "ignition_file" "cfssl-client-config" {
  mode       = 384
  filesystem = "root"
  path       = "/etc/cfssl/config.json"

  content {
    content = data.template_file.cfssl-client-config.rendered
  }
}

data "template_file" "cfssl-disk-mounter" {
  template = file("${path.module}/resources/disk-mounter.service")

  vars = {
    script_path = "/opt/bin/format-and-mount"
    volume_id   = var.cfssl_data_volumeid
    filesystem  = "ext4"
    user        = "root"
    group       = "root"
    mountpoint  = "/var/lib/cfssl"
  }
}

data "ignition_systemd_unit" "cfssl-disk-mounter" {
  name    = "disk-mounter.service"
  content = data.template_file.cfssl-disk-mounter.rendered
}

data "ignition_file" "cfssl-ca-csr" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/cfssl/ca-csr.json"

  content {
    content = <<EOS
{ "CN": "${var.cfssl_ca_cn}", "key": { "algo": "ecdsa", "size": 521 }, "ca": { "expiry": "${var.cfssl_ca_expiry_hours}h" } }
EOS
  }
}

data "ignition_file" "cfssl-init-ca" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-init-ca"

  content {
    content = file("${path.module}/resources/cfssl-init-ca.sh")
  }
}

data "ignition_file" "cfssl-init-proxy-pki" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-init-proxy-pki"

  content {
    content = file("${path.module}/resources/cfssl-init-proxy-pki")
  }
}

data "ignition_file" "cfssl-proxy-ca-csr-json" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/cfssl/proxy-ca-csr.json"

  content {
    content = file("${path.module}/resources/cfssl-proxy-ca-csr.json")
  }
}

data "ignition_file" "cfssl-proxy-csr-json" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/cfssl/proxy-csr.json"

  content {
    content = file("${path.module}/resources/cfssl-proxy-csr.json")
  }
}

data "template_file" "cfssl-server-config" {
  template = file("${path.module}/resources/cfssl-server-config.json")

  vars = {
    expiry_hours     = var.cfssl_node_expiry_hours
    cfssl_unused_key = random_id.cfssl-auth-key-unused.hex
    cfssl_auth_key   = random_id.cfssl-auth-key-client.hex
  }
}

data "ignition_file" "cfssl-server-config" {
  mode       = 384
  filesystem = "root"
  path       = "/etc/cfssl/config.json"

  content {
    content = data.template_file.cfssl-server-config.rendered
  }
}

data "ignition_systemd_unit" "cfssl" {
  name    = "cfssl.service"
  content = file("${path.module}/resources/cfssl.service")
}

data "ignition_file" "cfssl-sk-csr" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/cfssl/sk-csr.json"

  content {
    content = <<EOS
{ "key": { "algo": "ecdsa", "size": 256 } }
EOS
  }
}

data "ignition_file" "cfssl-nginx-conf" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/cfssl/sk-nginx.conf"

  content {
    content = file("${path.module}/resources/cfssl-nginx.conf")
  }
}

data "ignition_file" "cfssl-nginx-auth" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/cfssl/sk-nginx.htpasswd"

  // it's okay to use PLAIN below since the only thing that this password
  // safeguards is the signing key which is present on the server anyway
  content {
    content = "apiserver:{PLAIN}${random_id.cfssl-auth-key-apiserver.hex}"
  }
}

data "template_file" "cfssl-nginx" {
  template = file("${path.module}/resources/cfssl-nginx.service")

  vars = {
    nginx_image_url = "nginx"
    nginx_image_tag = "1.17-alpine"
  }
}

data "ignition_systemd_unit" "cfssl-nginx" {
  name = "cfssl-nginx.service"

  content = data.template_file.cfssl-nginx.rendered
}

module "cfssl-restarter" {
  source = "./modules/systemd_service_restarter"

  service_name = "cfssl"
  on_calendar  = "*-*-* 00:00:00"
}

data "ignition_config" "cfssl" {
  files = concat(
    [
      data.ignition_file.bashrc.rendered,
      data.ignition_file.cfssl.rendered,
      data.ignition_file.cfssljson.rendered,
      data.ignition_file.cfssl-server-config.rendered,
      data.ignition_file.cfssl-ca-csr.rendered,
      data.ignition_file.cfssl-init-ca.rendered,
      data.ignition_file.cfssl-sk-csr.rendered,
      data.ignition_file.cfssl-init-proxy-pki.rendered,
      data.ignition_file.cfssl-proxy-ca-csr-json.rendered,
      data.ignition_file.cfssl-proxy-csr-json.rendered,
      data.ignition_file.cfssl-nginx-conf.rendered,
      data.ignition_file.cfssl-nginx-auth.rendered,
      data.ignition_file.containerd-config.rendered,
      data.ignition_file.docker-config.rendered,
      data.ignition_file.format-and-mount.rendered,
    ],
    var.cfssl_additional_files
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.update-engine.rendered,
      data.ignition_systemd_unit.locksmithd_cfssl.rendered,
      data.ignition_systemd_unit.docker-opts-dropin.rendered,
      data.ignition_systemd_unit.node-exporter.rendered,
      data.ignition_systemd_unit.cfssl.rendered,
      data.ignition_systemd_unit.cfssl-nginx.rendered,
      data.ignition_systemd_unit.cfssl-disk-mounter.rendered,
      data.ignition_systemd_unit.containerd-dropin.rendered,
    ],
    module.cfssl-restarter.systemd_units,
    var.cfssl_additional_systemd_units
  )

  directories = [
    data.ignition_directory.journald.rendered
  ]
}

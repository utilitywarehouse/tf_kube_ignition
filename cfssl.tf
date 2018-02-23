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
  mask = "${!var.enable_container_linux_locksmithd_cfssl}"
}

// used by clients
data "template_file" "cfssl-client-config" {
  template = "${file("${path.module}/resources/cfssl-client-config.json")}"

  vars {
    cfssl_server_endpoint = "${var.cfssl_server_address}"
    cfssl_auth_key        = "${random_id.cfssl-auth-key-client.hex}"
  }
}

data "ignition_file" "cfssl-client-config" {
  mode       = 0600
  filesystem = "root"
  path       = "/etc/cfssl/config.json"

  content {
    content = "${data.template_file.cfssl-client-config.rendered}"
  }
}

// used by the server
module "cfssl-disk-mounter" {
  source = "./systemd_disk_mounter"

  device     = "xvdf"
  user       = "root"
  group      = "root"
  mountpoint = "/var/lib/cfssl"
}

data "ignition_file" "cfssl-ca-csr" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/cfssl/ca-csr.json"

  content {
    content = <<EOS
{ "CN": "${var.cfssl_ca_cn}", "key": { "algo": "ecdsa", "size": 521 }, "ca": { "expiry": "${var.cfssl_ca_expiry_hours}h" } }
EOS
  }
}

data "ignition_file" "cfssl-init-ca" {
  mode       = 0755
  filesystem = "root"
  path       = "/opt/bin/cfssl-init-ca"

  content {
    content = "${file("${path.module}/resources/cfssl-init-ca.sh")}"
  }
}

data "template_file" "cfssl-server-config" {
  template = "${file("${path.module}/resources/cfssl-server-config.json")}"

  vars {
    expiry_hours     = "${var.cfssl_node_expiry_hours}"
    cfssl_unused_key = "${random_id.cfssl-auth-key-unused.hex}"
    cfssl_auth_key   = "${random_id.cfssl-auth-key-client.hex}"
  }
}

data "ignition_file" "cfssl-server-config" {
  mode       = 0600
  filesystem = "root"
  path       = "/etc/cfssl/config.json"

  content {
    content = "${data.template_file.cfssl-server-config.rendered}"
  }
}

data "ignition_systemd_unit" "cfssl" {
  name    = "cfssl.service"
  content = "${file("${path.module}/resources/cfssl.service")}"
}

data "ignition_file" "cfssl-sk-csr" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/cfssl/sk-csr.json"

  content {
    content = <<EOS
{ "key": { "algo": "ecdsa", "size": 256 } }
EOS
  }
}

data "ignition_file" "cfssl-nginx-conf" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/cfssl/sk-nginx.conf"

  content {
    content = "${file("${path.module}/resources/cfssl-nginx.conf")}"
  }
}

data "ignition_file" "cfssl-nginx-auth" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/cfssl/sk-nginx.htpasswd"

  // it's okay to use PLAIN below since the only thing that this password
  // safeguards is the signing key which is present on the server anyway
  content {
    content = "apiserver:{PLAIN}${random_id.cfssl-auth-key-apiserver.hex}"
  }
}

data "template_file" "cfssl-nginx" {
  template = "${file("${path.module}/resources/cfssl-nginx.service")}"

  vars {
    nginx_image_url = "nginx"
    nginx_image_tag = "1.13-alpine"
  }
}

data "ignition_systemd_unit" "cfssl-nginx" {
  name = "cfssl-nginx.service"

  content = "${data.template_file.cfssl-nginx.rendered}"
}

module "cfssl-restarter" {
  source = "./systemd_service_restarter"

  service_name = "cfssl"
  on_calendar  = "*-*-* 00:00:00"
}

data "ignition_config" "cfssl" {
  files = ["${concat(
    list(
        data.ignition_file.cfssl.id,
        data.ignition_file.cfssljson.id,
        data.ignition_file.cfssl-server-config.id,
        data.ignition_file.cfssl-ca-csr.id,
        data.ignition_file.cfssl-init-ca.id,
        data.ignition_file.cfssl-sk-csr.id,
        data.ignition_file.cfssl-nginx-conf.id,
        data.ignition_file.cfssl-nginx-auth.id,
    ),
    var.cfssl_additional_files,
  )}"]

  systemd = ["${concat(
    list(
        data.ignition_systemd_unit.update-engine.id,
        data.ignition_systemd_unit.locksmithd_cfssl.id,
        data.ignition_systemd_unit.docker-opts-dropin.id,
        data.ignition_systemd_unit.node-exporter.id,
        data.ignition_systemd_unit.cfssl.id,
        data.ignition_systemd_unit.cfssl-nginx.id,
    ),
    module.cfssl-restarter.systemd_units,
    module.cfssl-disk-mounter.systemd_units,
    var.cfssl_additional_systemd_units,
  )}"]
}

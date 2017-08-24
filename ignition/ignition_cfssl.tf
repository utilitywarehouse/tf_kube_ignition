data "ignition_file" "cfssl" {
  filesystem = "root"
  path       = "/opt/bin/cfssl"
  mode       = 0755

  source {
    source       = "https://pkg.cfssl.org/R1.2/cfssl_linux-amd64"
    verification = "sha512-344d58d43aa3948c78eb7e7dafe493c3409f98c73f27cae041c24a7bd14aff07c702d8ab6cdfb15bd6cc55c18b2552f86c5f79a6778f0c277b5e9798d3a38e37"
  }
}

data "ignition_file" "cfssljson" {
  filesystem = "root"
  path       = "/opt/bin/cfssljson"
  mode       = 0755

  source {
    source       = "https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64"
    verification = "sha512-b80f19e61e16244422ad3d877e5a7df5c46b34181d264c9c529db8a8fc2999c6a6f7c1fb2dec63e08d311d6657c8fe05af3186b7ff369a866a47d140d393b49b"
  }
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

resource "random_id" "auth-key-unused" {
  byte_length = 16
}

resource "random_id" "auth-key-client" {
  byte_length = 16
}

data "template_file" "cfssl-server-config" {
  template = "${file("${path.module}/resources/cfssl-server-config.json")}"

  vars {
    expiry_hours     = "${var.cfssl_node_expiry_hours}"
    cfssl_unused_key = "${random_id.auth-key-unused.hex}"
    cfssl_auth_key   = "${random_id.auth-key-client.hex}"
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

data "ignition_config" "cfssl-server" {
  files = [
    "${data.ignition_file.cfssl.id}",
    "${data.ignition_file.cfssljson.id}",
    "${data.ignition_file.cfssl-server-config.id}",
    "${data.ignition_file.cfssl-ca-csr.id}",
    "${data.ignition_file.cfssl-init-ca.id}",
  ]

  systemd = [
    "${data.ignition_systemd_unit.cfssl.id}",
  ]
}

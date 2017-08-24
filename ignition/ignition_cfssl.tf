// common items
resource "random_id" "cfssl-auth-key-unused" {
  byte_length = 16
}

resource "random_id" "cfssl-auth-key-client" {
  byte_length = 16
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

data "ignition_systemd_unit" "cfssl-new-cert" {
  name = "cfssl-new-cert.service"

  content = <<EOS
[Unit]
Description=Generate new certificate
After=network-online.target
Requires=network-online.target
[Service]
Type=oneshot
ExecStart=/opt/bin/cfssl-new-cert
[Install]
WantedBy=multi-user.target
EOS
}

data "ignition_systemd_unit" "cfssl-new-cert-timer" {
  name = "cfssl-new-cert.timer"

  content = <<EOS
[Unit]
Description=Run cfssl-new-cert.service periodically
[Timer]
OnCalendar=${var.cfssl_node_renew_timer}
[Install]
WantedBy=timers.target
EOS
}

// user by the server
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

data "ignition_config" "cfssl" {
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

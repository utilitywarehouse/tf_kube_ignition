data "template_file" "etcd-cfssl-new-cert" {
  template = "${file("${path.module}/resources/cfssl-new-cert.sh")}"

  vars {
    user    = "etcd"
    group   = "etcd"
    role    = "k8s-etcd"
    profile = "client-server"
    path    = "/etc/etcd/ssl"

    hosts = "${join(",", list(
      "etcd.${var.dns_domain}",
      "*.etcd.${var.dns_domain}",
    ))}"
  }
}

data "ignition_file" "etcd-cfssl-new-cert" {
  mode       = 0755
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-cert"

  content {
    content = "${data.template_file.etcd-cfssl-new-cert.rendered}"
  }
}

data "ignition_file" "etcd-prom-machine-role" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/prom-text-collectors/machine_role.prom"

  content {
    content = "machine_role{role=\"etcd\"} 1\n"
  }
}

data "template_file" "etcdctl-wrapper" {
  count    = "${length(var.etcd_addresses)}"
  template = "${file("${path.module}/resources/etcdctl-wrapper")}"

  vars {
    etcd_image_url = "${var.etcd_image_url}"
    etcd_image_tag = "${var.etcd_image_tag}"
    private_ipv4   = "${var.etcd_addresses[count.index]}"
  }
}

data "ignition_file" "etcdctl-wrapper" {
  count      = "${length(var.etcd_addresses)}"
  mode       = 0755
  filesystem = "root"
  uid        = 500
  gid        = 500
  path       = "/home/core/etcdctl-wrapper"

  content {
    content = "${element(data.template_file.etcdctl-wrapper.*.rendered, count.index)}"
  }
}

data "template_file" "etcd-disk-formatter" {
  template = "${file("${path.module}/resources/disk-formatter.service")}"

  vars {
    device = "xvdf"
    user   = "etcd"
  }
}

data "ignition_systemd_unit" "etcd-disk-formatter" {
  name    = "disk-formatter-xvdf.service"
  content = "${data.template_file.etcd-disk-formatter.rendered}"
}

data "template_file" "etcd-disk-mounter" {
  template = "${file("${path.module}/resources/disk-mounter.service")}"

  vars {
    device     = "xvdf"
    mountpoint = "/var/lib/etcd" // influences the unit name below
  }
}

data "ignition_systemd_unit" "etcd-disk-mounter" {
  name    = "var-lib-etcd.mount"
  content = "${data.template_file.etcd-disk-mounter.rendered}"
}

resource "null_resource" "etcd_member" {
  count = "${length(var.etcd_addresses)}"

  triggers {
    index = "${count.index}"
  }
}

data "template_file" "etcd-member-dropin" {
  count    = "${length(var.etcd_addresses)}"
  template = "${file("${path.module}/resources/etcd-member-dropin.conf")}"

  vars {
    etcd_image_url       = "${var.etcd_image_url}"
    etcd_image_tag       = "${var.etcd_image_tag}"
    index                = "${count.index}"
    etcd_initial_cluster = "${join(",", formatlist("member%s=https://%s:2380", null_resource.etcd_member.*.triggers.index, var.etcd_addresses))}"
    private_ipv4         = "${var.etcd_addresses[count.index]}"
  }
}

data "ignition_systemd_unit" "etcd-member-dropin" {
  count = "${length(var.etcd_addresses)}"
  name  = "etcd-member.service"

  dropin {
    name    = "10-custom-options.conf"
    content = "${element(data.template_file.etcd-member-dropin.*.rendered, count.index)}"
  }
}

data "ignition_systemd_unit" "etcd-member-restart" {
  name = "etcd-member-restart.service"

  content = <<EOS
[Unit]
Description=Restart etcd-member.service
[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl try-restart etcd-member.service
EOS
}

data "ignition_systemd_unit" "etcd-member-restart-timer" {
  name = "etcd-member-restart.timer"

  content = <<EOS
[Unit]
Description=Run etcd-member-restart.service periodically
[Timer]
OnCalendar=${var.cfssl_node_renew_timer}
AccuracySec=1s
RandomizedDelaySec=60min
[Install]
WantedBy=timers.target
EOS
}

data "template_file" "etcd-node-exporter" {
  template = "${file("${path.module}/resources/node-exporter.service")}"

  vars {
    node_exporter_image_url = "${var.node_exporter_image_url}"
    node_exporter_image_tag = "${var.node_exporter_image_tag}"
  }
}

data "ignition_systemd_unit" "etcd-node-exporter" {
  name = "node-exporter.service"

  content = "${data.template_file.etcd-node-exporter.rendered}"
}

data "ignition_config" "etcd" {
  count = "${length(var.etcd_addresses)}"

  files = ["${concat(
    list(
        data.ignition_file.cfssl.id,
        data.ignition_file.cfssljson.id,
        data.ignition_file.cfssl-client-config.id,
        data.ignition_file.etcd-cfssl-new-cert.id,
        data.ignition_file.etcd-prom-machine-role.id,
        element(data.ignition_file.etcdctl-wrapper.*.id, count.index),
    ),
    var.etcd_additional_files,
  )}"]

  systemd = ["${concat(
    list(
        data.ignition_systemd_unit.update-engine.id,
        data.ignition_systemd_unit.locksmithd.id,
        data.ignition_systemd_unit.etcd-disk-formatter.id,
        data.ignition_systemd_unit.etcd-disk-mounter.id,
        element(data.ignition_systemd_unit.etcd-member-dropin.*.id, count.index),
        data.ignition_systemd_unit.etcd-member-restart.id,
        data.ignition_systemd_unit.etcd-member-restart-timer.id,
        data.ignition_systemd_unit.etcd-node-exporter.id,
    ),
    var.etcd_additional_systemd_units,
  )}"]
}

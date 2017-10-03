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

module "etcd-disk-mounter" {
  source = "./systemd_disk_mounter"

  device     = "xvdf"
  user       = "etcd"
  group      = "etcd"
  mountpoint = "/var/lib/etcd"
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

module "etcd-member-restarter" {
  source = "./systemd_service_restarter"

  service_name = "etcd-member"
  on_calendar  = "${var.cfssl_node_renew_timer}"
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

data "template_file" "etcd-metrics-proxy" {
  count    = "${length(var.etcd_addresses)}"
  template = "${file("${path.module}/resources/etcd-metrics-proxy.service")}"

  vars {
    etcd_ip = "${var.etcd_addresses[count.index]}"
  }
}

#
# This is a simple go app that exposes the metrics endpoint of etcd on a
# non-authenticated port, to avoid having to pass certificates & keys to
# prometheus. There's a change on etcd that achieves the same without
# the need for an additional service but it's scheduled for version 3.3.
# Until then, we will use this helper service.
#
# NOTE: This service essentially has full access on the data stored in etcd.
# The docker image is built using automated builds in quay.io out from an open
# GitHub repository. If you have reservations, you can always fork the
# repository and build your own images (like we've done).
#
data "ignition_systemd_unit" "etcd-metrics-proxy" {
  count = "${length(var.etcd_addresses)}"
  name  = "etcd-metrics-proxy.service"

  content = "${element(data.template_file.etcd-metrics-proxy.*.rendered, count.index)}"
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
        element(data.ignition_systemd_unit.etcd-member-dropin.*.id, count.index),
        data.ignition_systemd_unit.etcd-node-exporter.id,
        element(data.ignition_systemd_unit.etcd-metrics-proxy.*.id, count.index),
    ),
    module.etcd-disk-mounter.systemd_units,
    module.etcd-member-restarter.systemd_units,
    var.etcd_additional_systemd_units,
  )}"]
}

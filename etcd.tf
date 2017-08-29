data "template_file" "etcd-get-ssl" {
  template = "${file("${path.module}/resources/get-ssl.service")}"

  vars {
    ssl_tar_url      = "s3://${var.ssl_s3_bucket}/certs/k8s-etcd.tar"
    destination_path = "/etc/etcd/ssl/"
  }
}

data "ignition_systemd_unit" "etcd-get-ssl" {
  name    = "get-ssl.service"
  content = "${data.template_file.etcd-get-ssl.rendered}"
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
        data.ignition_file.s3-iam-get.id,
        data.ignition_file.etcd-prom-machine-role.id,
        element(data.ignition_file.etcdctl-wrapper.*.id, count.index),
    ),
    var.etcd_additional_files,
  )}"]

  systemd = ["${concat(
    list(
        data.ignition_systemd_unit.update-engine.id,
        data.ignition_systemd_unit.locksmithd.id,
        data.ignition_systemd_unit.etcd-get-ssl.id,
        data.ignition_systemd_unit.etcd-disk-formatter.id,
        data.ignition_systemd_unit.etcd-disk-mounter.id,
        element(data.ignition_systemd_unit.etcd-member-dropin.*.id, count.index),
        data.ignition_systemd_unit.etcd-node-exporter.id,
    ),
    var.etcd_additional_systemd_units,
  )}"]
}

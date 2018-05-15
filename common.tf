// common configuration items
data "ignition_filesystem" "root" {
  name = "root"
  path = "/sysroot"
}

data "ignition_systemd_unit" "update-engine" {
  name = "update-engine.service"
  mask = "${!var.enable_container_linux_update-engine}"
}

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

module "kubelet-restarter" {
  source = "./systemd_service_restarter"

  service_name = "kubelet"
  on_calendar  = "${var.cfssl_node_renew_timer}"
}

data "ignition_systemd_unit" "docker-opts-dropin" {
  name = "docker.service"

  dropin {
    name    = "10-custom-options.conf"
    content = "${file("${path.module}/resources/docker-dropin.conf")}"
  }
}

data "template_file" "node-exporter" {
  template = "${file("${path.module}/resources/node-exporter.service")}"

  vars {
    node_exporter_image_url = "${var.node_exporter_image_url}"
    node_exporter_image_tag = "${var.node_exporter_image_tag}"
  }
}

data "ignition_systemd_unit" "node-exporter" {
  name = "node-exporter.service"

  content = "${data.template_file.node-exporter.rendered}"
}

data "ignition_file" "format-and-mount" {
  mode       = 0755
  filesystem = "root"
  path       = "/opt/bin/format-and-mount"

  content {
    content = "${file("${path.module}/resources/format-and-mount")}"
  }
}

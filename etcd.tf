data "ignition_systemd_unit" "locksmithd_etcd" {
  name = "locksmithd.service"
  mask = "${!var.enable_container_linux_locksmithd_etcd}"
}

data "template_file" "etcd-cfssl-new-cert" {
  count    = "${length(var.etcd_addresses)}"
  template = "${file("${path.module}/resources/cfssl-new-cert.sh")}"

  vars {
    user    = "etcd"
    group   = "etcd"
    profile = "client-server"
    path    = "/etc/etcd/ssl"
    cn      = "${count.index}.etcd.${var.dns_domain}"
    org     = ""
    get_ip  = "${var.get_ip_command[var.cloud_provider]}"

    extra_names = "${join(",", list(
      "etcd.${var.dns_domain}",
    ))}"
  }
}

data "ignition_file" "etcd-cfssl-new-cert" {
  count      = "${length(var.etcd_addresses)}"
  mode       = 0755
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-cert"

  content {
    content = "${element(data.template_file.etcd-cfssl-new-cert.*.rendered, count.index)}"
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

data "template_file" "disk-formatter" {
  count = "${length(var.etcd_data_volumeids)}"

  template = "${ var.cloud_provider == "aws" ? 
	                 file("${path.module}/resources/aws-disk-formatter.service") 
								:var.cloud_provider == "gce" ?
								   file("${path.module}/resources/gce-disk-formatter.service")
								:""
							}"

  vars {
    volumeid   = "${var.etcd_data_volumeids[count.index]}"
    user       = "etcd"
    group      = "etcd"
    filesystem = "ext4"
  }
}

data "ignition_systemd_unit" "disk-formatter" {
  count   = "${length(var.etcd_data_volumeids)}"
  name    = "disk-formatter.service"
  content = "${element(data.template_file.disk-formatter.*.rendered, count.index)}"
}

data "template_file" "disk-mounter" {
  count = "${length(var.etcd_data_volumeids)}"

  template = "${ var.cloud_provider == "aws" ?  
									file("${path.module}/resources/aws-disk-mounter.mount")
								:var.cloud_provider == "gce" ?
									file("${path.module}/resources/gce-disk-mounter.mount")
								:""
							}"

  vars {
    volumeid       = "${var.etcd_data_volumeids[count.index]}"
    mountpoint     = "/var/lib/etcd"
    filesystem     = "ext4"
    disk-formatter = "disk-formatter.service"
  }
}

data "ignition_systemd_unit" "var-lib-etcd-mounter" {
  count   = "${length(var.etcd_data_volumeids)}"
  name    = "var-lib-etcd.mount"
  content = "${element(data.template_file.disk-mounter.*.rendered, count.index)}"
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

data "ignition_config" "etcd" {
  count = "${length(var.etcd_addresses)}"

  files = ["${concat(
    list(
        data.ignition_file.cfssl.id,
        data.ignition_file.cfssljson.id,
        data.ignition_file.cfssl-client-config.id,
        element(data.ignition_file.etcd-cfssl-new-cert.*.id, count.index),
        data.ignition_file.etcd-prom-machine-role.id,
        element(data.ignition_file.etcdctl-wrapper.*.id, count.index),
    ),
    var.etcd_additional_files,
  )}"]

  systemd = ["${concat(
    list(
        data.ignition_systemd_unit.update-engine.id,
        data.ignition_systemd_unit.locksmithd_etcd.id,
        data.ignition_systemd_unit.docker-opts-dropin.id,
        data.ignition_systemd_unit.node-exporter.id,
        element(data.ignition_systemd_unit.etcd-member-dropin.*.id, count.index),
        element(data.ignition_systemd_unit.disk-formatter.*.id, count.index),
        element(data.ignition_systemd_unit.var-lib-etcd-mounter.*.id, count.index),
    ),
    module.etcd-member-restarter.systemd_units,
    var.etcd_additional_systemd_units,
  )}"]
}

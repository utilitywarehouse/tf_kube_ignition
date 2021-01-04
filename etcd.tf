data "ignition_systemd_unit" "locksmithd_etcd" {
  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_etcd
}

data "template_file" "etcd-cfssl-new-cert" {
  count    = length(var.etcd_addresses)
  template = file("${path.module}/resources/cfssl-new-cert.sh")

  vars = {
    cert_name    = "node"
    user         = "etcd"
    group        = "etcd"
    profile      = "client-server"
    path         = "/etc/etcd/ssl"
    cn           = "${count.index}.etcd.${var.dns_domain}"
    org          = ""
    get_ip       = var.get_ip_command[var.cloud_provider]
    get_hostname = var.node_name_command[var.cloud_provider]
    extra_names  = join(",", ["etcd.${var.dns_domain}"])
  }
}

data "ignition_file" "etcd" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/etcd.tar.gz"

  source {
    source = "https://storage.googleapis.com/etcd/${var.etcd_image_tag}/etcd-${var.etcd_image_tag}-linux-amd64.tar.gz"
  }
}

data "ignition_file" "etcd-cfssl-new-cert" {
  count      = length(var.etcd_addresses)
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-cert"

  content {
    content = element(
      data.template_file.etcd-cfssl-new-cert.*.rendered,
      count.index,
    )
  }
}

data "ignition_file" "etcd-prom-machine-role" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/prom-text-collectors/machine_role.prom"

  content {
    content = "machine_role{role=\"etcd\"} 1\n"
  }
}

data "template_file" "etcdctl-wrapper" {
  count    = length(var.etcd_addresses)
  template = file("${path.module}/resources/etcdctl-wrapper")

  vars = {
    etcd_image_url = var.etcd_image_url
    etcd_image_tag = var.etcd_image_tag
    private_ipv4   = var.etcd_addresses[count.index]
  }
}

data "ignition_file" "etcdctl-wrapper" {
  count      = length(var.etcd_addresses)
  mode       = 493
  filesystem = "root"
  uid        = 500
  gid        = 500
  path       = "/opt/bin/etcdctl-wrapper"

  content {
    content = element(data.template_file.etcdctl-wrapper.*.rendered, count.index)
  }
}

data "template_file" "etcd-disk-mounter" {
  count    = length(var.etcd_addresses)
  template = file("${path.module}/resources/disk-mounter.service")

  vars = {
    script_path = "/opt/bin/format-and-mount"
    volume_id   = var.etcd_data_volumeids[count.index]
    filesystem  = "ext4"
    user        = "etcd"
    group       = "etcd"
    mountpoint  = "/var/lib/etcd"
  }
}

data "ignition_systemd_unit" "etcd-disk-mounter" {
  count   = length(var.etcd_addresses)
  name    = "disk-mounter.service"
  content = data.template_file.etcd-disk-mounter[count.index].rendered
}

resource "null_resource" "etcd_member" {
  count = length(var.etcd_addresses)

  triggers = {
    index = count.index
  }
}

data "template_file" "etcd-member" {
  count    = length(var.etcd_addresses)
  template = file("${path.module}/resources/etcd-member.service")

  vars = {
    etcd_version         = var.etcd_image_tag
    index                = count.index
    etcd_initial_cluster = join(",", formatlist("member%s=https://%s:2380", null_resource.etcd_member.*.triggers.index, var.etcd_addresses))
    private_ipv4         = var.etcd_addresses[count.index]
  }
}

data "ignition_systemd_unit" "etcd-member" {
  count   = length(var.etcd_addresses)
  name    = "etcd-member.service"
  content = element(data.template_file.etcd-member.*.rendered, count.index)
}

module "etcd-cert-fetcher" {
  source = "./modules/cert-fetcher-etcd"

  on_calendar = var.cfssl_node_renew_timer
}

data "ignition_config" "etcd" {
  count = length(var.etcd_addresses)

  files = concat(
    [
      data.ignition_file.cfssl.rendered,
      data.ignition_file.cfssljson.rendered,
      data.ignition_file.cfssl-client-config.rendered,
      data.ignition_file.etcd.rendered,
      element(data.ignition_file.etcd-cfssl-new-cert.*.rendered, count.index),
      data.ignition_file.etcd-prom-machine-role.rendered,
      element(data.ignition_file.etcdctl-wrapper.*.rendered, count.index),
      data.ignition_file.format-and-mount.rendered,
      data.ignition_file.docker-config.rendered,
    ],
    var.etcd_additional_files
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.update-engine.rendered,
      data.ignition_systemd_unit.locksmithd_etcd.rendered,
      data.ignition_systemd_unit.docker-opts-dropin.rendered,
      data.ignition_systemd_unit.node-exporter.rendered,
      element(data.ignition_systemd_unit.etcd-member.*.rendered, count.index),
      element(data.ignition_systemd_unit.etcd-disk-mounter.*.rendered, count.index)
    ],
    module.etcd-cert-fetcher.systemd_units,
    var.etcd_additional_systemd_units
  )

  directories = [
    data.ignition_directory.journald.rendered
  ]
}

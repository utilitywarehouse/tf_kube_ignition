data "ignition_systemd_unit" "locksmithd_etcd" {
  count = length(var.etcd_addresses)

  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_etcd
}

# Create locksmithd dropin configuration as a separate ignition file. This can
# be useful in cases one wants to pass a custom locksmithd service instead of
# the one defined in this module (using `omit_locksmithd_service` variable and
# additional ignition services as input). A variable is provided to control the
# creation of the ignition file: `set_etcd_locksmithd_dropin_reboot_config`
data "ignition_file" "locksmithd_etcd_dropin" {
  count = length(var.etcd_addresses)
  path  = "/etc/systemd/system/locksmithd.service.d/10-custom-options.conf"
  mode  = 420
  content {
    content = templatefile("${path.module}/resources/locksmithd-dropin.conf",
      {
        # Daily update windows, with a 1h buffer to prevent overlaps
        # and give time to react to any problems
        #   etcd-0: 10:00-11:00
        #   < 1h free >
        #   etcd-1: 12:00-13:00
        #   < 1h free >
        #   etcd-2: 14:00-15:00
        reboot_window_start  = formatdate("hh:mm", timeadd("0000-01-01T10:00:00Z", "${count.index * 2}h"))
        reboot_window_length = "1h"
      }
    )
  }
}

data "ignition_file" "etcd-cfssl-new-cert" {
  count = length(var.etcd_addresses)
  mode  = 493 # This is decimal for 0755 octal permissions
  path  = "/opt/bin/cfssl-new-cert"

  content {
    content = templatefile("${path.module}/resources/cfssl-new-cert.sh", {
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
    })
  }
}

data "ignition_file" "etcd" {
  mode = 493
  path = "/opt/bin/etcd.tar.gz"

  source {
    source = "https://storage.googleapis.com/etcd/${var.etcd_image_tag}/etcd-${var.etcd_image_tag}-linux-amd64.tar.gz"
  }
}

data "ignition_file" "etcd-prom-machine-role" {
  mode = 420
  path = "/etc/prom-text-collectors/machine_role.prom"

  content {
    content = "machine_role{role=\"etcd\"} 1\n"
  }
}

data "ignition_file" "etcdctl-wrapper" {
  count = length(var.etcd_addresses)
  mode  = 493 # 0755 in octal
  uid   = 500
  gid   = 500
  path  = "/opt/bin/etcdctl-wrapper"

  content {
    content = templatefile("${path.module}/resources/etcdctl-wrapper", {
      etcd_image_url = var.etcd_image_url
      etcd_image_tag = var.etcd_image_tag
      private_ipv4   = var.etcd_addresses[count.index]
    })
  }
}

data "ignition_systemd_unit" "etcd-disk-mounter" {
  count = length(var.etcd_addresses)
  name  = "disk-mounter.service"

  content = templatefile("${path.module}/resources/disk-mounter.service", {
    script_path = "/opt/bin/format-and-mount"
    volume_id   = var.etcd_data_volumeids[count.index]
    filesystem  = "ext4"
    user        = "etcd"
    group       = "etcd"
    mountpoint  = var.etcd_data_dir
  })
}

resource "null_resource" "etcd_member" {
  count = length(var.etcd_addresses)

  triggers = {
    index = count.index
  }
}

data "ignition_systemd_unit" "etcd-member" {
  count = length(var.etcd_addresses)
  name  = "etcd-member.service"

  content = templatefile("${path.module}/resources/etcd-member.service", {
    etcd_version         = var.etcd_image_tag
    index                = count.index
    etcd_initial_cluster = join(",", formatlist("member%s=https://%s:2380", null_resource.etcd_member.*.triggers.index, var.etcd_addresses))
    private_ipv4         = var.etcd_addresses[count.index]
    etcd_data_dir        = var.etcd_data_dir
  })
}

module "etcd-cert-fetcher" {
  source = "./modules/cert-fetcher-etcd"

  on_calendar = var.cfssl_node_renew_timer
}

data "ignition_systemd_unit" "etcd-defrag" {
  name    = "etcd-defrag.service"
  enabled = false # not enabled because this service is started by etcd-defrag.timer
  content = file("${path.module}/resources/etcd-defrag.service")
}

data "ignition_systemd_unit" "etcd-defrag-timer" {
  name = "etcd-defrag.timer"
  content = templatefile("${path.module}/resources/etcd-defrag.timer", {
    on_calendar = "daily"
  })
}

data "ignition_file" "etcd-restore" {
  count = length(var.etcd_addresses)
  path  = "/opt/bin/etcd-restore"
  mode  = 493

  content {
    content = templatefile("${path.module}/resources/etcd-restore.template", {
      DATA_DIR                    = var.etcd_data_dir
      MEMBER_NAME                 = "member${count.index}"
      INITIAL_CLUSTER             = join(",", formatlist("member%s=https://%s:2380", null_resource.etcd_member.*.triggers.index, var.etcd_addresses))
      INITIAL_ADVERTISE_PEER_URLS = "https://${var.etcd_addresses[count.index]}:2380"
    })
  }
}

data "ignition_file" "etcd-reset" {
  path = "/opt/bin/etcd-reset"
  mode = 493

  content {
    content = file("${path.module}/resources/etcd-reset")
  }
}

data "ignition_config" "etcd" {
  count = length(var.etcd_addresses)

  files = concat(
    [
      data.ignition_file.bashrc.rendered,
      data.ignition_file.cfssl-client-config.rendered,
      data.ignition_file.cfssl.rendered,
      data.ignition_file.cfssljson.rendered,
      data.ignition_file.containerd-config.rendered,
      data.ignition_file.containerd_dockerio_hosts_toml.rendered,
      data.ignition_file.docker-config.rendered,
      data.ignition_file.etcd-prom-machine-role.rendered,
      data.ignition_file.etcd.rendered,
      data.ignition_file.etcd-reset.rendered,
      data.ignition_file.format-and-mount.rendered,
      data.ignition_file.node_textfile_inode_fd_count.rendered,
      data.ignition_file.sysctl_kernel_vars.rendered,
      data.ignition_file.zram_generator_conf.rendered,
      element(data.ignition_file.etcd-cfssl-new-cert.*.rendered, count.index),
      element(data.ignition_file.etcd-restore.*.rendered, count.index),
      element(data.ignition_file.etcdctl-wrapper.*.rendered, count.index),
      var.cloud_provider == "aws" ? data.ignition_file.aws_meta_data_IMDSv2.rendered : "",
      var.set_etcd_locksmithd_dropin_reboot_config ? element(data.ignition_file.locksmithd_etcd_dropin.*.rendered, count.index) : "",
    ],
    var.etcd_additional_files
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.containerd-dropin.rendered,
      data.ignition_systemd_unit.docker-opts-dropin.rendered,
      data.ignition_systemd_unit.etcd-defrag-timer.rendered,
      data.ignition_systemd_unit.etcd-defrag.rendered,
      data.ignition_systemd_unit.node-exporter.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_service.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_timer.rendered,
      element(data.ignition_systemd_unit.etcd-disk-mounter.*.rendered, count.index),
      element(data.ignition_systemd_unit.etcd-member.*.rendered, count.index),
      !var.omit_update_engine_service ? data.ignition_systemd_unit.update-engine.rendered : "",
      !var.omit_locksmithd_service ? element(data.ignition_systemd_unit.locksmithd_etcd.*.rendered, count.index) : "",
    ],
    module.etcd-cert-fetcher.systemd_units,
    var.etcd_additional_systemd_units
  )

  directories = [
    data.ignition_directory.journald.rendered
  ]
}

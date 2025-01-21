data "ignition_systemd_unit" "update-engine" {
  name = "update-engine.service"
  mask = false == var.enable_container_linux_update-engine
}

data "ignition_file" "cfssl" {
  path = "/opt/bin/cfssl"
  mode = 493

  source {
    source       = "https://github.com/cloudflare/cfssl/releases/download/v${var.cfssl_version}/cfssl_${var.cfssl_version}_linux_amd64"
    verification = var.cfssl_binary_sha512
  }
}

data "ignition_file" "cfssljson" {
  path = "/opt/bin/cfssljson"
  mode = 493

  source {
    source       = "https://github.com/cloudflare/cfssl/releases/download/v${var.cfssl_version}/cfssljson_${var.cfssl_version}_linux_amd64"
    verification = var.cfssljson_binary_sha512
  }
}

data "template_file" "docker_opts_dropin" {
  template = file("${path.module}/resources/docker-dropin.conf")
}

data "ignition_systemd_unit" "docker-opts-dropin" {
  name = "docker.service"

  dropin {
    name    = "10-custom-options.conf"
    content = data.template_file.docker_opts_dropin.rendered
  }
}

data "template_file" "node-exporter" {
  template = file("${path.module}/resources/node-exporter.service")

  vars = {
    node_exporter_image_url = var.node_exporter_image_url
    node_exporter_image_tag = var.node_exporter_image_tag
  }
}

data "ignition_systemd_unit" "node-exporter" {
  name = "node-exporter.service"

  content = data.template_file.node-exporter.rendered
}

data "ignition_file" "format-and-mount" {
  mode = 493
  path = "/opt/bin/format-and-mount"

  content {
    content = file("${path.module}/resources/format-and-mount")
  }
}

data "ignition_file" "kubelet" {
  mode = 493
  path = "/opt/bin/kubelet"

  source {
    source = "https://storage.googleapis.com/kubernetes-release/release/${var.kubernetes_version}/bin/linux/amd64/kubelet"
  }
}

# Dir used by systemd to store logs in disk instead of memory
data "ignition_directory" "journald" {
  path = "/var/log/journal"
}

data "ignition_file" "docker_daemon_json" {
  mode = 493
  path = "/etc/docker/daemon.json"

  content {
    content = templatefile("${path.module}/resources/docker_daemon.json",
      {
        dockerhub_mirror_endpoint = var.dockerhub_mirror_endpoint,
      }
    )
  }
}

data "ignition_file" "docker-config" {
  mode = 384
  path = "/root/.docker/config.json"

  content {
    content = jsonencode(
      {
        auths = {
          "https://index.docker.io/v1/" = {
            auth = base64encode("${var.dockerhub_username}:${var.dockerhub_password}")
          }
        }
      }
    )
  }
}

data "ignition_file" "kubelet-docker-config" {
  mode = 384
  path = "/var/lib/kubelet/config.json"

  content {
    content = jsonencode(
      {
        auths = {
          "https://index.docker.io/v1/" = {
            auth = base64encode("${var.dockerhub_username}:${var.dockerhub_password}")
          }
        }
      }
    )
  }
}

data "ignition_file" "containerd_dockerio_hosts_toml" {
  path = "/etc/containerd/certs.d/docker.io/hosts.toml"
  mode = 384
  content {
    content = templatefile("${path.module}/resources/docker.io_hosts.toml",
      {
        dockerhub_mirror_endpoint = var.dockerhub_mirror_endpoint,
        use_mirror                = true
      }
    )
  }
}

data "ignition_file" "containerd-config" {
  path = "/etc/containerd/config.toml"
  mode = 384
  content {
    content = templatefile("${path.module}/resources/containerd-config.toml",
      {
        containerd_log_level = var.containerd_log_level
        dockerhub_username   = var.dockerhub_username
        dockerhub_password   = var.dockerhub_password
      }
    )
  }
}

data "ignition_systemd_unit" "containerd-dropin" {
  name = "containerd.service"

  dropin {
    name    = "10-custom-options.conf"
    content = file("${path.module}/resources/containerd-dropin.conf")
  }
}

data "ignition_file" "crictl-config" {
  path = "/etc/crictl.yaml"
  mode = 384

  content {
    content = file("${path.module}/resources/crictl.yaml")
  }
}

data "ignition_file" "bashrc" {
  path      = "/home/core/.bashrc"
  mode      = 420
  overwrite = true
  uid       = 500 # core
  gid       = 500 # core

  content {
    content = file("${path.module}/resources/bashrc")
  }
}

data "ignition_file" "kubernetes_accounting_config" {
  path = "/etc/systemd/system.conf.d/kubernetes-accounting.conf"
  content {
    content = file("${path.module}/resources/kubernetes-accounting.conf")
  }
}

# Use the values from "zram-generator-defaults"
data "ignition_file" "zram_generator_conf" {
  mode = 420
  path = "/etc/systemd/zram-generator.conf"

  content {
    content = <<EOF
[zram0]
zram-size = min(ram, 8192)
EOF
  }
}

# Updating to flatcar 2983.2.0 surfaced an issue where inotify resources are
# exhausted on worker nodes. Increasing inotify watchers and instances was
# tested to mitigate this issue. Using values from:
# https://github.com/giantswarm/k8scloudconfig/blob/master/files/conf/hardening.conf
# Same approach also mentioned here:
# https://github.com/kubernetes/kubernetes/issues/64315#issuecomment-904103310
#
# vm.max_map_count=1048576 :: higher value is needed by Partner Kafka, but also
# matching Fedora + Arch Linux upstream:
# - https://fedoraproject.org/wiki/Changes/IncreaseVmMaxMapCount
# - https://archlinux.org/news/increasing-the-default-vmmax_map_count-value/
data "ignition_file" "sysctl_kernel_vars" {
  mode = 420
  path = "/etc/sysctl.d/kernel.conf"

  content {
    content = <<EOS
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=8192
vm.max_map_count=1048576
user.max_user_namespaces=0
EOS
  }
}

# `touch` /boot/flatcar/first_boot to trigger ignition to run every time:
# https://flatcar-linux.org/docs/latest/provisioning/ignition/boot-process/#reprovisioning
# Useful when we want to fetch ignition updates during boot.
data "ignition_systemd_unit" "flatcar_first_boot" {
  name    = "ensure-flatcar-first-boot.service"
  content = <<EOS
[Unit]
Description=touch /boot/flatcar/first_boot to trigger new ignition run on reboot

[Service]
Type=oneshot
ExecStart=/usr/bin/touch /boot/flatcar/first_boot
RemainAfterExit=true
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOS
}

# Specifies a root filesystem where we wipe the device before filesystem
# creation. When combined with ignition reprovisioning it can give us "fresh"
# nodes on reboot.
data "ignition_filesystem" "root_wipe_filesystem" {
  device          = "/dev/disk/by-partlabel/ROOT"
  format          = "ext4"
  wipe_filesystem = true
  label           = "ROOT"
}

data "ignition_file" "aws_meta_data_IMDSv2" {
  mode = 493
  path = "/opt/bin/aws-imdsv2"

  content {
    content = <<EOS
#!/bin/sh
META_ENDPOINT=$1
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 600")
curl http://169.254.169.254/latest/meta-data/$META_ENDPOINT -H "X-aws-ec2-metadata-token: $TOKEN"
EOS
  }
}

data "ignition_systemd_unit" "coreos_metadata_sshkeys" {
  name = "coreos-metadata-sshkeys@core.service"
  mask = false == var.enable_coreos_metadata_sshkeys_service
}

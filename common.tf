data "ignition_systemd_unit" "update-engine" {
  name = "update-engine.service"
  mask = false == var.enable_container_linux_update-engine
}

data "ignition_file" "cfssl" {
  path = "/opt/bin/cfssl"
  mode = 493

  source {
    source       = "https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssl_1.4.1_linux_amd64"
    verification = "sha512-a3efc1690872be4e71d8edc2f4dbf0085c64e9691eaff0aece176504766ae81176828cd783681634d1262ecc1e079707129261279f98453b654b202feeb4b467"
  }
}

data "ignition_file" "cfssljson" {
  path = "/opt/bin/cfssljson"
  mode = 493

  source {
    source       = "https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssljson_1.4.1_linux_amd64"
    verification = "sha512-a81592c6876c9a0ed480d64b8347b7da2af7047cdf7522f47e808e64efe8635f94826350b11d129c0b22b224517a6c99622d9ceea86e79c476196c3c9333f3fe"
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

data "ignition_file" "containerd-config" {
  path = "/etc/containerd/config.toml"
  mode = 384
  content {
    content = templatefile("${path.module}/resources/containerd-config.toml",
      {
        containerd_log_level      = var.containerd_log_level
        containerd_no_shim        = tostring(var.containerd_no_shim)
        dockerhub_auth            = base64encode("${var.dockerhub_username}:${var.dockerhub_password}"),
        dockerhub_mirror_endpoint = var.dockerhub_mirror_endpoint,
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

data "ignition_file" "crictl" {
  mode = 420
  path = "/opt/crictl.tar.gz"

  source {
    source       = "https://github.com/kubernetes-sigs/cri-tools/releases/download/${var.crictl_version}/crictl-${var.crictl_version}-linux-amd64.tar.gz"
    verification = var.crictl_verification
  }
}

data "ignition_systemd_unit" "prepare-crictl" {
  name = "prepare-crictl.service"

  content = file("${path.module}/resources/prepare-crictl.service")
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

# Updating to flatcar 2983.2.0 surfaced an issue where inotify resources are
# exhausted on worker nodes. Increasing inotify watchers and instances was
# tested to mitigate this issue. Using values from:
# https://github.com/giantswarm/k8scloudconfig/blob/master/files/conf/hardening.conf
# Same approach also mentioned here:
# https://github.com/kubernetes/kubernetes/issues/64315#issuecomment-904103310
#
# vm.max_map_count=524288 adjusted for partner kafkas, which exceeded the
# previous limit.
data "ignition_file" "sysctl_kernel_vars" {
  mode = 420
  path = "/etc/sysctl.d/kernel.conf"

  content {
    content = <<EOS
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=8192
vm.max_map_count=524288
user.max_user_namespaces=0
EOS
  }
}

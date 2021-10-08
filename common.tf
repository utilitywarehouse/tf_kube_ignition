data "ignition_systemd_unit" "update-engine" {
  name = "update-engine.service"
  mask = false == var.enable_container_linux_update-engine
}

data "ignition_file" "cfssl" {
  filesystem = "root"
  path       = "/opt/bin/cfssl"
  mode       = 493

  source {
    source       = "https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssl_1.4.1_linux_amd64"
    verification = "sha512-a3efc1690872be4e71d8edc2f4dbf0085c64e9691eaff0aece176504766ae81176828cd783681634d1262ecc1e079707129261279f98453b654b202feeb4b467"
  }
}

data "ignition_file" "cfssljson" {
  filesystem = "root"
  path       = "/opt/bin/cfssljson"
  mode       = 493

  source {
    source       = "https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssljson_1.4.1_linux_amd64"
    verification = "sha512-a81592c6876c9a0ed480d64b8347b7da2af7047cdf7522f47e808e64efe8635f94826350b11d129c0b22b224517a6c99622d9ceea86e79c476196c3c9333f3fe"
  }
}

data "ignition_systemd_unit" "docker-opts-dropin" {
  name = "docker.service"

  dropin {
    name    = "10-custom-options.conf"
    content = file("${path.module}/resources/docker-dropin.conf")
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
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/format-and-mount"

  content {
    content = file("${path.module}/resources/format-and-mount")
  }
}

data "ignition_file" "kubelet" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/kubelet"

  source {
    source = "https://storage.googleapis.com/kubernetes-release/release/${var.kubernetes_version}/bin/linux/amd64/kubelet"
  }
}

# Dir used by systemd to store logs in disk instead of memory
data "ignition_directory" "journald" {
  filesystem = "root"
  path       = "/var/log/journal"
}

data "ignition_file" "docker_daemon_json" {
  mode       = 493
  filesystem = "root"
  path       = "/etc/docker/daemon.json"

  content {
    content = templatefile("${path.module}/resources/docker_daemon.json",
      {
        dockerhub_mirror_endpoint = var.dockerhub_mirror_endpoint,
      }
    )
  }
}

data "ignition_file" "docker-config" {
  mode       = 384
  filesystem = "root"
  path       = "/root/.docker/config.json"

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
  mode       = 384
  filesystem = "root"
  path       = "/var/lib/kubelet/config.json"

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
  filesystem = "root"
  path       = "/etc/containerd/config.toml"
  mode       = 384
  content {
    content = templatefile("${path.module}/resources/containerd-config.toml",
      {
        dockerhub_mirror_endpoint = var.dockerhub_mirror_endpoint,
        dockerhub_auth            = base64encode("${var.dockerhub_username}:${var.dockerhub_password}"),
        containerd_log_level      = var.containerd_log_level
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
  mode       = 420
  filesystem = "root"
  path       = "/opt/crictl.tar.gz"

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
  filesystem = "root"
  path       = "/etc/crictl.yaml"
  mode       = 384

  content {
    content = file("${path.module}/resources/crictl.yaml")
  }
}

data "ignition_file" "bashrc" {
  filesystem = "root"
  path       = "/home/core/.bashrc"
  mode       = 420
  uid        = 500 # core
  gid        = 500 # core

  content {
    content = file("${path.module}/resources/bashrc")
  }
}

data "ignition_systemd_unit" "fstrim_dropin" {
  name = "fstrim.service"

  dropin {
    name    = "10-all_mounted_fs.conf"
    content = file("${path.module}/resources/fstrim.conf")
  }
}

data "ignition_systemd_unit" "fstrim_timer" {
  name = "fstrim.timer"
}

data "ignition_systemd_unit" "locksmithd_worker" {
  name = "locksmithd.service"
  mask = "${!var.enable_container_linux_locksmithd_worker}"
}

// All nodes should belong to system:nodes group
data "template_file" "worker-cfssl-new-cert" {
  template = "${file("${path.module}/resources/cfssl-new-cert.sh")}"

  vars {
    cert_name   = "node"
    user        = "root"
    group       = "root"
    profile     = "client"
    path        = "/etc/kubernetes/ssl"
    cn          = "system:node:$(${var.node_name_command[var.cloud_provider]})"
    org         = "system:nodes"
    get_ip      = "${var.get_ip_command[var.cloud_provider]}"
    extra_names = ""
  }
}

data "ignition_file" "worker-cfssl-new-cert" {
  mode       = 0755
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-cert"

  content {
    content = "${data.template_file.worker-cfssl-new-cert.rendered}"
  }
}

data "template_file" "worker-kubelet" {
  template = "${file("${path.module}/resources/worker-kubelet.service")}"

  vars {
    kubelet_image_url = "${var.hyperkube_image_url}"
    kubelet_image_tag = "${var.hyperkube_image_tag}"
    cloud_provider    = "${var.cloud_provider}"
    role              = "worker"
  }
}

data "ignition_systemd_unit" "worker-kubelet" {
  name    = "kubelet.service"
  content = "${data.template_file.worker-kubelet.rendered}"
}

data "template_file" "worker-kubelet-conf" {
  template = "${file("${path.module}/resources/worker-kubelet-conf.yaml")}"

  vars {
    cluster_dns   = "${local.cluster_dns_yaml}"
    feature_gates = "${local.feature_gates_yaml_fragment}"
  }
}

data "ignition_file" "worker-kubelet-conf" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/kubernetes/config/worker-kubelet-conf.yaml"

  content {
    content = "${data.template_file.worker-kubelet-conf.rendered}"
  }
}

data "template_file" "worker-kubeconfig" {
  template = "${file("${path.module}/resources/worker-kubeconfig")}"

  vars {
    master_address = "${var.master_address}"
  }
}

data "ignition_file" "worker-kubeconfig" {
  mode       = 0644
  filesystem = "root"
  path       = "/var/lib/kubelet/kubeconfig"

  content {
    content = "${data.template_file.worker-kubeconfig.rendered}"
  }
}

data "ignition_file" "worker-sysctl-vm" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/sysctl.d/vm.conf"

  content {
    content = "vm.max_map_count=262144"
  }
}

data "template_file" "prometheus-tmpfs-dir" {
  template = "${file("${path.module}/resources/prometheus-tmpfs-dir.service")}"
}

data "ignition_systemd_unit" "prometheus-tmpfs-dir" {
  name    = "prometheus-tmpfs-dir.service"
  content = "${data.template_file.prometheus-tmpfs-dir.rendered}"
}

data "template_file" "prometheus-machine-role" {
  template = "${file("${path.module}/resources/prometheus-machine-role.service")}"

  vars {
    role = "worker"
  }
}

data "ignition_systemd_unit" "prometheus-machine-role" {
  name    = "prometheus-machine-role.service"
  content = "${data.template_file.prometheus-machine-role.rendered}"
}

data "template_file" "prometheus-ro-rootfs" {
  template = "${file("${path.module}/resources/prometheus-ro-rootfs.service")}"
}

data "ignition_systemd_unit" "prometheus-ro-rootfs" {
  name    = "prometheus-ro-rootfs.service"
  content = "${data.template_file.prometheus-ro-rootfs.rendered}"
}

data "template_file" "prometheus-ro-rootfs-timer" {
  template = "${file("${path.module}/resources/prometheus-ro-rootfs.timer")}"
}

data "ignition_systemd_unit" "prometheus-ro-rootfs-timer" {
  name    = "prometheus-ro-rootfs.timer"
  content = "${data.template_file.prometheus-ro-rootfs-timer.rendered}"
}

data "ignition_file" "prometheus-ro-rootfs" {
  mode       = 0755
  filesystem = "root"
  path       = "/opt/bin/prometheus-ro-rootfs"

  content {
    content = "${file("${path.module}/resources/prometheus-ro-rootfs")}"
  }
}

data "ignition_file" "containerd-config" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/containerd/config.toml"

  content {
    content = "${file("${path.module}/resources/containerd-config.toml")}"
  }
}

data "ignition_config" "worker" {
  files = ["${concat(
    list(
        data.ignition_file.cfssl.id,
        data.ignition_file.cfssljson.id,
        data.ignition_file.cfssl-client-config.id,
        data.ignition_file.containerd-config.id,
        data.ignition_file.crictl-config.id,
        data.ignition_file.install-crictl.id,
        data.ignition_file.worker-cfssl-new-cert.id,
        data.ignition_file.worker-kubeconfig.id,
        data.ignition_file.worker-sysctl-vm.id,
        data.ignition_file.worker-kubelet-conf.id,
        data.ignition_file.prometheus-ro-rootfs.id,
    ),
    var.worker_additional_files
  )}"]

  systemd = ["${concat(
    list(
        data.ignition_systemd_unit.update-engine.id,
        data.ignition_systemd_unit.locksmithd_worker.id,
        data.ignition_systemd_unit.docker-opts-dropin.id,
        data.ignition_systemd_unit.containerd-opts-dropin.id,
        data.ignition_systemd_unit.worker-kubelet.id,
        data.ignition_systemd_unit.prometheus-tmpfs-dir.id,
        data.ignition_systemd_unit.prometheus-machine-role.id,
        data.ignition_systemd_unit.prometheus-ro-rootfs.id,
        data.ignition_systemd_unit.prometheus-ro-rootfs-timer.id,
        data.ignition_systemd_unit.install-crictl.id,
    ),
    module.kubelet-restarter.systemd_units,
    var.worker_additional_systemd_units
  )}"]
}

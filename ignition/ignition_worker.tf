data "template_file" "worker-get-ssl" {
  template = "${file("${path.module}/resources/get-ssl.service")}"

  vars {
    ssl_tar_url      = "s3://${var.ssl_s3_bucket}/certs/k8s-worker.tar"
    destination_path = "/etc/kubernetes/ssl/"
  }
}

data "ignition_systemd_unit" "worker-get-ssl" {
  name    = "get-ssl.service"
  content = "${data.template_file.worker-get-ssl.rendered}"
}

data "template_file" "worker-kubelet" {
  template = "${file("${path.module}/resources/worker-kubelet.service")}"

  vars {
    kubelet_image_url = "${var.hyperkube_image_url}"
    kubelet_image_tag = "${var.hyperkube_image_tag}"
    cluster_dns       = "${var.cluster_dns}"
    cloud_provider    = "${var.cloud_provider}"
    role              = "worker"
  }
}

data "ignition_systemd_unit" "worker-kubelet" {
  name    = "kubelet.service"
  content = "${data.template_file.worker-kubelet.rendered}"
}

data "template_file" "worker-kube-proxy" {
  template = "${file("${path.module}/resources/worker-kube-proxy.yaml")}"

  vars {
    hyperkube_image_url = "${var.hyperkube_image_url}"
    hyperkube_image_tag = "${var.hyperkube_image_tag}"
    master_address      = "${var.master_address}"
  }
}

data "ignition_file" "worker-kube-proxy" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-proxy.yaml"

  content {
    content = "${data.template_file.worker-kube-proxy.rendered}"
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

data "ignition_file" "worker-prom-machine-role" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/prom-text-collectors/machine_role.prom"

  content {
    content = "machine_role{role=\"worker\"} 1\n"
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

data "ignition_config" "worker" {
  files = [
    "${data.ignition_file.s3-iam-get.id}",
    "${data.ignition_file.worker-prom-machine-role.id}",
    "${data.ignition_file.worker-kubeconfig.id}",
    "${data.ignition_file.worker-kube-proxy.id}",
    "${data.ignition_file.worker-sysctl-vm.id}",
  ]

  systemd = [
    "${data.ignition_systemd_unit.update-engine.id}",
    "${data.ignition_systemd_unit.locksmithd.id}",
    "${data.ignition_systemd_unit.worker-get-ssl.id}",
    "${data.ignition_systemd_unit.worker-kubelet.id}",
  ]
}

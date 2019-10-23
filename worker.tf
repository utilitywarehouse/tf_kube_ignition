data "ignition_systemd_unit" "locksmithd_worker" {
  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_worker
}

data "template_file" "worker-kubelet" {
  template = file("${path.module}/resources/node-kubelet.service")

  vars = {
    kubelet_binary_path = "/opt/bin/kubelet"
    cloud_provider      = var.cloud_provider
    labels              = "role=worker"
    taints              = ""
  }
}

data "ignition_systemd_unit" "worker-kubelet" {
  name    = "kubelet.service"
  content = data.template_file.worker-kubelet.rendered
}

// Prometheus machine-role metric
data "template_file" "prometheus-machine-role-worker" {
  template = file("${path.module}/resources/prometheus-machine-role.service")

  vars = {
    role = "worker"
  }
}

data "ignition_systemd_unit" "prometheus-machine-role-worker" {
  name    = "prometheus-machine-role.service"
  content = data.template_file.prometheus-machine-role-worker.rendered
}


// data.ignition_file.worker-prom-machine-role.id,
data "ignition_config" "worker" {
  files = concat(
    [
      data.ignition_file.cfssl.id,
      data.ignition_file.cfssljson.id,
      data.ignition_file.cfssl-client-config.id,
      data.ignition_file.node-cfssl-new-cert.id,
      data.ignition_file.kubelet-cfssl-new-cert.id,
      data.ignition_file.kubelet.id,
      data.ignition_file.node-kubeconfig.id,
      data.ignition_file.node-sysctl-vm.id,
      data.ignition_file.node-kubelet-conf.id,
      data.ignition_file.prometheus-ro-rootfs.id,
    ],
    var.worker_additional_files
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.update-engine.id,
      data.ignition_systemd_unit.locksmithd_worker.id,
      data.ignition_systemd_unit.docker-opts-dropin.id,
      data.ignition_systemd_unit.worker-kubelet.id,
      data.ignition_systemd_unit.prometheus-tmpfs-dir.id,
      data.ignition_systemd_unit.prometheus-machine-role-worker.id,
      data.ignition_systemd_unit.prometheus-ro-rootfs.id,
      data.ignition_systemd_unit.prometheus-ro-rootfs-timer.id,
    ],
    module.kubelet-restarter.systemd_units,
    var.worker_additional_systemd_units
  )
}

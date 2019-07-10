data "template_file" "storage-worker-kubelet" {
  template = file("${path.module}/resources/worker-kubelet.service")

  vars = {
    kubelet_image_url = var.hyperkube_image_url
    kubelet_image_tag = var.hyperkube_image_tag
    cloud_provider    = var.cloud_provider
    role              = "storage-worker"
    taints            = "key=value:NoSchedule"
  }
}

data "ignition_systemd_unit" "storage-worker-kubelet" {
  name    = "kubelet.service"
  content = data.template_file.storage-worker-kubelet.rendered
}

data "ignition_config" "storage-worker" {

  files = concat(
    [
      data.ignition_file.cfssl.id,
      data.ignition_file.cfssljson.id,
      data.ignition_file.cfssl-client-config.id,
      data.ignition_file.worker-cfssl-new-cert.id,
      data.ignition_file.worker-kubeconfig.id,
      data.ignition_file.worker-sysctl-vm.id,
      data.ignition_file.worker-kubelet-conf.id,
      data.ignition_file.prometheus-ro-rootfs.id,
    ],
    var.worker_additional_files
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.update-engine.id,
      data.ignition_systemd_unit.locksmithd_worker.id,
      data.ignition_systemd_unit.docker-opts-dropin.id,
      data.ignition_systemd_unit.storage-worker-kubelet.id,
      data.ignition_systemd_unit.prometheus-tmpfs-dir.id,
      data.ignition_systemd_unit.prometheus-machine-role.id,
      data.ignition_systemd_unit.prometheus-ro-rootfs.id,
      data.ignition_systemd_unit.prometheus-ro-rootfs-timer.id,
    ],
    module.kubelet-restarter.systemd_units,
    var.worker_additional_systemd_units
  )
}


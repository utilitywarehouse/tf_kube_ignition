data "ignition_systemd_unit" "locksmithd_storage_node" {
  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_storage_node
}

data "template_file" "storage-node-kubelet" {
  template = file("${path.module}/resources/node-kubelet.service")

  vars = {
    kubelet_binary_path = "/opt/bin/kubelet"
    cloud_provider      = var.cloud_provider
    labels              = "role=storage-node,node.longhorn.io/create-default-disk=true"
    taints              = "storage=longhorn:NoSchedule"
  }
}

data "ignition_systemd_unit" "storage-node-kubelet" {
  name    = "kubelet.service"
  content = data.template_file.storage-node-kubelet.rendered
}

data "template_file" "storage-node-disk-mounter" {
  template = file("${path.module}/resources/disk-mounter.service")

  vars = {
    script_path = "/opt/bin/format-and-mount"
    volume_id   = var.storage_node_volumeid
    filesystem  = "ext4"
    user        = "storage-node"
    group       = "storage-node"
    mountpoint  = "/var/lib/storage"
  }
}

data "ignition_systemd_unit" "storage-node-disk-mounter" {
  name    = "disk-mounter.service"
  content = data.template_file.storage-node-disk-mounter.rendered
}

// Prometheus machine-role metric
data "template_file" "prometheus-machine-role-storage-node" {
  template = file("${path.module}/resources/prometheus-machine-role.service")

  vars = {
    role = "storage-node"
  }
}

data "ignition_systemd_unit" "prometheus-machine-role-storage-node" {
  name    = "prometheus-machine-role.service"
  content = data.template_file.prometheus-machine-role-storage-node.rendered
}

data "ignition_config" "storage-node" {
  files = concat(
    [
      data.ignition_file.cfssl.id,
      data.ignition_file.cfssljson.id,
      data.ignition_file.cfssl-client-config.id,
      data.ignition_file.format-and-mount.id,
      data.ignition_file.kubelet.id,
      data.ignition_file.node-cfssl-new-cert.id,
      data.ignition_file.node-cfssl-new-kubelet-cert.id,
      data.ignition_file.node-sysctl-vm.id,
      data.ignition_file.node-kubeconfig.id,
      data.ignition_file.node-kubelet-conf.id,
      data.ignition_file.prometheus-ro-rootfs.id,
    ],
    var.storage_node_additional_files
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.update-engine.id,
      data.ignition_systemd_unit.locksmithd_storage_node.id,
      data.ignition_systemd_unit.docker-opts-dropin.id,
      data.ignition_systemd_unit.storage-node-kubelet.id,
      data.ignition_systemd_unit.prometheus-tmpfs-dir.id,
      data.ignition_systemd_unit.prometheus-machine-role-storage-node.id,
      data.ignition_systemd_unit.prometheus-ro-rootfs.id,
      data.ignition_systemd_unit.prometheus-ro-rootfs-timer.id,
      data.ignition_systemd_unit.storage-node-disk-mounter.id,
    ],
    module.kubelet-restarter.systemd_units,
    var.storage_node_additional_systemd_units
  )
}

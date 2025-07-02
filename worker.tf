data "ignition_systemd_unit" "locksmithd_worker" {
  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_worker
}

data "ignition_systemd_unit" "worker-kubelet" {
  name = "kubelet.service"
  content = templatefile("${path.module}/resources/node-kubelet.service", {
    kubelet_binary_path = "/opt/bin/kubelet"
    cloud_provider      = local.component_cloud_provider
    get_hostname        = var.node_name_command[var.cloud_provider]
    labels              = local.worker_kubelet_labels
  })
}

// Prometheus machine-role metric
data "ignition_systemd_unit" "prometheus-machine-role-worker" {
  name = "prometheus-machine-role.service"
  content = templatefile("${path.module}/resources/prometheus-machine-role.service", {
    role = "worker"
  })
}

data "ignition_systemd_unit" "prometheus-eviction-threshold-worker" {
  name = "prometheus-eviction-threshold.service"
  content = templatefile("${path.module}/resources/prometheus-eviction-threshold.service",
    {
      value = var.eviction_threshold_memory_soft > var.eviction_threshold_memory_hard ? var.eviction_threshold_memory_soft : var.eviction_threshold_memory_hard
    }
  )
}

// data.ignition_file.worker-prom-machine-role.rendered,
data "ignition_config" "worker" {
  filesystems = [
    var.force_boot_reprovisioning ? data.ignition_filesystem.root_wipe_filesystem.rendered : "",
  ]

  files = concat(
    [
      data.ignition_file.bashrc.rendered,
      data.ignition_file.cfssl-client-config.rendered,
      data.ignition_file.cfssl.rendered,
      data.ignition_file.cfssljson.rendered,
      data.ignition_file.containerd-config.rendered,
      data.ignition_file.containerd_dockerio_hosts_toml.rendered,
      data.ignition_file.crictl-config.rendered,
      data.ignition_file.docker-config.rendered,
      data.ignition_file.docker_daemon_json.rendered,
      data.ignition_file.kubelet-docker-config.rendered,
      data.ignition_file.kubelet.rendered,
      data.ignition_file.kubernetes_accounting_config.rendered,
      data.ignition_file.node-cfssl-new-cert.rendered,
      data.ignition_file.node-kubeconfig.rendered,
      data.ignition_file.node-kubelet-cfssl-new-cert.rendered,
      data.ignition_file.node-kubelet-conf.rendered,
      data.ignition_file.node_textfile_inode_fd_count.rendered,
      data.ignition_file.sysctl_kernel_vars.rendered,
      data.ignition_file.zram_generator_conf.rendered,
      var.cloud_provider == "aws" ? data.ignition_file.aws_meta_data_IMDSv2.rendered : "",
    ],
    var.worker_additional_files
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.containerd-dropin.rendered,
      data.ignition_systemd_unit.coreos_metadata_sshkeys.rendered,
      data.ignition_systemd_unit.docker-opts-dropin.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_service.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_timer.rendered,
      data.ignition_systemd_unit.prometheus-eviction-threshold-worker.rendered,
      data.ignition_systemd_unit.prometheus-machine-role-worker.rendered,
      data.ignition_systemd_unit.prometheus-tmpfs-dir.rendered,
      data.ignition_systemd_unit.worker-kubelet.rendered,
      !var.omit_locksmithd_service ? data.ignition_systemd_unit.locksmithd_worker.rendered : "",
      !var.omit_update_engine_service ? data.ignition_systemd_unit.update-engine.rendered : "",
      var.force_boot_reprovisioning ? data.ignition_systemd_unit.flatcar_first_boot.rendered : "",
    ],
    module.cert-refresh-node.systemd_units,
    var.worker_additional_systemd_units
  )

  directories = [
    data.ignition_directory.journald.rendered
  ]
}

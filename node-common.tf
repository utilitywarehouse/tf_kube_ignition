// All nodes should belong to system:nodes group
data "template_file" "node-cfssl-new-cert" {
  template = file("${path.module}/resources/cfssl-new-cert.sh")

  vars = {
    cert_name    = "node"
    user         = "root"
    group        = "root"
    profile      = "client"
    path         = "/etc/kubernetes/ssl"
    cn           = "system:node:$(${var.node_name_command[var.cloud_provider]})"
    org          = "system:nodes"
    get_ip       = var.get_ip_command[var.cloud_provider]
    get_hostname = var.node_name_command[var.cloud_provider]
    extra_names  = ""
  }
}

data "ignition_file" "node-cfssl-new-cert" {
  mode       = 493
  path       = "/opt/bin/cfssl-new-cert"

  content {
    content = data.template_file.node-cfssl-new-cert.rendered
  }
}

// Get a cert for to kubelet serve
data "template_file" "node-kubelet-cfssl-new-cert" {
  template = file("${path.module}/resources/cfssl-new-cert.sh")

  vars = {
    cert_name    = "kubelet"
    user         = "root"
    group        = "root"
    profile      = "client-server"
    path         = "/etc/kubernetes/ssl"
    cn           = "system:kubelet:$(${var.node_name_command[var.cloud_provider]})"
    org          = "system:kubelets"
    get_ip       = var.get_ip_command[var.cloud_provider]
    get_hostname = var.node_name_command[var.cloud_provider]
    extra_names  = ""
  }
}

data "ignition_file" "node-kubelet-cfssl-new-cert" {
  mode       = 493
  path       = "/opt/bin/cfssl-new-kubelet-cert"

  content {
    content = data.template_file.node-kubelet-cfssl-new-cert.rendered
  }
}

// Kubeconfig will be the same for all kubernetes nodes as it only
// contains master address and certs
data "template_file" "node-kubeconfig" {
  template = file("${path.module}/resources/node-kubeconfig")

  vars = {
    master_address = var.master_address
  }
}

data "ignition_file" "node-kubeconfig" {
  mode       = 420
  path       = "/var/lib/kubelet/kubeconfig"

  content {
    content = data.template_file.node-kubeconfig.rendered
  }
}

// Kubelet config
data "template_file" "node-kubelet-conf" {
  template = file("${path.module}/resources/node-kubelet-conf.yaml")

  vars = {
    cluster_dns                       = local.cluster_dns_yaml
    feature_gates                     = local.feature_gates_yaml_fragment
    kubelet_cgroup_v2_runtime_enabled = var.kubelet_cgroup_v2_runtime_enabled
    system_reserved_cpu               = var.system_reserved_cpu
    system_reserved_memory            = var.system_reserved_memory
    use_deprecated_docker_runtime     = var.use_deprecated_docker_runtime
  }
}

data "ignition_file" "node-kubelet-conf" {
  mode       = 420
  path       = "/etc/kubernetes/config/node-kubelet-conf.yaml"

  content {
    content = data.template_file.node-kubelet-conf.rendered
  }
}

// Common prometheus text-collector metrics for nodes
data "template_file" "prometheus-tmpfs-dir" {
  template = file("${path.module}/resources/prometheus-tmpfs-dir.service")
}

data "ignition_systemd_unit" "prometheus-tmpfs-dir" {
  name    = "prometheus-tmpfs-dir.service"
  enabled = false # not enabled because this service is started by prometheus-ro-rootfs.timer
  content = data.template_file.prometheus-tmpfs-dir.rendered
}

data "template_file" "prometheus-ro-rootfs" {
  template = file("${path.module}/resources/prometheus-ro-rootfs.service")
}

data "ignition_systemd_unit" "prometheus-ro-rootfs" {
  name    = "prometheus-ro-rootfs.service"
  enabled = false # not enabled because this service is started by prometheus-ro-rootfs.timer
  content = data.template_file.prometheus-ro-rootfs.rendered
}

data "template_file" "prometheus-ro-rootfs-timer" {
  template = file("${path.module}/resources/prometheus-ro-rootfs.timer")
}

data "ignition_systemd_unit" "prometheus-ro-rootfs-timer" {
  name    = "prometheus-ro-rootfs.timer"
  content = data.template_file.prometheus-ro-rootfs-timer.rendered
}

data "ignition_file" "prometheus-ro-rootfs" {
  mode       = 493
  path       = "/opt/bin/prometheus-ro-rootfs"

  content {
    content = file("${path.module}/resources/prometheus-ro-rootfs")
  }
}

module "cert-refresh-node" {
  source                        = "./modules/cert-refresh-node"
  on_calendar                   = var.cfssl_node_renew_timer
  use_deprecated_docker_runtime = var.use_deprecated_docker_runtime
}

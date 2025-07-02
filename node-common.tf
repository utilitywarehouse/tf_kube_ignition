// All nodes should belong to system:nodes group
data "ignition_file" "node-cfssl-new-cert" {
  mode = 493
  path = "/opt/bin/cfssl-new-cert"

  content {
    content = templatefile("${path.module}/resources/cfssl-new-cert.sh", {
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
    })
  }
}

// Get a cert for to kubelet serve
data "ignition_file" "node-kubelet-cfssl-new-cert" {
  mode = 493
  path = "/opt/bin/cfssl-new-kubelet-cert"

  content {
    content = templatefile("${path.module}/resources/cfssl-new-cert.sh", {
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
    })
  }
}

// Kubeconfig will be the same for all kubernetes nodes as it only
// contains master address and certs
data "ignition_file" "node-kubeconfig" {
  mode = 420
  path = "/var/lib/kubelet/kubeconfig"

  content {
    content = templatefile("${path.module}/resources/node-kubeconfig", {
      master_address = var.master_address
    })
  }
}

// Kubelet config
data "ignition_file" "node-kubelet-conf" {
  mode = 420
  path = "/etc/kubernetes/config/node-kubelet-conf.yaml"

  content {
    content = templatefile("${path.module}/resources/node-kubelet-conf.yaml", {
      cluster_dns                    = local.cluster_dns_yaml
      eviction_threshold_memory_hard = var.eviction_threshold_memory_hard
      eviction_threshold_memory_soft = var.eviction_threshold_memory_soft
      feature_gates                  = local.feature_gates_yaml_fragment
      system_reserved_cpu            = var.system_reserved_cpu
      system_reserved_memory         = var.system_reserved_memory
    })
  }
}

data "ignition_systemd_unit" "prometheus-tmpfs-dir" {
  name    = "prometheus-tmpfs-dir.service"
  enabled = false # not enabled because this service is started by other services
  content = file("${path.module}/resources/prometheus-tmpfs-dir.service")
}

module "cert-refresh-node" {
  source      = "./modules/cert-refresh-node"
  on_calendar = var.cfssl_node_renew_timer
}

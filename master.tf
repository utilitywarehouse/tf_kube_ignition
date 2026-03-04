data "ignition_systemd_unit" "locksmithd_master" {
  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_master
}

data "ignition_file" "cfssl-master-client-config" {
  mode = 384
  path = "/etc/cfssl/config.json"

  content {
    content = templatefile("${path.module}/resources/cfssl-master-client-config.json", {
      cfssl_server_endpoint = var.cfssl_server_address
      cfssl_master_auth_key = random_id.cfssl-auth-key-master.hex
    })
  }
}

module "cert-refresh-master" {
  source      = "./modules/cert-refresh-master"
  on_calendar = var.cfssl_node_renew_timer
}

// Node certificate for master kubelet. The Kubernetes Node authorizer grants
// permissions based solely on the CN pattern (system:node:<nodeName>), not on
// the Organization field. Masters use the same system:nodes organization as
// workers because both have identical kubelet RBAC permissions. The difference
// in certificate profiles (master-client-server vs worker-client) prevents
// workers from requesting master component certs (scheduler, controller-manager)
// via the separate master-auth key requirement.
//
// Client-only: no SANs needed, kubelet uses this to authenticate to apiserver.
data "ignition_file" "master-cfssl-new-node-cert" {
  mode = 493
  path = "/opt/bin/cfssl-new-node-cert"

  content {
    content = templatefile("${path.module}/resources/cfssl-new-client-cert.sh", {
      cert_name = "node"
      user      = "root"
      group     = "root"
      profile   = "master-client-server"
      path      = "/etc/kubernetes/ssl"
      cn        = "system:node:$(${var.node_name_command[var.cloud_provider]})"
      org       = "system:nodes"
    })
  }
}

// Get a cert for to kubelet serve
data "ignition_file" "master-kubelet-cfssl-new-cert" {
  mode = 493
  path = "/opt/bin/cfssl-new-kubelet-cert"

  content {
    content = templatefile("${path.module}/resources/cfssl-new-server-cert.sh", {
      cert_name    = "kubelet"
      user         = "root"
      group        = "root"
      profile      = "master-client-server"
      path         = "/etc/kubernetes/ssl"
      cn           = "system:kubelet:$(${var.node_name_command[var.cloud_provider]})"
      org          = "system:kubelets"
      get_ip       = var.get_ip_command[var.cloud_provider]
      get_hostname = var.node_name_command[var.cloud_provider]
      extra_names  = ""
    })
  }
}

// Serving certificate for the API server
data "ignition_file" "master-cfssl-new-apiserver-cert" {
  mode = 493
  path = "/opt/bin/cfssl-new-apiserver-cert"

  content {
    content = templatefile("${path.module}/resources/cfssl-new-server-cert.sh", {
      cert_name    = "apiserver"
      user         = "root"
      group        = "root"
      profile      = "master-client-server"
      path         = "/etc/kubernetes/ssl"
      cn           = "system:node:$(${var.node_name_command[var.cloud_provider]})"
      org          = ""
      get_ip       = var.get_ip_command[var.cloud_provider]
      get_hostname = var.node_name_command[var.cloud_provider]
      extra_names = join(
        ",",
        [
          local.kubernetes_master_svc,
          "kubernetes",
          "kubernetes.default",
          "kubernetes.default.svc",
          "kubernetes.default.svc.cluster.local",
          "elb.master.${var.dns_domain}",
          "*.master.${var.dns_domain}",
          "localhost",
          "127.0.0.1",
        ],
      )
    })
  }
}

// Client certificate for the API server to connect to the kubelets securely.
// Client-only: no SANs needed, apiserver uses this to authenticate to kubelet.
data "ignition_file" "master-cfssl-new-apiserver-kubelet-client-cert" {
  mode = 493
  path = "/opt/bin/cfssl-new-apiserver-kubelet-client-cert"

  content {
    content = templatefile("${path.module}/resources/cfssl-new-client-cert.sh", {
      cert_name = "apiserver-kubelet-client"
      user      = "root"
      group     = "root"
      profile   = "master-client-server"
      path      = "/etc/kubernetes/ssl"
      cn        = "system:node:$(${var.node_name_command[var.cloud_provider]})"
      org       = "system:masters"
    })
  }
}

// Client certificate for kube-scheduler.
// Client-only: no SANs needed, scheduler uses this to authenticate to apiserver.
data "ignition_file" "master-cfssl-new-scheduler-cert" {
  mode = 493
  path = "/opt/bin/cfssl-new-scheduler-cert"

  content {
    content = templatefile("${path.module}/resources/cfssl-new-client-cert.sh", {
      cert_name = "scheduler"
      user      = "root"
      group     = "root"
      profile   = "master-client-server"
      path      = "/etc/kubernetes/ssl"
      cn        = "system:kube-scheduler"
      org       = ""
    })
  }
}

// Client certificate for kube-controller-manager.
// Client-only: no SANs needed, controller-manager uses this to authenticate
// to apiserver.
data "ignition_file" "master-cfssl-new-controller-manager-cert" {
  mode = 493
  path = "/opt/bin/cfssl-new-controller-manager-cert"

  content {
    content = templatefile("${path.module}/resources/cfssl-new-client-cert.sh", {
      cert_name = "controller-manager"
      user      = "root"
      group     = "root"
      profile   = "master-client-server"
      path      = "/etc/kubernetes/ssl"
      cn        = "system:kube-controller-manager"
      org       = ""
    })
  }
}

data "ignition_file" "master-cfssl-keys-and-certs-get" {
  mode = 493
  path = "/opt/bin/cfssl-keys-and-certs-get"

  content {
    content = templatefile("${path.module}/resources/cfssl-keys-and-certs-get", {
      path = "/etc/kubernetes/ssl"
      auth = base64encode("apiserver:${random_id.cfssl-auth-key-apiserver.hex}")
    })
  }
}

data "ignition_systemd_unit" "master-kubelet" {
  name = "kubelet.service"
  content = templatefile("${path.module}/resources/master-kubelet.service", {
    kubelet_binary_path = "/opt/bin/kubelet"
    cloud_provider      = local.component_cloud_provider
    get_hostname        = var.node_name_command[var.cloud_provider]
    labels              = local.master_kubelet_labels
  })
}

data "ignition_file" "master-kubelet-conf" {
  mode = 420
  path = "/etc/kubernetes/config/master-kubelet-conf.yaml"

  content {
    content = templatefile("${path.module}/resources/master-kubelet-conf.yaml", {
      cluster_dns   = local.cluster_dns_yaml
      feature_gates = local.feature_gates_yaml_fragment
    })
  }
}

data "ignition_file" "kubelet-kubeconfig" {
  mode = 420
  path = "/var/lib/kubelet/kubeconfig"

  content {
    content = templatefile("${path.module}/resources/master-kubeconfig", {
      master_address = "localhost:443"
    })
  }
}

data "ignition_file" "scheduler-kubeconfig" {
  mode = 420
  path = "/etc/kubernetes/config/scheduler.conf"

  content {
    content = templatefile("${path.module}/resources/scheduler-kubeconfig", {
      master_address = "localhost:443"
    })
  }
}

data "ignition_file" "controller-manager-kubeconfig" {
  mode = 420
  path = "/etc/kubernetes/config/controller-manager.conf"

  content {
    content = templatefile("${path.module}/resources/controller-manager-kubeconfig", {
      master_address = "localhost:443"
    })
  }
}

data "ignition_file" "kube-apiserver" {
  mode = 420
  path = "/etc/kubernetes/manifests/kube-apiserver.yaml"

  content {
    content = templatefile("${path.module}/resources/kube-apiserver.yaml", {
      kubernetes_version           = var.kubernetes_version
      etcd_endpoints               = join(",", formatlist("https://%s:2379", var.etcd_addresses))
      service_network              = var.service_network
      master_address               = var.external_apiserver_address == "" ? var.master_address : var.external_apiserver_address
      master_instance_count        = var.master_instance_count
      oidc_issuer_url              = var.oidc_issuer_url
      oidc_client_id               = var.oidc_client_id
      feature_gates                = local.feature_gates_csv
      admission_plugins            = var.admission_plugins
      runtime_config               = join(",", var.apiserver_runtime_config)
      control_plane_pod_cpu_limits = var.control_plane_pod_cpu_limits
    })
  }
}

data "ignition_file" "audit-policy" {
  mode = 420
  path = "/etc/kubernetes/config/audit-policy.yaml"

  content {
    content = file("${path.module}/resources/audit-policy.yaml")
  }
}

data "ignition_file" "kube-controller-manager" {
  mode = 420
  path = "/etc/kubernetes/manifests/kube-controller-manager.yaml"

  content {
    content = templatefile("${path.module}/resources/kube-controller-manager.yaml", {
      kubernetes_version           = var.kubernetes_version
      pod_network                  = var.pod_network
      feature_gates                = local.feature_gates_csv
      control_plane_pod_cpu_limits = var.control_plane_pod_cpu_limits
    })
  }
}

data "ignition_file" "kube-scheduler" {
  mode = 420
  path = "/etc/kubernetes/manifests/kube-scheduler.yaml"

  content {
    content = templatefile("${path.module}/resources/kube-scheduler.yaml", {
      kubernetes_version           = var.kubernetes_version
      feature_gates                = local.feature_gates_csv
      control_plane_pod_cpu_limits = var.control_plane_pod_cpu_limits
    })
  }
}

data "ignition_file" "kube-scheduler-config" {
  mode = 420
  path = "/etc/kubernetes/config/kube-scheduler-config.yaml"

  content {
    content = file("${path.module}/resources/kube-scheduler-config.yaml")
  }
}

data "ignition_file" "master-prom-machine-role" {
  mode = 420
  path = "/etc/prom-text-collectors/machine_role.prom"

  content {
    content = "machine_role{role=\"master\"} 1\n"
  }
}

data "ignition_file" "master-prom-eviction-threshold" {
  mode = 420
  path = "/etc/prom-text-collectors/node_eviction_threshold.prom"

  content {
    # Default value from
    # https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1 is
    # 100Mi == 2^20 * 100 == 104857600
    content = "node_eviction_threshold 104857600\n"
  }
}

data "ignition_file" "control_plane_labeller" {
  mode = 493
  path = "/opt/bin/control-plane-labeller"
  content {
    content = templatefile("${path.module}/resources/control-plane-labeller.tftpl",
      {
        get_hostname = var.node_name_command[var.cloud_provider]
      }
    )
  }
}

data "ignition_systemd_unit" "control_plane_labeller" {
  name    = "control-plane-labeller.service"
  content = file("${path.module}/resources/control-plane-labeller.service")
}

data "ignition_config" "master" {
  filesystems = [
    var.force_boot_reprovisioning ? data.ignition_filesystem.root_wipe_filesystem.rendered : "",
  ]

  files = concat(
    [
      data.ignition_file.audit-policy.rendered,
      data.ignition_file.bashrc.rendered,
      data.ignition_file.cfssl-master-client-config.rendered,
      data.ignition_file.cfssl.rendered,
      data.ignition_file.cfssljson.rendered,
      data.ignition_file.containerd-config.rendered,
      data.ignition_file.containerd_dockerio_hosts_toml.rendered,
      data.ignition_file.control_plane_labeller.rendered,
      data.ignition_file.controller-manager-kubeconfig.rendered,
      data.ignition_file.crictl-config.rendered,
      data.ignition_file.docker-config.rendered,
      data.ignition_file.docker_daemon_json.rendered,
      data.ignition_file.kube-apiserver.rendered,
      data.ignition_file.kube-controller-manager.rendered,
      data.ignition_file.kube-scheduler-config.rendered,
      data.ignition_file.kube-scheduler.rendered,
      data.ignition_file.kubelet-docker-config.rendered,
      data.ignition_file.kubelet-kubeconfig.rendered,
      data.ignition_file.kubelet.rendered,
      data.ignition_file.kubernetes_accounting_config.rendered,
      data.ignition_file.master-cfssl-keys-and-certs-get.rendered,
      data.ignition_file.master-cfssl-new-apiserver-cert.rendered,
      data.ignition_file.master-cfssl-new-apiserver-kubelet-client-cert.rendered,
      data.ignition_file.master-cfssl-new-controller-manager-cert.rendered,
      data.ignition_file.master-cfssl-new-node-cert.rendered,
      data.ignition_file.master-cfssl-new-scheduler-cert.rendered,
      data.ignition_file.master-kubelet-cfssl-new-cert.rendered,
      data.ignition_file.master-kubelet-conf.rendered,
      data.ignition_file.master-prom-eviction-threshold.rendered,
      data.ignition_file.master-prom-machine-role.rendered,
      data.ignition_file.node_textfile_inode_fd_count.rendered,
      data.ignition_file.scheduler-kubeconfig.rendered,
      data.ignition_file.sysctl_kernel_vars.rendered,
      data.ignition_file.zram_generator_conf.rendered,
      var.cloud_provider == "aws" ? data.ignition_file.aws_meta_data_IMDSv2.rendered : "",
    ],
    var.master_additional_files,
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.containerd-dropin.rendered,
      data.ignition_systemd_unit.control_plane_labeller.rendered,
      data.ignition_systemd_unit.coreos_metadata_sshkeys.rendered,
      data.ignition_systemd_unit.docker-opts-dropin.rendered,
      data.ignition_systemd_unit.master-kubelet.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_service.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_timer.rendered,
      !var.omit_locksmithd_service ? data.ignition_systemd_unit.locksmithd_master.rendered : "",
      !var.omit_update_engine_service ? data.ignition_systemd_unit.update-engine.rendered : "",
      var.force_boot_reprovisioning ? data.ignition_systemd_unit.flatcar_first_boot.rendered : "",
    ],
    module.cert-refresh-master.systemd_units,
    var.master_additional_systemd_units,
  )

  directories = [
    data.ignition_directory.journald.rendered
  ]
}

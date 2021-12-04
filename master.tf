data "ignition_systemd_unit" "locksmithd_master" {
  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_master
}

module "cert-refresh-master" {
  source      = "./modules/cert-refresh-master"
  on_calendar = var.cfssl_node_renew_timer
}

// Node certificate for kubelet to use as part of system:master-nodes. We need
// ClusterRoleBindings to allow kube components creation and bind the group
// with system:node role. In order to be authorized by the Node authorizer,
// kubelets must use a credential that identifies them as being in the
// system:nodes group, with a username of system:node:<nodeName>
data "template_file" "master-node-cfssl-new-cert" {
  template = file("${path.module}/resources/cfssl-new-cert.sh")

  vars = {
    cert_name    = "node"
    user         = "root"
    group        = "root"
    profile      = "client-server"
    path         = "/etc/kubernetes/ssl"
    cn           = "system:node:$(${var.node_name_command[var.cloud_provider]})"
    org          = "system:master-nodes"
    get_ip       = var.get_ip_command[var.cloud_provider]
    get_hostname = var.node_name_command[var.cloud_provider]
    extra_names  = ""
  }
}

data "ignition_file" "master-cfssl-new-node-cert" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-node-cert"

  content {
    content = data.template_file.master-node-cfssl-new-cert.rendered
  }
}

// Get a cert for to kubelet serve
data "template_file" "master-kubelet-cfssl-new-cert" {
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

data "ignition_file" "master-kubelet-cfssl-new-cert" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-kubelet-cert"

  content {
    content = data.template_file.master-kubelet-cfssl-new-cert.rendered
  }
}

// Serving certificate for the API server
data "template_file" "master-apiserver-cfssl-new-cert" {
  template = file("${path.module}/resources/cfssl-new-cert.sh")

  vars = {
    cert_name    = "apiserver"
    user         = "root"
    group        = "root"
    profile      = "client-server"
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
  }
}

data "ignition_file" "master-cfssl-new-apiserver-cert" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-apiserver-cert"

  content {
    content = data.template_file.master-apiserver-cfssl-new-cert.rendered
  }
}

// Client certificate for the API server to connect to the kubelets securely
data "template_file" "master-apiserver-kubelet-client-cfssl-new-cert" {
  template = file("${path.module}/resources/cfssl-new-cert.sh")

  vars = {
    cert_name    = "apiserver-kubelet-client"
    user         = "root"
    group        = "root"
    profile      = "client-server"
    path         = "/etc/kubernetes/ssl"
    cn           = "system:node:$(${var.node_name_command[var.cloud_provider]})"
    org          = "system:masters"
    get_ip       = var.get_ip_command[var.cloud_provider]
    get_hostname = var.node_name_command[var.cloud_provider]
    extra_names  = ""
  }
}

data "ignition_file" "master-cfssl-new-apiserver-kubelet-client-cert" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-apiserver-kubelet-client-cert"

  content {
    content = data.template_file.master-apiserver-kubelet-client-cfssl-new-cert.rendered
  }
}

// Client certificate for kube-scheduler
data "template_file" "master-scheduler-cfssl-new-cert" {
  template = file("${path.module}/resources/cfssl-new-cert.sh")

  vars = {
    cert_name    = "scheduler"
    user         = "root"
    group        = "root"
    profile      = "client-server"
    path         = "/etc/kubernetes/ssl"
    cn           = "system:kube-scheduler"
    org          = ""
    get_ip       = var.get_ip_command[var.cloud_provider]
    get_hostname = var.node_name_command[var.cloud_provider]
    extra_names  = ""
  }
}

data "ignition_file" "master-cfssl-new-scheduler-cert" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-scheduler-cert"

  content {
    content = data.template_file.master-scheduler-cfssl-new-cert.rendered
  }
}

// Client certificate for kube-controller-manager
data "template_file" "master-controller-manager-cfssl-new-cert" {
  template = file("${path.module}/resources/cfssl-new-cert.sh")

  vars = {
    cert_name    = "controller-manager"
    user         = "root"
    group        = "root"
    profile      = "client-server"
    path         = "/etc/kubernetes/ssl"
    cn           = "system:kube-controller-manager"
    org          = ""
    get_ip       = var.get_ip_command[var.cloud_provider]
    get_hostname = var.node_name_command[var.cloud_provider]
    extra_names  = ""
  }
}

data "ignition_file" "master-cfssl-new-controller-manager-cert" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-controller-manager-cert"

  content {
    content = data.template_file.master-controller-manager-cfssl-new-cert.rendered
  }
}

data "template_file" "master-cfssl-keys-and-certs-get" {
  template = file("${path.module}/resources/cfssl-keys-and-certs-get")

  vars = {
    path = "/etc/kubernetes/ssl"
    auth = base64encode("apiserver:${random_id.cfssl-auth-key-apiserver.hex}")
  }
}

data "ignition_file" "master-cfssl-keys-and-certs-get" {
  mode       = 493
  filesystem = "root"
  path       = "/opt/bin/cfssl-keys-and-certs-get"

  content {
    content = data.template_file.master-cfssl-keys-and-certs-get.rendered
  }
}

data "template_file" "master-kubelet" {
  template = file("${path.module}/resources/master-kubelet.service")

  vars = {
    kubelet_binary_path = "/opt/bin/kubelet"
    cloud_provider      = var.cloud_provider
    get_hostname        = var.node_name_command[var.cloud_provider]
  }
}

data "ignition_systemd_unit" "master-kubelet" {
  name    = "kubelet.service"
  content = data.template_file.master-kubelet.rendered
}

data "template_file" "master-kubelet-conf" {
  template = file("${path.module}/resources/master-kubelet-conf.yaml")

  vars = {
    cluster_dns                       = local.cluster_dns_yaml
    feature_gates                     = local.feature_gates_yaml_fragment
    kubelet_cgroup_v2_runtime_enabled = var.kubelet_cgroup_v2_runtime_enabled
  }
}

data "ignition_file" "master-kubelet-conf" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/kubernetes/config/master-kubelet-conf.yaml"

  content {
    content = data.template_file.master-kubelet-conf.rendered
  }
}

data "template_file" "master-kubeconfig" {
  template = file("${path.module}/resources/master-kubeconfig")

  vars = {
    master_address = "localhost:443"
  }
}

data "ignition_file" "kubelet-kubeconfig" {
  mode       = 420
  filesystem = "root"
  path       = "/var/lib/kubelet/kubeconfig"

  content {
    content = data.template_file.master-kubeconfig.rendered
  }
}

data "template_file" "scheduler-kubeconfig" {
  template = file("${path.module}/resources/scheduler-kubeconfig")

  vars = {
    master_address = "localhost:443"
  }
}

data "ignition_file" "scheduler-kubeconfig" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/kubernetes/config/scheduler.conf"

  content {
    content = data.template_file.scheduler-kubeconfig.rendered
  }
}

data "template_file" "controller-manager-kubeconfig" {
  template = file("${path.module}/resources/controller-manager-kubeconfig")

  vars = {
    master_address = "localhost:443"
  }
}

data "ignition_file" "controller-manager-kubeconfig" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/kubernetes/config/controller-manager.conf"

  content {
    content = data.template_file.controller-manager-kubeconfig.rendered
  }
}

data "template_file" "kube-apiserver" {
  template = file("${path.module}/resources/kube-apiserver.yaml")

  vars = {
    kubernetes_version    = var.kubernetes_version
    etcd_endpoints        = join(",", formatlist("https://%s:2379", var.etcd_addresses))
    service_network       = var.service_network
    master_address        = var.external_apiserver_address == "" ? var.master_address : var.external_apiserver_address
    master_instance_count = var.master_instance_count
    cloud_provider        = var.cloud_provider
    oidc_issuer_url       = var.oidc_issuer_url
    oidc_client_id        = var.oidc_client_id
    feature_gates         = local.feature_gates_csv
    admission_plugins     = var.admission_plugins
    runtime_config        = join(",", [])
  }
  /*
     * for the list of APIs & resources enabled by default, please see near the
     * bottom of the file:
     *   https://github.com/kubernetes/kubernetes/blob/<ref>/pkg/master/master.go
     *
     */
}

data "ignition_file" "kube-apiserver" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-apiserver.yaml"

  content {
    content = data.template_file.kube-apiserver.rendered
  }
}

data "template_file" "audit-policy" {
  template = file("${path.module}/resources/audit-policy.yaml")
}

data "ignition_file" "audit-policy" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/kubernetes/config/audit-policy.yaml"

  content {
    content = data.template_file.audit-policy.rendered
  }
}

data "template_file" "kube-controller-manager" {
  template = file("${path.module}/resources/kube-controller-manager.yaml")

  vars = {
    kubernetes_version = var.kubernetes_version
    cloud_provider     = var.cloud_provider
    cloud_config       = var.kube_controller_cloud_config
    pod_network        = var.pod_network
    feature_gates      = local.feature_gates_csv
  }
}

data "ignition_file" "kube-controller-manager" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-controller-manager.yaml"

  content {
    content = data.template_file.kube-controller-manager.rendered
  }
}

data "ignition_file" "kube-controller-conf" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/kubernetes/config/cloud_provider/cloud.conf"

  content {
    content = var.kube_controller_cloud_config
  }
}

data "template_file" "kube-scheduler" {
  template = file("${path.module}/resources/kube-scheduler.yaml")

  vars = {
    kubernetes_version = var.kubernetes_version
    feature_gates      = local.feature_gates_csv
  }
}

data "ignition_file" "kube-scheduler" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-scheduler.yaml"

  content {
    content = data.template_file.kube-scheduler.rendered
  }
}

data "ignition_file" "kube-scheduler-config" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/kubernetes/config/kube-scheduler-config.yaml"

  content {
    content = file("${path.module}/resources/kube-scheduler-config.yaml")
  }
}

data "ignition_file" "master-prom-machine-role" {
  mode       = 420
  filesystem = "root"
  path       = "/etc/prom-text-collectors/machine_role.prom"

  content {
    content = "machine_role{role=\"master\"} 1\n"
  }
}

locals {
  kube_controller_additional_config = var.kube_controller_cloud_config == "" ? "" : data.ignition_file.kube-controller-conf.rendered
}

data "ignition_config" "master" {
  files = concat(
    [
      data.ignition_file.audit-policy.rendered,
      data.ignition_file.bashrc.rendered,
      data.ignition_file.cfssl-client-config.rendered,
      data.ignition_file.cfssl.rendered,
      data.ignition_file.cfssljson.rendered,
      data.ignition_file.containerd-config.rendered,
      data.ignition_file.controller-manager-kubeconfig.rendered,
      data.ignition_file.crictl-config.rendered,
      data.ignition_file.crictl.rendered,
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
      data.ignition_file.master-prom-machine-role.rendered,
      data.ignition_file.node_textfile_inode_fd_count.rendered,
      data.ignition_file.scheduler-kubeconfig.rendered,
      data.ignition_file.sysctl_kernel_vars.rendered,
    ],
    var.master_additional_files,
    [local.kube_controller_additional_config]
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.containerd-dropin.rendered,
      data.ignition_systemd_unit.docker-opts-dropin.rendered,
      data.ignition_systemd_unit.fstrim_dropin.rendered,
      data.ignition_systemd_unit.fstrim_timer.rendered,
      data.ignition_systemd_unit.locksmithd_master.rendered,
      data.ignition_systemd_unit.master-kubelet.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_service.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_timer.rendered,
      data.ignition_systemd_unit.prepare-crictl.rendered,
      data.ignition_systemd_unit.update-engine.rendered,
    ],
    module.cert-refresh-master.systemd_units,
    var.master_additional_systemd_units,
  )

  directories = [
    data.ignition_directory.journald.rendered
  ]
}

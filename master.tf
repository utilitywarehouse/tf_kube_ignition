data "ignition_systemd_unit" "locksmithd_master" {
  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_master
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
  }
}

data "ignition_systemd_unit" "master-kubelet" {
  name    = "kubelet.service"
  content = data.template_file.master-kubelet.rendered
}

data "template_file" "master-kubelet-conf" {
  template = file("${path.module}/resources/master-kubelet-conf.yaml")

  vars = {
    cluster_dns   = local.cluster_dns_yaml
    feature_gates = local.feature_gates_yaml_fragment
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
    hyperkube_image_url   = var.hyperkube_image_url
    hyperkube_image_tag   = var.hyperkube_image_tag
    etcd_endpoints        = join(",", formatlist("https://%s:2379", var.etcd_addresses))
    service_network       = var.service_network
    master_address        = var.master_address
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
    hyperkube_image_url = var.hyperkube_image_url
    hyperkube_image_tag = var.hyperkube_image_tag
    cloud_provider      = var.cloud_provider
    cloud_config        = var.kube_controller_cloud_config
    pod_network         = var.pod_network
    feature_gates       = local.feature_gates_csv
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
    hyperkube_image_url = var.hyperkube_image_url
    hyperkube_image_tag = var.hyperkube_image_tag
    feature_gates       = local.feature_gates_csv
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
  kube_controller_additional_config = var.kube_controller_cloud_config == "" ? "" : data.ignition_file.kube-controller-conf.id
}

data "ignition_config" "master" {
  files = concat(
    [
      data.ignition_file.audit-policy.id,
      data.ignition_file.cfssl.id,
      data.ignition_file.cfssljson.id,
      data.ignition_file.cfssl-client-config.id,
      data.ignition_file.master-cfssl-new-node-cert.id,
      data.ignition_file.master-cfssl-new-apiserver-cert.id,
      data.ignition_file.master-cfssl-new-apiserver-kubelet-client-cert.id,
      data.ignition_file.master-cfssl-new-scheduler-cert.id,
      data.ignition_file.master-cfssl-new-controller-manager-cert.id,
      data.ignition_file.master-cfssl-keys-and-certs-get.id,
      data.ignition_file.master-kubelet-cfssl-new-cert.id,
      data.ignition_file.master-prom-machine-role.id,
      data.ignition_file.scheduler-kubeconfig.id,
      data.ignition_file.controller-manager-kubeconfig.id,
      data.ignition_file.kubelet-kubeconfig.id,
      data.ignition_file.kube-apiserver.id,
      data.ignition_file.kube-scheduler.id,
      data.ignition_file.kube-scheduler-config.id,
      data.ignition_file.kube-controller-manager.id,
      data.ignition_file.kubelet.id,
      data.ignition_file.master-kubelet-conf.id,
    ],
    var.master_additional_files,
    [local.kube_controller_additional_config]
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.update-engine.id,
      data.ignition_systemd_unit.locksmithd_master.id,
      data.ignition_systemd_unit.docker-opts-dropin.id,
      data.ignition_systemd_unit.master-kubelet.id,
    ],
    module.kubelet-restarter.systemd_units,
    var.master_additional_systemd_units
  )
}

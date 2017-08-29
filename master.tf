data "template_file" "master-cfssl-new-cert" {
  template = "${file("${path.module}/resources/cfssl-new-cert.sh")}"

  vars {
    user    = "root"
    group   = "root"
    role    = "k8s-apiserver"
    profile = "client-server"
    path    = "/etc/kubernetes/ssl"

    hosts = "${join(",", list(
      "10.3.0.1",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster.local",
      "elb.master.${var.dns_domain}",
      "*.master.${var.dns_domain}",
    ))}"
  }
}

data "ignition_file" "master-cfssl-new-cert" {
  mode       = 0755
  filesystem = "root"
  path       = "/opt/bin/cfssl-new-cert"

  content {
    content = "${data.template_file.master-cfssl-new-cert.rendered}"
  }
}

data "template_file" "master-kubelet" {
  template = "${file("${path.module}/resources/master-kubelet.service")}"

  vars {
    kubelet_image_url = "${var.hyperkube_image_url}"
    kubelet_image_tag = "${var.hyperkube_image_tag}"
    cloud_provider    = "${var.cloud_provider}"
    cluster_dns       = "${var.cluster_dns}"
  }
}

data "ignition_systemd_unit" "master-kubelet" {
  name    = "kubelet.service"
  content = "${data.template_file.master-kubelet.rendered}"
}

data "template_file" "master-kube-proxy" {
  template = "${file("${path.module}/resources/master-kube-proxy.yaml")}"

  vars {
    hyperkube_image_url = "${var.hyperkube_image_url}"
    hyperkube_image_tag = "${var.hyperkube_image_tag}"
  }
}

data "ignition_file" "master-kube-proxy" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-proxy.yaml"

  content {
    content = "${data.template_file.master-kube-proxy.rendered}"
  }
}

data "ignition_file" "master-kubeconfig" {
  mode       = 0644
  filesystem = "root"
  path       = "/var/lib/kubelet/kubeconfig"

  content {
    content = "${file("${path.module}/resources/master-kubeconfig")}"
  }
}

data "template_file" "kube-apiserver" {
  template = "${file("${path.module}/resources/kube-apiserver.yaml")}"

  vars {
    hyperkube_image_url   = "${var.hyperkube_image_url}"
    hyperkube_image_tag   = "${var.hyperkube_image_tag}"
    etcd_endpoints        = "${join(",", formatlist("https://%s:2379", var.etcd_addresses))}"
    service_network       = "${var.service_network}"
    master_instance_count = "${var.master_instance_count}"
    cloud_provider        = "${var.cloud_provider}"
    oidc_issuer_url       = "${var.oidc_issuer_url}"
    oidc_client_id        = "${var.oidc_client_id}"
  }
}

data "ignition_file" "kube-apiserver" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-apiserver.yaml"

  content {
    content = "${data.template_file.kube-apiserver.rendered}"
  }
}

data "template_file" "kube-controller-manager" {
  template = "${file("${path.module}/resources/kube-controller-manager.yaml")}"

  vars {
    hyperkube_image_url = "${var.hyperkube_image_url}"
    hyperkube_image_tag = "${var.hyperkube_image_tag}"
    cloud_provider      = "${var.cloud_provider}"
    pod_network         = "${var.pod_network}"
  }
}

data "ignition_file" "kube-controller-manager" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-controller-manager.yaml"

  content {
    content = "${data.template_file.kube-controller-manager.rendered}"
  }
}

data "template_file" "kube-scheduler" {
  template = "${file("${path.module}/resources/kube-scheduler.yaml")}"

  vars {
    hyperkube_image_url = "${var.hyperkube_image_url}"
    hyperkube_image_tag = "${var.hyperkube_image_tag}"
  }
}

data "ignition_file" "kube-scheduler" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/kubernetes/manifests/kube-scheduler.yaml"

  content {
    content = "${data.template_file.kube-scheduler.rendered}"
  }
}

data "ignition_file" "master-prom-machine-role" {
  mode       = 0644
  filesystem = "root"
  path       = "/etc/prom-text-collectors/machine_role.prom"

  content {
    content = "machine_role{role=\"master\"} 1\n"
  }
}

data "ignition_config" "master" {
  files = ["${concat(
    list(
        data.ignition_file.cfssl.id,
        data.ignition_file.cfssljson.id,
        data.ignition_file.cfssl-client-config.id,
        data.ignition_file.master-cfssl-new-cert.id,
        data.ignition_file.master-prom-machine-role.id,
        data.ignition_file.master-kubeconfig.id,
        data.ignition_file.master-kube-proxy.id,
        data.ignition_file.kube-apiserver.id,
        data.ignition_file.kube-scheduler.id,
        data.ignition_file.kube-controller-manager.id,
    ),
    var.master_additional_files,
  )}"]

  systemd = ["${concat(
    list(
        data.ignition_systemd_unit.update-engine.id,
        data.ignition_systemd_unit.locksmithd.id,
        data.ignition_systemd_unit.cfssl-new-cert.id,
        data.ignition_systemd_unit.cfssl-new-cert-timer.id,
        data.ignition_systemd_unit.master-kubelet.id,
    ),
    var.master_additional_systemd_units,
  )}"]
}

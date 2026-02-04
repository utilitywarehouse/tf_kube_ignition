// common items

# Unused auth key for CFSSL's "default" profile. This profile is never used
# (all cert requests explicitly specify a profile), but CFSSL requires the
# default profile to reference a valid auth key. This acts as a security
# feature: if the default profile is somehow invoked, requests will fail
# because no node possesses this key.
resource "random_id" "cfssl-auth-key-unused" {
  byte_length = 16
}

resource "random_id" "cfssl-auth-key-client" {
  byte_length = 16
}

# HTTP Basic Auth key for fetching special certificates (signing key, proxy certs)
# from CFSSL server. This is separate from CFSSL profile auth keys.
resource "random_id" "cfssl-auth-key-apiserver" {
  byte_length = 16
}

resource "random_id" "cfssl-auth-key-worker" {
  byte_length = 16
}

resource "random_id" "cfssl-auth-key-master" {
  byte_length = 16
}

resource "random_id" "cfssl-auth-key-etcd" {
  byte_length = 16
}

data "ignition_systemd_unit" "locksmithd_cfssl" {
  name = "locksmithd.service"
  mask = false == var.enable_container_linux_locksmithd_cfssl
}

// used by clients
data "ignition_file" "cfssl-client-config" {
  mode = 384
  path = "/etc/cfssl/config.json"

  content {
    content = templatefile("${path.module}/resources/cfssl-client-config.json", {
      cfssl_server_endpoint = var.cfssl_server_address
      cfssl_auth_key        = random_id.cfssl-auth-key-client.hex
    })
  }
}

data "ignition_systemd_unit" "cfssl-disk-mounter" {
  name = "disk-mounter.service"
  content = templatefile("${path.module}/resources/disk-mounter.service", {
    script_path = "/opt/bin/format-and-mount"
    volume_id   = var.cfssl_data_volumeid
    filesystem  = "ext4"
    user        = "root"
    group       = "root"
    mountpoint  = "/var/lib/cfssl"
  })
}

data "ignition_file" "cfssl-ca-csr" {
  mode = 420
  path = "/etc/cfssl/ca-csr.json"

  content {
    content = <<EOS
{ "CN": "${var.cfssl_ca_cn}", "key": { "algo": "ecdsa", "size": 521 }, "ca": { "expiry": "${var.cfssl_ca_expiry_hours}h" } }
EOS
  }
}

data "ignition_file" "cfssl-init-ca" {
  mode = 493
  path = "/opt/bin/cfssl-init-ca"

  content {
    content = file("${path.module}/resources/cfssl-init-ca.sh")
  }
}

data "ignition_file" "cfssl-init-proxy-pki" {
  mode = 493
  path = "/opt/bin/cfssl-init-proxy-pki"

  content {
    content = file("${path.module}/resources/cfssl-init-proxy-pki")
  }
}

data "ignition_file" "cfssl-proxy-ca-csr-json" {
  mode = 420
  path = "/etc/cfssl/proxy-ca-csr.json"

  content {
    content = templatefile("${path.module}/resources/cfssl-proxy-ca-csr.json", {
      ca_expiry_hours = var.cfssl_ca_expiry_hours
    })
  }
}

data "ignition_file" "cfssl-proxy-csr-json" {
  mode = 420
  path = "/etc/cfssl/proxy-csr.json"

  content {
    content = file("${path.module}/resources/cfssl-proxy-csr.json")
  }
}

# CFSSL server configuration file. The 'default' profile uses the 'unused'
# auth key as a security measure. All cert requests explicitly specify a
# profile (worker-client, master-client-server, etc), so this default is never
# used. If it's somehow invoked, requests fail because no node has the unused
# auth key.
#
# NOTE: The shared system:node:* and system:kubelet:* CN patterns in worker
# and master profiles is safe and intentional. Both workers and masters use
# system:nodes organization and get identical kubelet permissions via the
# Kubernetes Node authorizer (which grants permissions based on CN pattern
# alone, not Organization). The security separation between worker-auth and
# master-auth keys prevents workers from requesting certificates for master
# control plane components (scheduler, controller-manager). The real privilege
# separation occurs at the component level (scheduler, controller-manager,
# apiserver, etcd) which have separate auth keys and dedicated CN patterns.
data "ignition_file" "cfssl-server-config" {
  mode = 384
  path = "/etc/cfssl/config.json"

  content {
    content = templatefile("${path.module}/resources/cfssl-server-config.json", {
      expiry_hours          = var.cfssl_node_expiry_hours
      cfssl_unused_key      = random_id.cfssl-auth-key-unused.hex
      cfssl_auth_key        = random_id.cfssl-auth-key-client.hex
      cfssl_worker_auth_key = random_id.cfssl-auth-key-worker.hex
      cfssl_master_auth_key = random_id.cfssl-auth-key-master.hex
      cfssl_etcd_auth_key   = random_id.cfssl-auth-key-etcd.hex
    })
  }
}

data "ignition_systemd_unit" "cfssl" {
  name    = "cfssl.service"
  content = file("${path.module}/resources/cfssl.service")
}

data "ignition_file" "cfssl-sk-csr" {
  mode = 420
  path = "/etc/cfssl/sk-csr.json"

  content {
    content = <<EOS
{ "key": { "algo": "ecdsa", "size": 256 } }
EOS
  }
}

data "ignition_file" "cfssl-nginx-conf" {
  mode = 420
  path = "/etc/cfssl/sk-nginx.conf"

  content {
    content = file("${path.module}/resources/cfssl-nginx.conf")
  }
}

data "ignition_file" "cfssl-nginx-auth" {
  mode = 420
  path = "/etc/cfssl/sk-nginx.htpasswd"

  // it's okay to use PLAIN below since the only thing that this password
  // safeguards is the signing key which is present on the server anyway
  content {
    content = "apiserver:{PLAIN}${random_id.cfssl-auth-key-apiserver.hex}"
  }
}

data "ignition_systemd_unit" "cfssl-nginx" {
  name = "cfssl-nginx.service"

  content = templatefile("${path.module}/resources/cfssl-nginx.service", {
    nginx_image = var.nginx_image
  })
}

module "cfssl-restarter" {
  source = "./modules/systemd_service_restarter"

  service_name = "cfssl"
  on_calendar  = "*-*-* 00:00:00"
}

data "ignition_file" "cfssl-prom-machine-role" {
  mode = 420
  path = "/etc/prom-text-collectors/machine_role.prom"

  content {
    content = "machine_role{role=\"cfssl\"} 1\n"
  }
}

data "ignition_config" "cfssl" {
  files = concat(
    [
      data.ignition_file.bashrc.rendered,
      data.ignition_file.cfssl-ca-csr.rendered,
      data.ignition_file.cfssl-init-ca.rendered,
      data.ignition_file.cfssl-init-proxy-pki.rendered,
      data.ignition_file.cfssl-nginx-auth.rendered,
      data.ignition_file.cfssl-nginx-conf.rendered,
      data.ignition_file.cfssl-prom-machine-role.rendered,
      data.ignition_file.cfssl-proxy-ca-csr-json.rendered,
      data.ignition_file.cfssl-proxy-csr-json.rendered,
      data.ignition_file.cfssl-server-config.rendered,
      data.ignition_file.cfssl-sk-csr.rendered,
      data.ignition_file.cfssl.rendered,
      data.ignition_file.cfssljson.rendered,
      data.ignition_file.containerd-config.rendered,
      data.ignition_file.containerd_dockerio_hosts_toml.rendered,
      data.ignition_file.docker-config.rendered,
      data.ignition_file.format-and-mount.rendered,
      data.ignition_file.node_textfile_inode_fd_count.rendered,
      data.ignition_file.sysctl_kernel_vars.rendered,
      data.ignition_file.zram_generator_conf.rendered,
      var.cloud_provider == "aws" ? data.ignition_file.aws_meta_data_IMDSv2.rendered : "",
    ],
    var.cfssl_additional_files
  )

  systemd = concat(
    [
      data.ignition_systemd_unit.cfssl-disk-mounter.rendered,
      data.ignition_systemd_unit.cfssl-nginx.rendered,
      data.ignition_systemd_unit.cfssl.rendered,
      data.ignition_systemd_unit.containerd-dropin.rendered,
      data.ignition_systemd_unit.docker-opts-dropin.rendered,
      data.ignition_systemd_unit.node-exporter.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_service.rendered,
      data.ignition_systemd_unit.node_textfile_inode_fd_count_timer.rendered,
      !var.omit_locksmithd_service ? data.ignition_systemd_unit.locksmithd_cfssl.rendered : "",
      !var.omit_update_engine_service ? data.ignition_systemd_unit.update-engine.rendered : "",
    ],
    module.cfssl-restarter.systemd_units,
    var.cfssl_additional_systemd_units
  )

  directories = [
    data.ignition_directory.journald.rendered
  ]
}

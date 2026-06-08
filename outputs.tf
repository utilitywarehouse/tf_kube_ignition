output "cfssl" {
  value = data.ignition_config.cfssl.rendered
}

output "master" {
  value = data.ignition_config.master.rendered
}

output "worker" {
  value = data.ignition_config.worker_config["default"].rendered
}

output "worker_ignition_configs" {
  description = "Map of ignition config objects for all worker groups, keyed by group name. The 'default' key is the standard untainted worker config; other keys correspond to entries in worker_groups. Each object exposes rendered, systemd, files, and directories."
  value = { for k, v in data.ignition_config.worker_config : k => {
    rendered    = v.rendered
    systemd     = v.systemd
    files       = v.files
    directories = v.directories
  } }
}

output "etcd" {
  value = data.ignition_config.etcd.*.rendered
}

// Also output ignition config systemd and files for stuff like on-prem that need to manipulate those
output "cfssl_ignition_systemd" {
  value = data.ignition_config.cfssl.systemd
}

output "cfssl_ignition_files" {
  value = data.ignition_config.cfssl.files
}

output "cfssl_ignition_directories" {
  value = data.ignition_config.cfssl.directories
}

output "master_ignition_systemd" {
  value = data.ignition_config.master.systemd
}

output "master_ignition_files" {
  value = data.ignition_config.master.files
}

output "master_ignition_directories" {
  value = data.ignition_config.master.directories
}

output "worker_ignition_systemd" {
  value = data.ignition_config.worker_config["default"].systemd
}

output "worker_ignition_files" {
  value = data.ignition_config.worker_config["default"].files
}

output "worker_ignition_directories" {
  value = data.ignition_config.worker_config["default"].directories
}

output "etcd_ignition_systemd" {
  value = data.ignition_config.etcd.*.systemd
}

output "etcd_ignition_files" {
  value = data.ignition_config.etcd.*.files
}

output "etcd_ignition_directories" {
  value = data.ignition_config.etcd.*.directories
}

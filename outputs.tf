output "cfssl" {
  value = data.ignition_config.cfssl.rendered
}

output "master" {
  value = data.ignition_config.master.rendered
}

output "worker" {
  value = data.ignition_config.worker.rendered
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
  value = data.ignition_config.worker.systemd
}

output "worker_ignition_files" {
  value = data.ignition_config.worker.files
}

output "worker_ignition_directories" {
  value = data.ignition_config.worker.directories
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

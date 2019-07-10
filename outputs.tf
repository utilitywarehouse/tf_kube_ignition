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

output "master_ignition_systemd" {
  value = data.ignition_config.master.systemd
}

output "master_ignition_files" {
  value = data.ignition_config.master.files
}

output "worker_ignition_systemd" {
  value = data.ignition_config.worker.systemd
}

output "worker_ignition_files" {
  value = data.ignition_config.worker.files
}

output "storage_worker_ignition_systemd" {
  value = data.ignition_config.storage-worker.systemd
}

output "etcd_ignition_systemd" {
  value = [data.ignition_config.etcd.*.systemd]
}

output "etcd_ignition_files" {
  value = [data.ignition_config.etcd.*.files]
}

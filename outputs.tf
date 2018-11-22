output "cfssl" {
  value = "${data.ignition_config.cfssl.rendered}"
}

output "master" {
  value = "${data.ignition_config.master.rendered}"
}

output "worker" {
  value = "${data.ignition_config.worker.rendered}"
}

output "etcd" {
  value = ["${data.ignition_config.etcd.*.rendered}"]
}

// Also output ignition config ids for stuff like on-prem that need to manipulate those
output "cfssl_ignition_id" {
  value = "${data.ignition_config.cfssl.id}"
}

output "master_ignition_id" {
  value = "${data.ignition_config.master.id}"
}

output "worker_ignition_id" {
  value = "${data.ignition_config.worker.id}"
}

output "etcd_ignition_id" {
  value = ["${data.ignition_config.etcd.*.id}"]
}

output "master" {
  value = "${data.ignition_config.master.rendered}"
}

output "worker" {
  value = "${data.ignition_config.worker.rendered}"
}

output "etcd" {
  value = ["${data.ignition_config.etcd.*.rendered}"]
}

output "master" {
  value = "${data.ignition_config.master.rendered}"
}

output "worker" {
  value = "${data.ignition_config.worker.rendered}"
}

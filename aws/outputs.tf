output "etcd_ip_list" {
  value = ["${null_resource.etcd_address.*.triggers.address}"]
}

output "master_address" {
  value = "${aws_route53_record.master-elb.name}"
}

output "etcd_security_group_id" {
  value = "${aws_security_group.etcd.id}"
}

output "master_security_group_id" {
  value = "${aws_security_group.master.id}"
}

output "worker_security_group_id" {
  value = "${aws_security_group.worker.id}"
}

output "etcd_ip_list" {
  value = ["${null_resource.etcd_address.*.triggers.address}"]
}

output "master_address" {
  value = "${aws_route53_record.master-elb.name}"
}

output "worker_security_group_id" {
  value = "${aws_security_group.worker.id}"
}

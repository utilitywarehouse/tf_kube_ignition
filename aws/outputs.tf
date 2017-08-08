output "etcd_ip_list" {
  value = "${aws_instance.etcd.*.private_ip}"
}

output "master_address" {
  value = "${aws_route53_record.master-elb.name}"
}

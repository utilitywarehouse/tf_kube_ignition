// IAM instance role
resource "aws_iam_role" "etcd" {
  name = "${var.cluster_name}_etcd"

  assume_role_policy = <<EOS
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOS
}

resource "aws_iam_instance_profile" "etcd" {
  name = "${var.cluster_name}-etcd"
  role = "${aws_iam_role.etcd.name}"
}

resource "aws_iam_role_policy" "etcd" {
  name = "${var.cluster_name}-etcd"
  role = "${aws_iam_role.etcd.id}"

  policy = <<EOS
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:List*",
        "s3:Get*"
      ],
      "Resource": [ "arn:aws:s3:::${var.ssl_s3_bucket_name}/*" ]
    }
  ]
}
EOS
}

// EC2 instance
# module "etcd_address" {
#   source = "./cidrhost"
#
#   count      = "${var.etcd_instance_count}"
#   cidr_block = "${data.aws_subnet.private.*.cidr_block[count.index]}"
#   host       = "${count.index}"
# }

resource "null_resource" "etcd_address" {
  count = "${var.etcd_instance_count}"

  triggers {
    address = "${cidrhost(data.aws_subnet.private.*.cidr_block[count.index], 4 + (count.index / length(var.private_subnet_ids)))}"
  }
}

resource "aws_instance" "etcd" {
  count                  = "${var.etcd_instance_count}"
  ami                    = "${var.containerlinux_ami_id}"
  instance_type          = "${var.etcd_instance_type}"
  user_data              = "${var.etcd_user_data[count.index]}"
  iam_instance_profile   = "${aws_iam_instance_profile.etcd.name}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.etcd.id}"]
  subnet_id              = "${var.private_subnet_ids[count.index]}"
  private_ip             = "${null_resource.etcd_address.*.triggers.address[count.index]}"

  lifecycle {
    ignore_changes = ["ami"]
  }

  root_block_device = {
    volume_type = "gp2"
    volume_size = "30"
  }

  # Instance tags
  tags {
    "Name"        = "etcd ${var.cluster_name} ${var.environment} server ${count.index}"
    "environment" = "${var.environment}"
    "instance"    = "${count.index}"
    "role"        = "${var.cluster_name}"

    # used by kubelet's aws provider to determine cluster
    "KubernetesCluster" = "${var.cluster_name}"
  }
}

resource "aws_ebs_volume" "etcd-data" {
  count             = "${var.etcd_instance_count}"
  availability_zone = "${data.aws_subnet.private.*.availability_zone[count.index]}"
  size              = 50
  type              = "gp2"

  tags {
    "Name"        = "etcd ${var.cluster_name} ${var.environment} data vol ${count.index}"
    "environment" = "${var.environment}"
    "role"        = "${var.cluster_name}"

    # used by kubelet's aws provider to determine cluster
    "KubernetesCluster" = "${var.cluster_name}"

    # used by snapshot-manager lambda
    "SnapshotManager"       = "true"
    "SnapshotRetentionDays" = "3"
  }
}

resource "aws_volume_attachment" "etcd-data" {
  count       = "${var.etcd_instance_count}"
  device_name = "/dev/xvdf"
  volume_id   = "${aws_ebs_volume.etcd-data.*.id[count.index]}"
  instance_id = "${aws_instance.etcd.*.id[count.index]}"
}

// VPC Security Group
resource "aws_security_group" "etcd" {
  name        = "${var.cluster_name}-etcd"
  description = "k8s etcd security group"
  vpc_id      = "${var.vpc_id}"

  tags {
    "Name" = "etcd ${var.cluster_name} ${var.environment} sg"

    // used by kubelet's aws provider to determine cluster
    "KubernetesCluster" = "${var.cluster_name}"
  }
}

resource "aws_security_group_rule" "egress-from-etcd" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.etcd.id}"
}

resource "aws_security_group_rule" "ingress-etcd-to-self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = "${aws_security_group.etcd.id}"
  security_group_id        = "${aws_security_group.etcd.id}"
}

resource "aws_security_group_rule" "ingress-master-to-etcd" {
  type                     = "ingress"
  from_port                = 2379
  to_port                  = 2379
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.master.id}"
  security_group_id        = "${aws_security_group.etcd.id}"
}

# prometheus needs to scrape etcd metrics
resource "aws_security_group_rule" "ingress-worker-to-etcd-client" {
  type                     = "ingress"
  from_port                = 2379
  to_port                  = 2379
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.worker.id}"
  security_group_id        = "${aws_security_group.etcd.id}"
}

# prometheus needs to scrape node_exporter metrics
resource "aws_security_group_rule" "ingress-worker-to-etcd-node-metrics" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.worker.id}"
  security_group_id        = "${aws_security_group.etcd.id}"
}

resource "aws_security_group_rule" "etcd-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${var.ssh_security_group_id}"
  security_group_id        = "${aws_security_group.etcd.id}"
}

// Route53 records
resource "aws_route53_record" "etcd-all" {
  zone_id = "${var.route53_zone_id}"
  count   = 1
  name    = "etcd.${var.cluster_name}.${data.aws_route53_zone.main.name}"
  type    = "A"
  ttl     = "30"
  records = ["${aws_instance.etcd.*.private_ip}"]
}

resource "aws_route53_record" "etcd-by-instance" {
  count   = "${var.etcd_instance_count}"
  zone_id = "${var.route53_zone_id}"
  name    = "${count.index}.etcd.${var.cluster_name}.${data.aws_route53_zone.main.name}"
  type    = "A"
  ttl     = "30"
  records = ["${aws_instance.etcd.*.private_ip[count.index]}"]
}

resource "aws_route53_record" "etcd-PTR-by-instance" {
  count   = "${var.etcd_instance_count}"
  zone_id = "${var.route53_inaddr_arpa_zone_id}"
  name    = "${element(split(".", aws_instance.etcd.*.private_ip[count.index]), 3)}.${element(split(".", aws_instance.etcd.*.private_ip[count.index]), 2)}.${data.aws_route53_zone.inaddr_arpa.name}"
  type    = "PTR"
  ttl     = "30"
  records = ["${aws_route53_record.etcd-by-instance.*.name[count.index]}."]
}

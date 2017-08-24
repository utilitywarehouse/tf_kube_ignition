resource "null_resource" "cfssl_address" {
  triggers {
    subnet  = "${var.private_subnet_ids[0]}"
    address = "${cidrhost(data.aws_subnet.private.*.cidr_block[0], 5)}"
  }
}

// EC2 Instance
resource "aws_instance" "cfssl" {
  ami                    = "${var.containerlinux_ami_id}"
  instance_type          = "t2.nano"
  user_data              = "${var.cfssl_user_data}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.cfssl.id}"]
  subnet_id              = "${null_resource.cfssl_address.triggers.subnet}"
  private_ip             = "${null_resource.cfssl_address.triggers.address}"

  lifecycle {
    ignore_changes = ["ami"]
  }

  root_block_device = {
    volume_type = "gp2"
    volume_size = "8"
  }

  # Instance tags
  tags {
    "Name" = "cfssl ${var.cluster_name}"
    "role" = "${var.cluster_name}"

    # used by kubelet's aws provider to determine cluster
    "KubernetesCluster" = "${var.cluster_name}"
  }
}

// VPC Security Group
resource "aws_security_group" "cfssl" {
  name        = "${var.cluster_name}-cfssl"
  description = "k8s cfssl security group"
  vpc_id      = "${var.vpc_id}"

  tags {
    "Name" = "cfssl ${var.cluster_name}"

    // used by kubelet's aws provider to determine cluster
    "KubernetesCluster" = "${var.cluster_name}"
  }
}

resource "aws_security_group_rule" "egress-from-cfssl" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.cfssl.id}"
}

resource "aws_security_group_rule" "ingress-cfssl-to-self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = "${aws_security_group.cfssl.id}"
  security_group_id        = "${aws_security_group.cfssl.id}"
}

resource "aws_security_group_rule" "cfssl-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${var.ssh_security_group_id}"
  security_group_id        = "${aws_security_group.cfssl.id}"
}

resource "aws_security_group_rule" "ingress-etcd-to-cfssl" {
  type                     = "ingress"
  from_port                = 8888
  to_port                  = 8888
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.etcd.id}"
  security_group_id        = "${aws_security_group.cfssl.id}"
}

resource "aws_security_group_rule" "ingress-master-to-cfssl" {
  type                     = "ingress"
  from_port                = 8888
  to_port                  = 8888
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.master.id}"
  security_group_id        = "${aws_security_group.cfssl.id}"
}

resource "aws_security_group_rule" "ingress-worker-to-cfssl" {
  type                     = "ingress"
  from_port                = 8888
  to_port                  = 8888
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.worker.id}"
  security_group_id        = "${aws_security_group.cfssl.id}"
}

// IAM instance role
resource "aws_iam_role" "worker" {
  name = "${var.cluster_name}_worker"

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

resource "aws_iam_instance_profile" "worker" {
  name = "${var.cluster_name}-worker"
  role = "${aws_iam_role.worker.name}"
}

resource "aws_iam_role_policy" "worker" {
  name = "${var.cluster_name}-worker"
  role = "${aws_iam_role.worker.id}"

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
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:ReplaceRoute",
        "ec2:DescribeRouteTables",
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}
EOS
}

// EC2 AutoScaling groups
resource "aws_launch_configuration" "worker" {
  iam_instance_profile = "${aws_iam_instance_profile.worker.name}"
  image_id             = "${var.containerlinux_ami_id}"
  instance_type        = "${var.worker_instance_type}"
  key_name             = "${var.key_name}"
  security_groups      = ["${aws_security_group.worker.id}"]
  user_data            = "${var.worker_user_data}"

  lifecycle {
    create_before_destroy = true
  }

  # Storage
  root_block_device {
    volume_size = 52
    volume_type = "gp2"
  }
}

resource "aws_launch_configuration" "worker-spot" {
  iam_instance_profile = "${aws_iam_instance_profile.worker.name}"
  image_id             = "${var.containerlinux_ami_id}"
  instance_type        = "${var.worker_instance_type}"
  spot_price           = "${var.worker_spot_instance_bid}"
  key_name             = "${var.key_name}"
  security_groups      = ["${aws_security_group.worker.id}"]
  user_data            = "${var.worker_user_data}"

  lifecycle {
    create_before_destroy = true
  }

  # Storage
  root_block_device {
    volume_size = 52
    volume_type = "gp2"
  }
}

resource "aws_autoscaling_group" "worker" {
  name                      = "worker ${var.cluster_name}"
  desired_capacity          = "${var.worker_ondemand_instance_count}"
  max_size                  = "${var.worker_ondemand_instance_count + var.worker_spot_instance_count}"
  min_size                  = "${var.worker_ondemand_instance_count}"
  health_check_grace_period = 60
  health_check_type         = "EC2"
  force_delete              = true
  termination_policies      = ["NewestInstance"]
  enabled_metrics           = ["GroupInServiceInstances", "GroupTotalInstances"]
  launch_configuration      = "${aws_launch_configuration.worker.name}"
  vpc_zone_identifier       = ["${var.private_subnet_ids}"]
  load_balancers            = ["${var.worker_elb_names}"]
  default_cooldown          = 60

  tag {
    key                 = "builtWith"
    value               = "terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Cluster"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  # used by kubelet's aws provider to determine cluster
  tag {
    key                 = "KubernetesCluster"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "worker ${var.cluster_name}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "worker-spot" {
  name                      = "worker-spot ${var.cluster_name}"
  desired_capacity          = "${var.worker_spot_instance_count}"
  max_size                  = "${var.worker_spot_instance_count}"
  min_size                  = "${var.worker_spot_instance_count}"
  health_check_grace_period = 60
  health_check_type         = "EC2"
  force_delete              = true
  termination_policies      = ["NewestInstance"]
  enabled_metrics           = ["GroupInServiceInstances", "GroupTotalInstances"]
  launch_configuration      = "${aws_launch_configuration.worker-spot.name}"
  vpc_zone_identifier       = ["${var.private_subnet_ids}"]
  load_balancers            = ["${var.worker_elb_names}"]
  default_cooldown          = 60

  tag {
    key                 = "builtWith"
    value               = "terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Cluster"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  # used by kubelet's aws provider to determine cluster
  tag {
    key                 = "KubernetesCluster"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "worker-spot ${var.cluster_name}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale-up-on-demand" {
  name                   = "scale-up-on-demand"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.worker.name}"
}

resource "aws_autoscaling_policy" "scale-down-on-demand" {
  name                   = "scale-down-on-demand"
  scaling_adjustment     = "${var.worker_ondemand_instance_count}"
  adjustment_type        = "ExactCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.worker.name}"
}

resource "aws_cloudwatch_metric_alarm" "spot-instances-terminated" {
  alarm_name                = "spot-instances-terminated"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "GroupInServiceInstances"
  namespace                 = "AWS/AutoScaling"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "${var.worker_spot_instance_count}"
  alarm_description         = "This metric checks if spot instances have been terminated."
  insufficient_data_actions = []
  alarm_actions             = ["${aws_autoscaling_policy.scale-up-on-demand.arn}"]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.worker-spot.name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "spot-instances-fulfilled" {
  alarm_name                = "spot-instances-fulfilled"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "GroupInServiceInstances"
  namespace                 = "AWS/AutoScaling"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "${var.worker_spot_instance_count}"
  alarm_description         = "This metric checks if all spot bids have been fulfilled."
  insufficient_data_actions = []
  alarm_actions             = ["${aws_autoscaling_policy.scale-down-on-demand.arn}"]

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.worker-spot.name}"
  }
}

// VPC security groups
resource "aws_security_group" "worker" {
  name        = "${var.cluster_name}-worker"
  description = "k8s worker security group"
  vpc_id      = "${var.vpc_id}"

  tags {
    "Name"              = "worker ${var.cluster_name}"
    "KubernetesCluster" = "${var.cluster_name}"        // used by kubelet's aws provider to determine cluster
  }
}

resource "aws_security_group_rule" "egress-from-worker" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.worker.id}"
}

resource "aws_security_group_rule" "ingress-worker-to-self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = "${aws_security_group.worker.id}"
  security_group_id        = "${aws_security_group.worker.id}"
}

resource "aws_security_group_rule" "ingress-master-to-worker" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = "${aws_security_group.master.id}"
  security_group_id        = "${aws_security_group.worker.id}"
}

resource "aws_security_group_rule" "worker-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${var.ssh_security_group_id}"
  security_group_id        = "${aws_security_group.worker.id}"
}

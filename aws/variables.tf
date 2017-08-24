// generic
variable "region" {
  description = "The AWS region to deploy the cluster in."
}

variable "cluster_name" {
  description = "And identifier for the cluster."
}

variable "vpc_id" {
  description = "The ID of the VPC to create resources in."
}

variable "public_subnet_ids" {
  description = "A list of the available public subnets in which EC2 instances can be created."
  type        = "list"
}

variable "private_subnet_ids" {
  description = "A list of the available private subnets in which EC2 instances can be created."
  type        = "list"
}

variable "key_name" {
  description = "The name of the AWS Key Pair to be used when launching EC2 instances."
}

variable "ssh_security_group_id" {
  description = "The ID of the Security Group to open port 22 to."
}

variable "ssl_s3_bucket_name" {
  description = "The name of the S3 bucket that will be used to hold SSL certificates and keys for the nodes."
}

variable "containerlinux_ami_id" {
  description = "The ID of the Container Linux AMI to use for instances."
}

variable "route53_zone_id" {
  description = "The ID of the Route53 Zone to add records to."
}

variable "route53_inaddr_arpa_zone_id" {
  description = "The ID of the Route53 Zone to add pointer records to."
}

// cfssl server
variable "cfssl_user_data" {
  description = "The user data to provide to the cfssl server."
}

// etcd nodes
variable "etcd_instance_count" {
  default     = "3"
  description = "The number of etcd instances to launch."
}

variable "etcd_instance_type" {
  default     = "t2.small"
  description = "The type of etcd instances to launch."
}

variable "etcd_user_data" {
  description = "A list of the user data to provide to the etcd instances. Must be the same length as etcd_instance_count."
  type        = "list"
}

// master nodes
variable "master_instance_count" {
  default     = "3"
  description = "The number of kubernetes master instances to launch."
}

variable "master_instance_type" {
  default     = "t2.small"
  description = "The type of kubernetes master instances to launch."
}

variable "master_user_data" {
  description = "The user data to provide to the kubernetes master instances."
}

// worker nodes
variable "worker_ondemand_instance_count" {
  default     = "3"
  description = "The number of kubernetes worker on-demand instances to launch."
}

variable "worker_spot_instance_count" {
  default     = "0"
  description = "The number of kubernetes worker spot instances to launch."
}

variable "worker_spot_instance_bid" {
  description = "The price to bid for kubernetes worker spot instances."
}

variable "worker_instance_type" {
  default     = "m4.large"
  description = "The type of kubernetes worker instances to launch."
}

variable "worker_user_data" {
  description = "The user data to provide to the kubernetes worker instances."
}

variable "worker_elb_names" {
  description = "A list of ELB names to be attached to the worker autoscaling groups."
  type        = "list"
}

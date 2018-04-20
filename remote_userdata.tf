resource "aws_s3_bucket" "userdata" {
  bucket = "uw-userdata.${var.role_name}.${var.account}"
  acl    = "public-read"

  tags = "${map(
    "Name" , "uw-userdata.${var.role_name}.${var.account}",
    "terraform.io/component", "${var.role_name}/userdata",
    "kubernetes.io/cluster/${var.role_name}", "owned",
	)}"
}

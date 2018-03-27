variable "volumeid" {}
variable "mountpoint" {}

variable "user" {
  default = "root"
}

variable "group" {
  default = "root"
}

variable "filesystem" {
  default = "ext4"
}

data "ignition_systemd_unit" "disk-formatter" {
  name = "disk-formatter-${var.volumeid}.service"

  content = <<EOS
[Unit]
Description=Format device with volume-id: ${var.volumeid}, if it has no filesystem
[Service]
Type=oneshot
RemainAfterExit=yes
Environment=DEVICE=/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${var.volumeid}
ExecStart=/bin/sh -c "fsck -a $${DEVICE} || (mkfs.${var.filesystem} $${DEVICE} && mount $${DEVICE} /mnt && chown -R ${var.user}:${var.group} /mnt && umount /mnt)"
EOS
}

data "ignition_systemd_unit" "disk-mounter" {
  name = "${join("-", compact(split("/", var.mountpoint)))}.mount"

  content = <<EOS
[Unit]
Description=Mount device ${var.volumeid} to ${var.mountpoint}
Requires=${data.ignition_systemd_unit.disk-formatter.name}
After=${data.ignition_systemd_unit.disk-formatter.name}
[Mount]
What=/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${var.volumeid}
Where=${var.mountpoint}
Type=${var.filesystem}
EOS
}

output "systemd_units" {
  value = [
    "${data.ignition_systemd_unit.disk-formatter.id}",
    "${data.ignition_systemd_unit.disk-mounter.id}",
  ]
}

output "mount_unit_name" {
  value = "${data.ignition_systemd_unit.disk-mounter.name}"
}

variable "device" {}
variable "mountpoint" {}
variable "user" {}
variable "group" {}

data "ignition_systemd_unit" "disk-formatter" {
  name = "disk-formatter-${var.device}.service"

  content = <<EOS
[Unit]
Description=Format device ${var.device}, if it has no filesystem
After=dev-${var.device}.device
Requires=dev-${var.device}.device
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c "fsck -a /dev/${var.device} || (mkfs.ext4 /dev/${var.device} && mount /dev/${var.device} /mnt && chown -R ${var.user}:${var.group} /mnt && umount /mnt)"
EOS
}

data "ignition_systemd_unit" "disk-mounter" {
  name = "${join("-", compact(split("/", var.mountpoint)))}.mount"

  content = <<EOS
[Unit]
Description=Mount device ${var.device} volume to ${var.mountpoint}
Requires=disk-formatter-${var.device}.service
After=disk-formatter-${var.device}.service
[Mount]
What=/dev/${var.device}
Where=${var.mountpoint}
Type=ext4
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

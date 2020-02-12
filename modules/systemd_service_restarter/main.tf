variable "on_calendar" {}
variable "service_name" {}

data "ignition_systemd_unit" "service-restart" {
  name = "${var.service_name}-restart.service"

  content = <<EOS
[Unit]
Description=Restart ${var.service_name}.service
[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl try-restart ${var.service_name}.service
EOS
}

data "ignition_systemd_unit" "service-restart-timer" {
  name = "${var.service_name}-restart.timer"

  content = <<EOS
[Unit]
Description=Run ${var.service_name}-restart.service periodically
[Timer]
OnCalendar=${var.on_calendar}
AccuracySec=1s
RandomizedDelaySec=60min
[Install]
WantedBy=timers.target
EOS
}

output "systemd_units" {
  value = [
    data.ignition_systemd_unit.service-restart.id,
    data.ignition_systemd_unit.service-restart-timer.id,
  ]
}

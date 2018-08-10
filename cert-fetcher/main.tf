variable "on_calendar" {}
variable "service_name" {}

data "ignition_systemd_unit" "cert-fetch-service" {
  name = "cert-fetch.service"

  content = <<EOS
[Unit]
Description=Fetch new certificates from cfssl server
[Service]
Type=oneshot
ExecStart=/opt/bin/cfssl-new-cert
EOS
}

data "ignition_systemd_unit" "cert-fetch-timer" {
  name = "cert-fetch.timer"

  content = <<EOS
[Unit]
Description=Fetch new certificates from cfssl server
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
    "${data.ignition_systemd_unit.cert-fetch-service.id}",
    "${data.ignition_systemd_unit.cert-fetch-timer.id}",
  ]
}

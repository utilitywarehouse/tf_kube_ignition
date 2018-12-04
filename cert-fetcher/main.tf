variable "on_calendar" {}

data "ignition_systemd_unit" "cert-fetch-service" {
  name = "cert-fetch.service"

  content = <<EOS
[Unit]
Description=Fetch new certificates from cfssl server
After=network-online.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'while ! /opt/bin/cfssl-new-cert; do echo "cfssl not ready, sleeping 5 seconds";sleep 5; done'
[Install]
WantedBy=multi-user.target
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

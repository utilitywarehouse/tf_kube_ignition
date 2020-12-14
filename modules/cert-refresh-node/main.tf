variable "on_calendar" {
  type = string
}

data "ignition_systemd_unit" "cert-refresh" {
  name = "cert-refresh.service"

  content = <<EOS
[Unit]
Description=Fetch new certificates from cfssl server and restart components to reload certs
Requires=containerd.service
After=network-online.target
[Service]
Type=oneshot
ExecStart=/opt/bin/cfssl-new-cert
ExecStart=/opt/bin/cfssl-new-kubelet-cert
# Hack to reload certs on control plane tier
#  https://github.com/kubernetes/kubernetes/issues/46287
ExecStart=/usr/bin/systemctl try-restart kubelet.service
[Install]
WantedBy=multi-user.target
EOS
}

data "ignition_systemd_unit" "cert-refresh-timer" {
  name = "cert-refresh.timer"

  content = <<EOS
[Unit]
Description=Fetch new certificates from cfssl server and restart components to reload certs
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
    data.ignition_systemd_unit.cert-refresh.rendered,
    data.ignition_systemd_unit.cert-refresh-timer.rendered,
  ]
}

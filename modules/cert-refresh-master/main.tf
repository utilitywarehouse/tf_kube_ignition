variable "on_calendar" {
  type = string
}

data "ignition_systemd_unit" "cert-refresh" {
  name = "cert-refresh.service"

  content = <<EOS
[Unit]
Description=Fetch new certificates from cfssl server and restart components to reload certs
Requires=containerd.service prepare-crictl.service
After=network-online.target
[Service]
Type=oneshot
ExecStart=/opt/bin/cfssl-keys-and-certs-get
ExecStart=/opt/bin/cfssl-new-node-cert
ExecStart=/opt/bin/cfssl-new-kubelet-cert
ExecStart=/opt/bin/cfssl-new-apiserver-cert
ExecStart=/opt/bin/cfssl-new-apiserver-kubelet-client-cert
ExecStart=/opt/bin/cfssl-new-scheduler-cert
ExecStart=/opt/bin/cfssl-new-controller-manager-cert
# Hack to reload certs on control plane tier
#  https://github.com/kubernetes/kubernetes/issues/46287
ExecStart=-/bin/sh -c "/opt/bin/crictl stop $(/opt/bin/crictl ps -q --label io.kubernetes.container.name=kube-controller-manager)"
ExecStart=-/bin/sh -c "/opt/bin/crictl stop $(/opt/bin/crictl ps -q --label io.kubernetes.container.name=kube-apiserver)"
ExecStart=-/bin/sh -c "/opt/bin/crictl stop $(/opt/bin/crictl ps -q --label io.kubernetes.container.name=kube-scheduler)"
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

#!/bin/sh

set -o errexit

mkdir -p ${path}
cd ${path}

_ip="$(${get_ip})"
_hostname="$(hostname)"

# workaround for https://github.com/kubernetes/kubernetes/issues/72102
# include first member's ip in SAN for all nodes
# this replicates kubeadm behaviour to include first node's ip, as kubeadm
# generates all certificates on the first node
_first_member_ip="$(echo $${_ip} | sed 's/[0-9]*$/4/')"

/opt/bin/cfssl gencert \
  -config=/etc/cfssl/config.json \
  -profile=${profile} \
  -hostname="$${_ip},$${_first_member_ip},$${_hostname}${extra_names != "" ? ",${extra_names}" : "" }" - << EOF | /opt/bin/cfssljson -bare ${cert_name}
{"CN":"${cn}",${org != "" ? "\"names\":[{\"O\":\"${org}\"}]," : ""}"key":{"algo":"ecdsa","size":384}}
EOF

/opt/bin/cfssl info -config=/etc/cfssl/config.json | /opt/bin/cfssljson -bare ca

chown ${user}:${group} ./*

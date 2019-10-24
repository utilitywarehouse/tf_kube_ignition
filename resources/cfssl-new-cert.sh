#!/bin/sh

set -o errexit

mkdir -p ${path}
cd ${path}

_ip="$(${get_ip})"
_hostname="$(${get_hostname})"

/opt/bin/cfssl gencert \
  -config=/etc/cfssl/config.json \
  -profile=${profile} \
  -hostname="$${_ip},$${_hostname}${extra_names != "" ? ",${extra_names}" : "" }" - << EOF | /opt/bin/cfssljson -bare ${cert_name}
{"CN":"${cn}",${org != "" ? "\"names\":[{\"O\":\"${org}\"}]," : ""}"key":{"algo":"ecdsa","size":384}}
EOF

/opt/bin/cfssl info -config=/etc/cfssl/config.json | /opt/bin/cfssljson -bare ca

chown ${user}:${group} ./*

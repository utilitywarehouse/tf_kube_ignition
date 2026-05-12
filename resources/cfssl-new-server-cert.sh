#!/bin/sh

set -o errexit

mkdir -p ${path}
cd ${path}

_ip="$(${get_ip})"
_hostname="$(${get_hostname})"

_hostname_san=""
if [ -n "$_hostname" ]; then
  _hostname_san=",$${_hostname}"
fi

_extra_names_san=""
if [ -n "${extra_names}" ]; then
  _extra_names_san=",${extra_names}"
fi

/opt/bin/cfssl gencert \
  -config=/etc/cfssl/config.json \
  -profile=${profile} \
  -hostname="$${_ip}$${_hostname_san}$${_extra_names_san}" - << EOF | /opt/bin/cfssljson -bare ${cert_name}
{"CN":"${cn}",${org != "" ? "\"names\":[{\"O\":\"${org}\"}]," : ""}"key":{"algo":"ecdsa","size":384}}
EOF

/opt/bin/cfssl info -config=/etc/cfssl/config.json | /opt/bin/cfssljson -bare ca

chown ${user}:${group} ./*

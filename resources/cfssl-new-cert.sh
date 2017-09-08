#!/bin/sh

set -o errexit

mkdir -p ${path}
cd ${path}

_ip="$(ip addr show dev eth0 | grep 'inet ' | awk '{ print $2; }' | cut -d/ -f1)"
_hostname="$(hostname)"

/opt/bin/cfssl gencert \
  -config=/etc/cfssl/config.json \
  -profile=${profile} \
  -hostname="$${_ip},$${_hostname},${hosts}" - << EOF | /opt/bin/cfssljson -bare "${role}"
{"CN":"${role}","key":{"algo":"ecdsa","size":384}}
EOF

/opt/bin/cfssl info -config=/etc/cfssl/config.json | /opt/bin/cfssljson -bare ca

chown ${user}:${group} ./*

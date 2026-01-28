#!/bin/bash

_args="/etc/cfssl/ca-csr.json"

if [ ! -f "${_args}" ]; then
    echo 'ca-csr.json not found'
    exit 1
fi

[ -f ca-key.pem ] && _args="-ca-key=ca-key.pem ${_args}"

[ -f ca-key.pem ] && [ -f ca.pem ] \
    && (( "$(date +%s)" < "$(date -d "$(/opt/bin/cfssl certinfo -cert=/var/lib/cfssl/ca.pem | jq -r '.not_after')" +%s)" - 90 * 24 * 3600 )) \
    && exit 0

/opt/bin/cfssl gencert -initca ${_args} | /opt/bin/cfssljson -bare ca -

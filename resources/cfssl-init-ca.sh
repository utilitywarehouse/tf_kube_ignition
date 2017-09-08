#!/bin/bash

_args="/etc/cfssl/ca-csr.json"

if [ ! -f "${_args}" ]; then
    echo 'ca-csr.json not found'
    exit 1
fi

if [ -f ca.pem ] && [ -f ca-key.pem ]; then
    [ "$(/opt/bin/cfssl certinfo -cert=ca.pem | jq -r '.not_after')" \< "$(date +%Y-%m-%dT%H:%M:%IZ)" ] \
        &&  /opt/bin/cfssl gencert\
            -renewca \
            -ca=ca.pem \
            -ca-key=ca-key.pem \
            ${_args} | /opt/bin/cfssljson -bare ca -
    exit 0
fi

[ -f ca-key.pem ] && _args="-ca-key=ca-key.pem ${_args}"

/opt/bin/cfssl gencert -initca ${_args} | /opt/bin/cfssljson -bare ca -

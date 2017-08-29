#!/bin/bash

_args="ca-csr.json"

if [ ! -f "${_args}" ]; then
    echo 'ca-csr.json not found'
    exit 1
fi

if [ -f ca.pem ] && [ -f ca-key.pem ]; then
    [ "$(cfssl certinfo -cert=ca.pem | jq -r '.not_after')" \< "$(date -Iseconds)Z" ] \
        &&  /opt/bin/cfssl gencert\
            -renewca \
            -ca=ca.pem \
            -ca-key=ca-key.pem \
            ca-csr.json | /opt/bin/cfssljson -bare ca -
    exit 0
fi

[ -f ca-key.pem ] && _args="-ca-key=ca-key.pem ${_args}"

/opt/bin/cfssl gencert -initca ${_args} | /opt/bin/cfssljson -bare ca -

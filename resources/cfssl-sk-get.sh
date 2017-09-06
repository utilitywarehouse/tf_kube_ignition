#!/bin/sh

set -o errexit

mkdir -p ${path}
cd ${path}

/usr/bin/curl -Ls -o signing-key.pem \
    -H 'Authorization: Basic ${auth}' \
    http://$(jq -r '.remotes.server | split(":")[0]' /etc/cfssl/config.json):8889/signing-key

/usr/bin/chmod 0600 signing-key.pem

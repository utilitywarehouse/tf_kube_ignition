#!/bin/sh

set -o errexit

mkdir -p ${path}
cd ${path}

/usr/bin/curl -Ls -o signing-key.pem \
    -H 'Authorization: Basic ${auth}' \
    http://$(jq -r '.remotes.server | split(":")[0]' /etc/cfssl/config.json):8889/signing-key

# Check that we got a valid ec key
set +e
/usr/bin/openssl ec -in ${path}/signing-key.pem -noout
if [ $? -ne 0 ]; then
	echo "Failed to get EC key from cfssl server";
	exit 1;
fi
set -e

# Give the right permissions
/usr/bin/chmod 0600 signing-key.pem

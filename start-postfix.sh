#!/bin/bash -e

set -o pipefail

function handleSig {
    echo "Stopping postfix..."
    postfix stop
    echo "Postfix stopped."
}

trap handleSig SIGINT SIGTERM SIGQUIT SIGHUP

cp /etc/postfix/main.cf /tmp/

if [ "$RECEIVE_FOR_DOMAINS" == "" ]; then
    echo "The RECEIVE_FOR_DOMAINS environment variable must be specifid. This is a space or comma separated list of virtual domains to receive email for." >&2
    exit 1;
fi

if [ "$EMAIL_HOST" == "" ]; then
    echo "The public hostname must be specific in the EMAIL_HOST environment variable." >&2
    exit 1;
fi

echo "$EMAIL_HOST" > /etc/mailname

postconf -e \
	 "virtual_mailbox_domains = $RECEIVE_FOR_DOMAINS" \
	 "smtpd_banner=${EMAIL_HOST} ESMTP \$mail_name (Ubuntu)"

readonly CERT_FILE=/etc/postfix/cert.pem
readonly KEY_FILE=/etc/postfix/privkey.pem

if [ ! -f "$CERT_FILE" ]; then
    echo "Certificate file [$CERT_FILE] not found. The certificate file needs to be mounted into the container." >&2
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "Private key file [$KEY_FILE] not found. They private key needs to be mounted into the container." >&2
    exit 1
fi

echo "Starting postfix"
postfix start-fg &

cat /etc/postfix/main.cf

echo "Postfix started."

CERT_MD5=$(md5sum "$CERT_FILE" | cut -d ' ' -f1)
KEY_MD5=$(md5sum "$KEY_FILE" | cut -d ' ' -f1)

while true; do
    postmap /etc/postfix/virtual # update with any new entries from /etc/postfix/virtual

    NEW_CERT_MD5=$(md5sum "$CERT_FILE" | cut -d ' ' -f1)
    NEW_KEY_MD5=$(md5sum "$KEY_FILE" | cut -d ' ' -f1)

    if [ "$NEW_CERT_MD5" != "$CERT_MD5" ] || [ "$NEW_KEY_MD5" != "$KEY_MD5" ]; then
	CERT_MD5="$NEW_CERT_MD5"
	KEY_MD5="$NEW_KEY_MD5"

	echo "Certificate or private key changed. Reloading."
	postfix reload
    fi
    
    sleep 60 &
    wait $!
done

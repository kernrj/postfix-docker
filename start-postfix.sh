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

if [ "$KEY_FILE" == "" ]; then
    echo "Specify the path (within the container) to the private key file with KEY_FILE" >&2
    exit 1;
fi

if [ "$CERT_FILE" == "" ]; then
    echo "Specify the path (within the container) to the certificate file with CERT_FILE" >&2
    exit 1;
fi

echo "$EMAIL_HOST" > /etc/mailname

cat /etc/postfix/main.cf | \
    sed -E "s/email_host_replace_me/$EMAIL_HOST/g" | \
    sed -E "s|^(mydestination[= ].*)\$|\\1 $RECEIVE_FOR_DOMAINS|" | \
    sed -E "s|^(smtpd_tls_cert_file[= ].*)\$|smtpd_tls_cert_file=$CERT_FILE|" | \
    sed -E "s|^(smtpd_tls_key_file[= ].*)\$|smtpd_tls_key_file=$KEY_FILE|" | \
    sed -E "s|^(smtpd_banner[= ].*)\$|smtpd_banner = $EMAIL_HOST ESMTP \$mail_name \(Ubuntu\)|" \
	> /tmp/main.cf

mv /tmp/main.cf /etc/postfix/

FILE_RETRIES=0
readonly FILE_MAX_RETRIES=20
while [ ! -f "$CERT_FILE" ] && [ "$FILE_RETRIES" -lt "$FILE_MAX_RETRIES" ]; do
    echo "Certificate file [$CERT_FILE] does not exist. Waiting..."
    ls -l $(dirname "$CERT_FILE")
    sleep 5
    ((FILE_RETRIES++)) || true
done

if [ ! -f "$CERT_FILE" ]; then
    echo "Certificate file [$CERT_FILE] not found. Exiting." >&2
    exit 1
fi

FILE_RETRIES=0
readonly 
while [ ! -f "$KEY_FILE" ] && [ "$FILE_RETRIES" -lt "$FILE_MAX_RETRIES" ]; do
    echo "Private key file [$KEY_FILE] does not exist. Waiting..."
    sleep 5
    ((FILE_RETRIES++)) || true
done

if [ ! -f "$KEY_FILE" ]; then
    echo "Private key file [$KEY_FILE] not found. Exiting." >&2
    exit 1
fi

echo "Starting postfix"
postfix start-fg &
readonly POSTFIX_PID=$!

cat /etc/postfix/main.cf

echo "Postfix started."

CERT_MD5=$(md5sum "$CERT_FILE" | cut -d ' ' -f1)
KEY_MD5=$(md5sum "$KEY_FILE" | cut -d ' ' -f1)

while true; do
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
wait $POSTFIX_PID


To change the server's mailer_type, set the MAILER_TYPE build arg when building the container.
For example:
```
docker build -t my-postfix --build-arg MAILER_TYPE="Internet Site" .
```

Required variables:
CERT_FILE: Path to the certificate file within the container
KEY_FILE: Path to the private key file within the container
EMAIL_HOST: The hostname of the server. This should match the reverse-dns for the server's IP address."
RECEIVE_FOR_DOMAINS: A space- or comma-separated list of virtual domains this server receives email for.

Example:
```
docker run \
    --mount type=bind,source=/etc/letsencrypt/live/your-email-servers-hostname.com/privkey.pem,destination=/certs/privkey.pem,readonly=true \
    --mount type=bind,source=/etc/letsencrypt/live/your-email-servers-hostname.com/fullchain.pem,destination=/certs/fullchain.pem,readonly=true \
    -e CERT_FILE=/certs/fullchain.pem \
    -e KEY_FILE=/certs/privkey.pem \
    -e RECEIVE_FOR_DOMAINS="domain-to-receive-email-for.com another-domain-to-receive-email-for.com" \
    -e EMAIL_HOST=your-email-servers-hostname.com \
    --rm \
    -p 25:25 \
    kernrj/postfix
```
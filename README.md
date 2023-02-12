# Dockerfile for a Postfix SMTP server


## Building
The default server mailer_type is "Internet Site".
```
docker build -t my-postfix .
```

To change the mailer_type, set the MAILER_TYPE build arg when building the container.
```
docker build -t my-postfix --build-arg MAILER_TYPE="Internet Site" .
```

# Ports to open
- 25: SMTP

## Required variables
- EMAIL_HOST: The hostname of the server. This should match the reverse-dns for the server's IP address.
- RECEIVE_FOR_DOMAINS: A comma-separated list of virtual domains this server receives email for.

## User aliases
This section is optional. An alias map can be mounted to /etc/postfix/virtual. It will be checked for new entries once per minute, but can be refreshed sooner by running `postmap /etc/postfix/virtual` inside the container.

## Example
```
docker run \
    --mount type=bind,source=/etc/letsencrypt/live/your-email-servers-hostname.com/privkey.pem,destination=/etc/postfix/privkey.pem,readonly=true \
    --mount type=bind,source=/etc/letsencrypt/live/your-email-servers-hostname.com/fullchain.pem,destination=/etc/postfix/fullchain.pem,readonly=true \
    -e RECEIVE_FOR_DOMAINS="domain-to-receive-email-for.com, another-domain-to-receive-email-for.com" \
    -e EMAIL_HOST=your-email-servers-hostname.com \
    --rm \
    -p 25:25 \
    kernrj/postfix
```

## docker-compose example
Example docker-compose.yml, also including [dovecot](https://github.com/kernrj/dovecot-docker.git) and [certbot](https://github.com/kernrj/certbot-docker.git):

```yml
version: '2'
services:
    postfix:
        image: kernrj/postfix
        restart: always
        volumes:
            - type: bind
              source: /etc/letsencrypt/live/mx1.your-server.com/fullchain.pem
              target: /etc/postfix/cert.pem
              read_only: true
            - type: bind
              source: /etc/letsencrypt/live/mx1.your-server.com/privkey.pem
              target: /etc/postfix/privkey.pem
              read_only: true
        environment:
            - EMAIL_HOST=mx1.your-server.com
            - RECEIVE_FOR_DOMAINS="domain1.com, domain2.com"
        ports:
            - 25:25

    dovecot:
        image: kernrj/dovecot
        restart: always
        volumes:
            - type: bind
              source: ./dovecot-passwd
              target: /etc/dovecot/passwd
              read_only: true
            - type: bind
              source: /etc/letsencrypt/live/mx1.your-server.com/fullchain.pem
              target: /etc/dovecot/cert.pem
              read_only: true
            - type: bind
              source: /etc/letsencrypt/live/mx1.your-server.com/privkey.pem
              target: /etc/dovecot/privkey.pem
              read_only: true
            - "./mail:/var/spool/vmail"
        environment:
            - POSTMASTER_EMAIL=your_email@example.com
        ports:
            - 993:993

    certbot: # creates or renews a certificate for the email server once every 30 days
        image: kernrj/certbot
        restart: always
        init: true
        volumes:
            - type: bind
              source: /etc/letsencrypt
              target: /etc/letsencrypt
        environment:
            - CERT_DOMAIN=mx1.yourserver.com
            - CERT_EMAIL=your_email@example.com
            - AGREE_TOS=yes # Specifying "yes" means you agree to the terms of service in the certbot application in the container being launched. This is equivalent to `certbot --agree-tos`.
        ports:
            - 80:80
```

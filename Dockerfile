FROM ubuntu:20.04

ENV LC_ALL C
ENV DEBIAN_FRONTEND="noninteractive"
ARG MAILER_TYPE="Internet Site"

RUN echo "Etc/UTC" > /etc/timezone && \
    rm -f /etc/localtime && \
    ln -s /usr/share/zoneinfo/UTC /etc/localtime && \
    apt-get update -y && \
    apt-get upgrade -y && \
    echo "postfix postfix/mailname string email_host_replace_me" | debconf-set-selections && \
    echo "postfix postfix/main_mailer_type string \"${MAILER_TYPE}\"" | debconf-set-selections && \
    apt-get install -y postfix mailutils tini && \
    postconf -e \
        'maillog_file = /dev/stdout' \
	'mydestination = localhost' \
	'relayhost =' \
	'virtual_alias_maps = hash:/etc/postfix/virtual' \
        'smtpd_tls_cert_file = /etc/postfix/cert.pem' \
        'smtpd_tls_key_file = /etc/postfix/privkey.pem' \
        'smtpd_relay_restrictions = permit_sasl_authenticated, reject_unauth_destination' \
        'smtpd_sender_restrictions = reject_sender_login_mismatch, reject_non_fqdn_sender, reject_unlisted_sender, permit_sasl_authenticated, reject_unauth_destination, reject_invalid_hostname, reject_unknown_sender_domain, reject_unauth_pipelining' \
        'smtpd_recipient_restrictions = reject_non_fqdn_recipient, reject_unverified_recipient, reject_invalid_hostname, reject_unauth_pipelining, reject_unknown_recipient_domain' \
	'virtual_transport = lmtp:inet:dovecot:24' \
        'smtpd_sasl_auth_enable = yes' \
        'smtp_tls_note_starttls_offer = yes' \
        'smtpd_sasl_security_options = noanonymous' \
        'smtpd_sasl_tls_security_options = noanonymous' \
        'smtpd_sasl_authenticated_header = yes' \
        'broken_sasl_auth_clients = yes' && \
    postconf -F lmtp/unix/chroot=- && \
    touch /etc/postfix/virtual

# lmtp can't run in a chroot because it needs to be able to resolve Dovecot's hostname

COPY start-postfix.sh /bin/

RUN chmod 755 /bin/start-postfix.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/start-postfix.sh"]

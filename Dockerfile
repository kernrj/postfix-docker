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
    apt-get install -y postfix mailutils && \
    egrep -v "^maillog_file[= ])" /etc/postfix/main.cf > /tmp/main.cf && \
    echo "maillog_file=/dev/stdout" >> /tmp/main.cf && \
    cat /tmp/main.cf | \
	sed -E 's|^(smtpd_tls_cert_file[= ].*)$|smtpd_tls_cert_file=/etc/ssl/certs/cert.pem|' | \
	sed -E 's|^(smtpd_tls_key_file[= ].*)$|smtpd_tls_key_file=/etc/ssl/certs/privkey.pem|' > /tmp/main2.cf && \
    mv /tmp/main2.cf /etc/postfix/main.cf && \
    rm -fr /tmp/*

COPY start-postfix.sh /bin/

RUN chmod 755 /bin/start-postfix.sh

ENTRYPOINT ["/bin/start-postfix.sh"]

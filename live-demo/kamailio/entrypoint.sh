#!/bin/bash
# Set default settings, pull repository, build
# app, etc., _if_ we are not given a different
# command.  If so, execute that command instead.
set -e
set -x

# Default values
: ${PID_FILE:="/var/run/kamailio.pid"}
: ${KAMAILIO_ARGS:="-DD -E -f /etc/kamailio/kamailio.cfg -P ${PID_FILE}"}

# confd requires that these variables actually be exported
export PID_FILE

# Make dispatcher.list exists
mkdir -p /data/kamailio
touch /data/kamailio/dispatcher.list

: ${CLOUD=""} # One of aws, azure, do, gcp, or empty
if [ "$CLOUD" != "" ]; then
   PROVIDER="-provider ${CLOUD}"
fi

: ${PRIVATE_IPV4:="$(netdiscover -field privatev4 ${PROVIDER})"}
: ${PUBLIC_IPV4:="$(netdiscover -field publicv4 ${PROVIDER})"}
: ${PUBLIC_HOSTNAME:="$(netdiscover -field hostname ${PROVIDER})"}
: ${PUBLIC_PORT:=5060}
: ${PRIVATE_PORT:=5080}

# Build local configuration
cat <<ENDHERE >/data/kamailio/local.k
#!define PUBLIC_IP "${PUBLIC_IPV4}"
#!subst "/PUBLIC_IP/${PUBLIC_IPV4}/"
#!define PRIVATE_IP "${PRIVATE_IPV4}"
#!subst "/PRIVATE_IP/${PRIVATE_IPV4}/"
alias=${PUBLIC_IPV4} ${PUBLIC_HOSTNAME} ${SIP_HOSTNAME}
listen=udp:${PRIVATE_IPV4}:${PUBLIC_PORT} advertise ${PUBLIC_IPV4}:${PUBLIC_PORT}
listen=tcp:${PRIVATE_IPV4}:${PUBLIC_PORT} advertise ${PUBLIC_IPV4}:${PUBLIC_PORT}
listen=udp:${PRIVATE_IPV4}:${PRIVATE_PORT}
listen=tcp:${PRIVATE_IPV4}:${PRIVATE_PORT}
ENDHERE

# Runs kamaillio, while shipping stderr/stdout to logstash
exec /usr/sbin/kamailio $KAMAILIO_ARGS # $*


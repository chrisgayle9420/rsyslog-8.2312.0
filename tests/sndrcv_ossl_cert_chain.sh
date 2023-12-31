#!/bin/bash
# alorbach, 2019-01-16
# This file is part of the rsyslog project, released  under ASL 2.0
. ${srcdir:=.}/diag.sh init
export NUMMESSAGES=1000
# uncomment for debugging support:
#export RSYSLOG_DEBUG="debug nostdout noprintmutexaction"
export RSYSLOG_DEBUGLOG="log"
generate_conf
export PORT_RCVR="$(get_free_port)"
### This is important, as it must be exactly the same
### as the ones configured in used certificates
export HOSTNAME="fedora"
add_conf '
global(
    DefaultNetstreamDriver="ossl"
    DefaultNetstreamDriverCAFile="'$srcdir/testsuites/certchain/ca-cert.pem'"
    DefaultNetstreamDriverCertFile="'$srcdir/testsuites/certchain/server-cert.pem'"
    DefaultNetstreamDriverKeyFile="'$srcdir/testsuites/certchain/server-key.pem'"
    NetstreamDriverCAExtraFiles="'$srcdir/testsuites/certchain/ca-root-cert.pem'"
)

module(	load="../plugins/imtcp/.libs/imtcp"
	StreamDriver.Name="ossl"
	StreamDriver.Mode="1"
        PermittedPeer="'$HOSTNAME'"
	StreamDriver.AuthMode="x509/name" )
# then SENDER sends to this port (not tcpflood!)
input(	type="imtcp" port="'$PORT_RCVR'" )

$template outfmt,"%msg:F,58:2%\n"
$template dynfile,"'$RSYSLOG_OUT_LOG'" # trick to use relative path names!
:msg, contains, "msgnum:" ?dynfile;outfmt
'
startup
export RSYSLOG_DEBUGLOG="log2"
#valgrind="valgrind"
generate_conf 2
export TCPFLOOD_PORT="$(get_free_port)"
add_conf '
global(
	defaultNetstreamDriverCAFile="'$srcdir/testsuites/certchain/ca-root-cert.pem'"
	defaultNetstreamDriverCertFile="'$srcdir/testsuites/certchain/client-cert.pem'"
	defaultNetstreamDriverKeyFile="'$srcdir/testsuites/certchain/client-key.pem'"
)

# Note: no TLS for the listener, this is for tcpflood!
$ModLoad ../plugins/imtcp/.libs/imtcp
input(	type="imtcp" port="0" listenPortFileName="'$RSYSLOG_DYNNAME'.tcpflood_port" )

# set up the action
action(	type="omfwd"
	protocol="tcp"
	target="127.0.0.1"
	port="'$PORT_RCVR'"
	StreamDriver="ossl"
	StreamDriverMode="1"
	StreamDriverAuthMode="x509/name"
        StreamDriverPermittedPeers="'$HOSTNAME'"
	)
' 2
startup 2

# now inject the messages into instance 2. It will connect to instance 1,
# and that instance will record the data.
tcpflood -m$NUMMESSAGES -i1
wait_file_lines
# shut down sender when everything is sent, receiver continues to run concurrently
shutdown_when_empty 2
wait_shutdown 2
# now it is time to stop the receiver as well
shutdown_when_empty
wait_shutdown

seq_check 1 $NUMMESSAGES
exit_test

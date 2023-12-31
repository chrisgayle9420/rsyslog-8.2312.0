#!/bin/bash
# add 2017-11-06 by PascalWithopf, released under ASL 2.0
. ${srcdir:=.}/diag.sh init
generate_conf
add_conf '
module(load="../plugins/mmexternal/.libs/mmexternal")

template(name="outfmt" type="string" string="-%$!%-\n")

if $msg contains "msgnum:" then {
	action(type="mmexternal" interface.input="fulljson"
		binary="'$PYTHON' '${srcdir}'/testsuites/mmexternal-SegFault-mm-python.py")
	action(type="omfile" template="outfmt" file=`echo $RSYSLOG_OUT_LOG`)
}
'
startup_vg
injectmsg literal "<129>Mar 10 01:00:00 172.20.245.8 tag:msgnum:1"
shutdown_when_empty
wait_shutdown_vg
check_exit_vg
export EXPECTED='-{ "sometag": "somevalue" }-'
cmp_exact
exit_test

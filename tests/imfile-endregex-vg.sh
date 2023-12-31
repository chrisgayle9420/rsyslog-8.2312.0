#!/bin/bash
# This is part of the rsyslog testbench, licensed under ASL 2.0
. ${srcdir:=.}/diag.sh init
mkdir "$RSYSLOG_DYNNAME.work"
generate_conf
add_conf '
global(workDirectory="./'"$RSYSLOG_DYNNAME"'.work")
module(load="../plugins/imfile/.libs/imfile")

input(type="imfile"
      File="./'$RSYSLOG_DYNNAME'.input"
      Tag="file:"
      startmsg.regex="^[^ ]")

template(name="outfmt" type="list") {
  constant(value="HEADER ")
  property(name="msg" format="json")
  constant(value="\n")
}

if $msg contains "msgnum:" then
 action(
   type="omfile"
   file=`echo $RSYSLOG_OUT_LOG`
   template="outfmt"
 )
'
startup_vg

# write the beginning of the file
echo 'msgnum:0
 msgnum:1' > $RSYSLOG_DYNNAME.input
echo 'msgnum:2' >> $RSYSLOG_DYNNAME.input

wait_file_lines $RSYSLOG_OUT_LOG 1

# write some more lines (see https://github.com/rsyslog/rsyslog/issues/144)
echo 'msgnum:3
 msgnum:4' >> $RSYSLOG_DYNNAME.input
echo 'msgnum:5' >> $RSYSLOG_DYNNAME.input # this one shouldn't be written to the output file because of ReadMode 2

wait_file_lines $RSYSLOG_OUT_LOG 3

shutdown_when_empty
wait_shutdown_vg
check_exit_vg

## check if we have the correct number of messages
NUMLINES=$(grep -c HEADER  $RSYSLOG_OUT_LOG 2>/dev/null)

if [ -z $NUMLINES ]; then
  echo "ERROR: expecting at least a match for HEADER, maybe  $RSYSLOG_OUT_LOG wasn't even written?"
  cat $RSYSLOG_OUT_LOG
  error_exit 1
else
  if [ ! $NUMLINES -eq 3 ]; then
    echo "ERROR: expecting 3 headers, got $NUMLINES"
    cat $RSYSLOG_OUT_LOG
    error_exit 1
  fi
fi

## check if all the data we expect to get in the file is there

for i in {1..4}; do
  grep msgnum:$i  $RSYSLOG_OUT_LOG > /dev/null 2>&1
  if [ ! $? -eq 0 ]; then
    echo "ERROR: expecting the string 'msgnum:$i', it's not there"
    error_exit 1
  fi
done

exit_test

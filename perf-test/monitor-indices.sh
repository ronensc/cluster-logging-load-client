#!/usr/bin/env bash

function echo_ts() {
  date +"[%FT%T%z] $*"
}

prev_result=""

count=0
while [ $count -lt 3 ]
do

  result=$(oc exec -it -n openshift-logging \
    $(oc get po -n openshift-logging -l "component=elasticsearch" -o jsonpath={.items[0].metadata.name}) \
    -c elasticsearch -- \
    es_util --query="_cat/indices?v=true&s=index")

  if [ "$result" = "$prev_result" ]; then
    ((count++))
  else
    count=1
  fi

  date +"[%FT%T%z]"
  echo "$result"

  prev_result="$result"
  sleep 10s
done
echo_ts "DONE"
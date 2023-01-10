#!/bin/bash
export podstatus=$(kubectl get pod `kubectl get cm pod-name-cm -n demo -o yaml | grep allow: | awk '{print $2}'` -n demo -o json | jq '.status.phase' | sed 's/"//g')
#echo $podstatus
if [[ "$podstatus" == "Running" ]]
then
  echo "Pod is $podstatus"
else
  /root/RENJISH-DEMO/PART_2/block-sh.sh nginx-deployment demo
fi

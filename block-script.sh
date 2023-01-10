#!/bin/bash
export YELLOW='\033[0;33m'
export NC='\033[0m'

NAMESPACE=$2
NAME=$1
export masterpodname=$(kubectl get pods -n $NAMESPACE | grep $NAME | awk '{print $1}' | grep -iv 'Name' | head -1)
export memberpodname=$(kubectl get pods -n $NAMESPACE | grep $NAME | awk '{print $1}' | grep -iv 'Name' | tail -3)
export member1=$(echo $memberpodname | awk '{split($0,a," "); print a[1]}')
export member2=$(echo $memberpodname | awk '{split($0,a," "); print a[2]}')
export member3=$(echo $memberpodname | awk '{split($0,a," "); print a[3]}')

#Add pod name in config map
cat <<EOF > $NAMESPACE-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pod-name-cm
  namespace: $NAMESPACE
data:
  allow: "[\"$masterpodname\"]"
  block: "[\"$member1\", \"$member2\", \"$member3\"]"
EOF
sleep 5
kubectl apply -f $NAMESPACE-cm.yaml &> /dev/null

sallowed=$(kubectl get cm -n demo pod-name-cm -o yaml | grep -i "allow:" | awk '{print $2}')
allowed=$(echo $sallowed | tr -d []\"\')
sblocked=$(kubectl get cm -n demo pod-name-cm -o yaml | grep -i "block:" -A1 | awk '{print $1, $2, $3}' )
ssblocked=$(echo $sblocked | awk '{print $2, $3, $4}')
blocked=$(echo $ssblocked | tr -d []\"\')
sleep 5
echo
echo -e "${NC}${YELLOW}========================================================"
echo -e "Current allowed pod :${NC} $allowed${YELLOW}"
echo -e "Current blocked pod :${NC} $blocked${YELLOW}"
echo -e "======================================================="

# ADD policy
echo
echo -e "${YELLOW}4. Adding Kyverno policy to block shell access based on tags ${NC}"
cat <<EOF > $NAMESPACE-block-pod-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-pod
  annotations:
    pod-policies.kyverno.io/autogen-controllers: DaemonSet,Deployment,StatefulSet
spec:
    validationFailureAction: enforce
    background: false
    rules:
    - name: block-pod-exec
      context:
        - name: dictionary
          configMap:
            name: pod-name-cm
            namespace: $NAMESPACE
      match:
        any:
        - resources:
            kinds:
            - PodExecOptions
      preconditions:
        all:
        - key: "{{ request.operation }}"
          operator: Equals
          value: CONNECT
      validate:
        message: "Exec'ing into the pod {{ request.name }} is not allowed as the pod is not in the allowed list of pods: {{ \"dictionary\".data.\"allow\" }}."
        deny:
          conditions:
            all:
            - key: "{{ request.name }}"
              operator: NotIn
              value: "{{ \"dictionary\".data.\"allow\" }}"
EOF
kubectl apply -f $NAMESPACE-block-pod-policy.yaml &> /dev/null

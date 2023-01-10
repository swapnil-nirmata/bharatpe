#!/bin/bash

# DEFINE COLORS
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export PINK='\033[0;35m'
export BLUE='\033[0;36m'
export GREY='\033[0;37m'
export NC='\033[0m'

# Functions
yes_no(){
echo -en "${NC}${YELLOW}Proceed with demo - [Y|N]? ${NC}"
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
  echo
else
  exit;
fi
}

check_status(){
echo
sleep 20
sallowed=$(kubectl get cm -n demo pod-name-cm -o yaml | grep -i "allow:" | awk '{print $2}')
allowed=$(echo $sallowed | tr -d []\"\')
sblocked=$(kubectl get cm -n demo pod-name-cm -o yaml | grep -i "block:" -A1 | awk '{print $1, $2, $3}' )
ssblocked=$(echo $sblocked | awk '{print $2, $3, $4}')
blocked=$(echo $ssblocked | tr -d []\"\')
oneblocked=$(echo $blocked | awk '{print $2}' | tr -d ,)
sleep 5
echo -e "${YELLOW}------------------------------------------------------"
echo -e "Curent status of deployment "
echo -e "------------------------------------------------------${NC}${GREEN}"
kubectl get pods -n demo
echo
echo -e "${NC}${YELLOW}========================================================"
echo -e "Current allowed pod :${NC} $allowed${YELLOW}"
echo -e "Current blocked pod :${NC} $blocked${YELLOW}"
echo -e "========================================================"
# Try to login to one of the pods sh
sleep 5
echo
echo -e "Trying to login to blocked pod $oneblocked"
sleep 10
echo -e "Running command : kubectl exec -it $oneblocked -n demo sh "
sleep 5
echo -e "-------------------------------------------------------------------------------${NC}${RED}"
kubectl exec -it $oneblocked -n demo sh
echo -e "${NC}${YELLOW}-------------------------------------------------------------------------------${NC}"
echo
yes_no

}
# Deploy App
echo -e "${BLUE}------------------------------------------------------------------------"
echo -e "DEMO USE CASE : Primary Pod in Replica Use Case"
echo -e "------------------------------------------------------------------------${NC}"
echo
echo -e "${YELLOW}1. Creating a sample nginx application with 4 replicas${NC}"
cat <<EOF > /root/DEMO/BHARAPT-PE/nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 4 # tells deployment to run 4 pods matching the template
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
EOF
kubectl create ns demo &> /dev/null
kubectl apply -f /root/DEMO/BHARAPT-PE/nginx-deployment.yaml -n demo &> /dev/null
sleep 15
echo -e "${YELLOW}2. Validating if the application is deployed successfully ${NC}${GREEN}"
echo
kubectl get pods -n demo
echo
yes_no
echo -e "${NC}${YELLOW}3. Tagging one replicas to enable shell access, blocking for other${NC}"
sleep 3
/root/DEMO/BHARAPT-PE/block.sh nginx-deployment demo
kubectl get cpol -A | grep -i "block-pod"
sleep 5
# Cronjob script
cat <<EOF > /root/DEMO/BHARAPT-PE/cronjob.sh
#!/bin/bash
export podstatus=$(kubectl get pod `kubectl get cm pod-name-cm -n demo -o yaml | grep allow: | awk '{print $2}' | tr -d []\"\' ` -n demo -o json | jq '.status.phase' | sed 's/"//g')
#echo $podstatus
if [[ "$podstatus" == "Running" ]]
then
  echo "Pod is $podstatus"
else
  /root/DEMO/BHARAPT-PE/block.sh nginx-deployment demo
fi
EOF
chmod 755 /root/DEMO/BHARAPT-PE/cronjob.sh

# Service script
cat <<EOF > /root/DEMO/BHARAPT-PE/service.sh
#!/bin/bash
while true
do
 /root/DEMO/BHARAPT-PE/cronjob.sh
 sleep 2
done
EOF
chmod 755 /root/DEMO/BHARAPT-PE/service.sh

# Service configuration
cat <<EOF >  /etc/systemd/system/pod-check.service
[Unit]
Description=Pod Monitoring Service

[Service]
Type=simple
User=root
Group=root
TimeoutStartSec=5
Restart=on-failure
RestartSec=30s
#ExecStartPre=
ExecStart=/root/DEMO/BHARAPT-PE/service.sh
SyslogIdentifier=Status
#ExecStop=

[Install]
WantedBy=multi-user.target
EOF
systemctl start pod-check.service &> /dev/null
systemctl daemon-reload &> /dev/null
check_status
echo -e "${YELLOW}5. Validating failure scenario of primary pod ${NC}"
sallowed=$(kubectl get cm -n demo pod-name-cm -o yaml | grep -i "allow:" | awk '{print $2}')
allowed=$(echo $sallowed | tr -d []\"\')
sblocked=$(kubectl get cm -n demo pod-name-cm -o yaml | grep -i "block:" -A1 | awk '{print $1, $2, $3}' )
ssblocked=$(echo $sblocked | awk '{print $2, $3, $4}')
blocked=$(echo $ssblocked | tr -d []\"\')
echo -e "${YELLOW}------------------------------------------------------"
echo -e "Curent status of deployment "
echo -e "------------------------------------------------------${NC}${GREEN}"
kubectl get pods -n demo
echo
echo -e "${NC}${YELLOW}========================================================"
echo -e "Current allowed pod :${NC} $allowed${YELLOW}"
echo -e "Current blocked pod :${NC} $blocked${YELLOW}"
echo -e "======================================================="
echo
sleep 5
echo -e "${YELLOW}- Deleting primary/allowed pod to see changes"
echo
echo -e "Running command : kubectl delete pod $allowed -n demo ${NC}"
echo -e "${GREEN}--------------------------------------------------------"
kubectl delete pod $allowed -n demo
echo -e "--------------------------------------------------------${NC}"
sleep 25
sallowed=$(kubectl get cm -n demo pod-name-cm -o yaml | grep -i "allow:" | awk '{print $2}')
allowed=$(echo $sallowed | tr -d []\"\')
sblocked=$(kubectl get cm -n demo pod-name-cm -o yaml | grep -i "block:" -A1 | awk '{print $1, $2, $3}' )
ssblocked=$(echo $sblocked | awk '{print $2, $3, $4}')
blocked=$(echo $ssblocked | tr -d []\"\')
sleep 5
echo -e "${YELLOW}------------------------------------------------------"
echo -e "Curent status of deployment "
echo -e "------------------------------------------------------${NC}${GREEN}"
kubectl get pods -n demo
echo
sleep 5
echo -e "${NC}${YELLOW}========================================================"
echo -e "Current allowed pod :${NC} $allowed${YELLOW}"
echo -e "Current blocked pod :${NC} $blocked${YELLOW}"
echo -e "======================================================="
echo
echo -e "${YELLOW}-------------------------------------------------------------------------------"
echo -e "Use case validation completed"
echo -e "-------------------------------------------------------------------------------${NC}"

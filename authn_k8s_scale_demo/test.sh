set -x
oc project conjur
service_desc=$(oc describe service conjur-master)
echo $service_desc | awk '/NodePort:/ {print $2 " " $3}' | awk '/https/ {print $2}' | awk -F "/" '{ print $1 }'

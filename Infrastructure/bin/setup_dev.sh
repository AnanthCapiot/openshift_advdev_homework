#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

oc project ${GUID}-parks-dev
# Code to set up the parks development project.

oc policy add-role-to-user edit system:serviceaccount:70fa-jenkins:jenkins -n 70fa-parks-dev

oc new-app --name=mongodb -e MONGODB_USER=mongodb -e MONGODB_PASSWORD=mongodb -e MONGODB_DATABASE=parks -e MONGODB_ADMIN_PASSWORD=mongodb_admin_password     registry.access.redhat.com/rhscl/mongodb-26-rhel7
oc rollout pause dc/mongodb 
echo "apiVersion: "v1"
kind: "PersistentVolumeClaim"
metadata:
  name: "mongo-pvc"
spec:
  accessModes:
    - "ReadWriteOnce"
  resources:
    requests:
      storage: "2Gi"" | oc create -f -

oc set volume dc/mongodb --add --type=persistentVolumeClaim --name=mongo-pv --claim-name=mongo-pvc --mount-path=/data --containers=*
oc rollout resume dc/mongodb


oc new-build --binary=true --strategy=source --name=mlbparks jboss-eap70-openshift:1.7 
oc new-build --binary=true --strategy=source --name=nationalparks redhat-openjdk18-openshift:1.2
oc new-build --binary=true --strategy=source --name=parksmap redhat-openjdk18-openshift:1.2

oc new-app 70fa-parks-dev/mlbparks:0.0-0 -e APPNAME="MLB Parks (Dev)" --name=mlbparks --allow-missing-imagestream-tags=true 
oc new-app 70fa-parks-dev/nationalparks:0.0-0 -e APPNAME="National Parks (Dev)" --name=nationalparks --allow-missing-imagestream-tags=true 
oc new-app 70fa-parks-dev/parksmap:0.0-0 -e APPNAME="ParksMap (Dev)" --name=parksmap --allow-missing-imagestream-tags=true 

oc set triggers dc/mlbparks --remove-all
oc set triggers dc/nationalparks --remove-all
oc set triggers dc/parksmap --remove-all

oc expose dc mlbparks --port 8080
oc expose dc nationalparks --port 8080
oc expose dc parksmap --port 8080

oc expose svc mlbparks -l type=parksmap-backend
oc expose svc nationalparks  -l type=parksmap-backend
oc expose svc parksmap  -l type=parksmap-backend

echo "DB_HOST=mongodb
DB_PORT=27017
DB_USERNAME=mongodb
DB_PASSWORD=mongodb
DB_NAME=parks" > application-db.properties

oc create configmap mlbparks-config --from-literal="application-db.properties=Placeholder"
oc create configmap nationalparks-config --from-literal="application-db.properties=Placeholder"

# oc env dc/mlbparks --from=configmap/mlbparks-config
# oc env dc/nationalparks --from=configmap/nationalparks-config

oc patch dc/mlbparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: mlbparks, command: ['curl -XGET http://localhost:8080/ws/data/load/']}}}}}"
oc patch dc/nationalparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: nationalparks, command: ['curl -XGET http://localhost:8080/ws/data/load/']}}}}}"

oc set probe dc/mlbparks --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/mlbparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/

oc set probe dc/nationalparks --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/nationalparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/

# oc set volume dc/mlbparks --add --name=mlbparks-config-vol --mount-path=/configuration/application-db.properties --sub-path=application-db.properties --configmap-name=mlbparks-config
# oc set volume dc/nationalparks --add --name=nationalparks-config-vol --mount-path=/configuration/application-db.properties --sub-path=application-db.properties --configmap-name=nationalparks-config

echo "apiVersion: v1
kind: Service
metadata:
    name: parksmap-backend
    labels:
        type: parksmap-backend
spec:
    selector:
        type: parksmap-backend
    ports:
    - protocol: TCP
      port: 8080" | oc create -f -
# oc expose svc tasks
# To be Implemented by Student

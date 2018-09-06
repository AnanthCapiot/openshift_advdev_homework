#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

oc project ${GUID}-parks-prod
# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.

oc policy add-role-to-user edit system:serviceaccount:70fa-jenkins:jenkins -n 70fa-parks-prod
oc policy add-role-to-group system:image-puller system:serviceaccount:70fa-parks-prod -n 70fa-parks-dev
# To be Implemented by Student

# Replicated MongoDB setup
echo 'kind: Service
apiVersion: v1
metadata:
  name: "mongodb-internal"
  labels:
    name: "mongodb"
spec:
  ports:
  - name: "mongoport"
    port: 27017
  clusterIp: none
  selector:
    name : "mongodb"' | oc create -f -

echo 'kind: Service
apiVersion: v1
metadata:
  name: "mongodb"
  labels:
    name: "mongodb"
spec:
  ports:
  - name: "mongodb"
    port: 27017
  selector:
    name: "mongodb"' | oc create -f -

echo 'apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: "mongodb-stateful-set"
  labels:
    name: mongodb
    type: statefulset
spec:
  selector:
    matchLabels:
      name: "mongodb"
  serviceName: "mongodb-internal"
  replicas: 3
  template:
    metadata:
      labels:
        name: "mongodb"
    spec:
      containers:
      - name: mongo-container
        image: registry.access.redhat.com/rhscl/mongodb-34-rhel7:latest
        ports:
        - containerPort: 27017
        args:
        - "run-mongod-replication"
        volumeMounts:
        - name: mongo-data
          mountPath: "/var/lib/mongodb/data"
        env:
        - name: MONGODB_DATABASE
          value: "parks"
        - name: MONGODB_USER
          value: "mongodb"
        - name: MONGODB_PASSWORD
          value: "mongodb"
        - name: MONGODB_ADMIN_PASSWORD
          value: "mongodb_admin_password"
        - name: MONGODB_REPLICA_NAME
          value: "rs0"
        - name: MONGODB_KEYFILE_VALUE
          value: "12345678901234567890"
        - name: MONGODB_SERVICE_NAME
          value: "mongodb-internal"
        readinessProbe:
          exec:
            command:
            - stat
            - /tmp/initialized
  volumeClaimTemplates:
  - metadata:
      name: mongo-data
      labels:
        name: "mongodb"
    spec:
      accessModes: [ ReadWriteOnce ]
      resources:
        requests:
          storage: "4Gi"' | oc create -f -


# Blue Application
oc new-app 70fa-parks-dev/mlbparks:0.0 --name=mlbparks-blue -e APPNAME="MLB Parks (Blue)" --allow-missing-imagestream-tags=true
oc new-app 70fa-parks-dev/nationalparks:0.0 --name=nationalparks-blue -e APPNAME="National Parks (Blue)" --allow-missing-imagestream-tags=true
oc new-app 70fa-parks-dev/parksmap:0.0 --name=parksmap-blue -e APPNAME="ParksMap (Blue)" --allow-missing-imagestream-tags=true


oc set triggers dc/mlbparks-blue --remove-all
oc set triggers dc/nationalparks-blue --remove-all
oc set triggers dc/parksmap-blue --remove-all


oc expose dc/mlbparks-blue --port 8080
oc expose dc/nationalparks-blue --port 8080
oc expose dc/parksmap-blue --port 8080

oc create configmap mlbparks-blue-config --from-literal="application-db.properties=Placeholder"
oc create configmap nationalparks-blue-config --from-literal="application-db.properties=Placeholder"
oc create configmap parksmap-blue-config --from-literal="application-db.properties=Placeholder"

oc env dc/mlbparks-blue --from=configmap/mlbparks-blue-config
oc env dc/nationalparks-blue --from=configmap/nationalparks-blue-config
oc env dc/parksmap-blue --from=configmap/parksmap-blue-config

oc expose svc/mlbparks-blue --name mlbparks -n 70fa-parks-prod
oc expose svc/nationalparks-blue --name nationalparks -n 70fa-parks-prod
oc expose svc/parksmap-blue --name parksmap -n 70fa-parks-prod


# Green Application
oc new-app 70fa-parks-dev/mlbparks:0.0 --name=mlbparks-green -e APPNAME="MLB Parks (Green)" --allow-missing-imagestream-tags=true
oc new-app 70fa-parks-dev/nationalparks:0.0 --name=nationalparks-green -e APPNAME="National Parks (Green)" --allow-missing-imagestream-tags=true
oc new-app 70fa-parks-dev/parksmap:0.0 --name=parksmap-green -e APPNAME="ParksMap (Green)" --allow-missing-imagestream-tags=true


oc set triggers dc/mlbparks-green --remove-all
oc set triggers dc/nationalparks-green --remove-all
oc set triggers dc/parksmap-green --remove-all


oc expose dc/mlbparks-green --port 8080
oc expose dc/nationalparks-green --port 8080
oc expose dc/parksmap-green --port 8080

oc create configmap mlbparks-green-config --from-literal="application-db.properties=Placeholder"
oc create configmap nationalparks-green-config --from-literal="application-db.properties=Placeholder"
oc create configmap parksmap-green-config --from-literal="application-db.properties=Placeholder"

oc env dc/mlbparks-green --from=configmap/mlbparks-green-config
oc env dc/nationalparks-green --from=configmap/nationalparks-green-config
oc env dc/parksmap-green --from=configmap/parksmap-green-config
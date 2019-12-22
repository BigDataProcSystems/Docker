# Spark Standalone Cluster on Kubernetes using Deployments

Sergei Yu. Papulin (papulin.study@yandex.ru)

## Contents

- Installing Minikube
- Building Spark Image
- Deploying Spark on Kubernetes
- Spark Pi Test
- Cleaning Up
- References

## Prerequisites

To get started, you need to have done the following:
- Install and run Docker. See how to do it [here](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

## Installing Minikube

How to install the `minikube` tool you can find [here](install_minikube.md).

## Running Kubernetes

To launch K8S, run the following command:

`sudo minikube start --vm-driver=none`

```
😄  minikube v1.6.1 on Ubuntu 18.04 (vbox/amd64)
...
🤹  Running on localhost (CPUs=4, Memory=7974MB, Disk=60217MB) ...
...
ℹ️   OS release is Ubuntu 18.04.3 LTS
🐳  Preparing Kubernetes v1.17.0 on Docker '19.03.5' ...
    ▪ kubelet.resolv-conf=/run/systemd/resolve/resolv.conf
...
🏄  Done! kubectl is now configured to use "minikube"
```

Note there are parameters for configuring cpus and memory that can be used by your cluster. However, they cannot be applied in the 'none' driver mode.

Check the cluster status:

`sudo minikube status`

```
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

You can run a cluster later when you build a Spark image and create other files.

## Building Spark Image

Spark 2.3 and later versions have the Dockerfile in its home directory for creating the Spark image. Therefore, download Spark 2.4.4 and build the image.

#### Download Spark distribution

Switch to the home directory:

```
cd $HOME
```

Download Spark 2.4.4, unpack it and delete the initial archive:

```
mkdir spark \
    && wget -P sources https://archive.apache.org/dist/spark/spark-2.4.4/spark-2.4.4-bin-hadoop2.7.tgz \
    && tar -xvf sources/spark-2.4.4-bin-hadoop2.7.tgz --directory spark --strip-components 1 \
    && rm sources/spark-2.4.4-bin-hadoop2.7.tgz
```

#### Build Spark image

Build the image by running the following script in the home Spark directory:

`cd $SPARK_HOME && bin/docker-image-tool.sh build`

```
...
Successfully built e5d13f574244
Successfully tagged spark:latest
...
Successfully built 6343567afd81
Successfully tagged spark-py:latest
...
Successfully built e20c83c11bb8
Successfully tagged spark-r:latest
```

Print all available images:

`docker image ls`

```
REPOSITORY                                TAG                 IMAGE ID            CREATED              SIZE
spark-r                                   latest              e20c83c11bb8        About a minute ago   760MB
spark-py                                  latest              6343567afd81        5 minutes ago        466MB
spark                                     latest              e5d13f574244        6 minutes ago        375MB
```

The Dockerfile and entrypoint script you can find in `$SPARK_HOME/spark/kubernetes/dockerfiles/spark`.

#### Modify initial image 

To deploy Spark on Kubernetes using a deployment version, we have to change a bit the created image to apply a custom entrypoint script. This image will be used to run the Spark master and workers nodes.

There are two basic scripts: the first is for starting containers and the second is for stopping them.

The starting script looks as follows:

```bash
#!/bin/bash

case "$1" in
    master)
        echo "MASTER"
        exec tini -s -- /opt/spark/bin/spark-class org.apache.spark.deploy.master.Master --host $HOSTNAME --port 7077 --webui-port 8080
        ;;
    worker)
        echo "WORKER"
        MASTER_IP_ADDRESSES=( $( nslookup $MASTER_IP_RESOLVER | awk '/^Address / { print $3 }') )
        if [ ${#MASTER_IP_ADDRESSES[@]} ] && [ -n ${MASTER_IP_ADDRESSES[0]} ]; 
        then
            echo ${MASTER_IP_ADDRESSES[0]} $MASTER_HOSTNAME >> /etc/hosts
            exec tini -s -- /opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker spark://$MASTER_HOSTNAME:7077
        else
            echo "Master IP was not found" 1>&2
            exit 1
        fi
        ;;
    *)
        echo $"Usage: $0 {master|worker}" 1>&2
        exit 1
esac
```

Now create a Dockerfile with the following content:

```dockerfile
FROM spark:latest

LABEL maintainer="Sergei Papulin <papulin.study@yandex.ru>"

ENV PATH="$SPARK_HOME/bin:${PATH}"
COPY ["./start-spark.sh", "./stop-spark.sh", "/opt/"]
RUN chmod 755 /opt/start-spark.sh /opt/stop-spark.sh
```

Build the custom Spark image using the created Dockerfile:

`cd $REPO/projects/k8s/spark/ && docker build -t custom-spark:v2.4.4 .`

```
Sending build context to Docker daemon  11.26kB
Step 1/5 : FROM spark:latest
 ---> e5d13f574244
Step 2/5 : LABEL maintainer="Sergei Papulin <papulin.study@yandex.ru>"
 ---> Running in 9de96c753974
Removing intermediate container 9de96c753974
 ---> 050bb6981f5e
Step 3/5 : ENV PATH="$SPARK_HOME/bin:${PATH}"
 ---> Running in e05dc93b02fd
Removing intermediate container e05dc93b02fd
 ---> 80882ed1ba66
Step 4/5 : COPY ["./start-spark.sh", "./stop-spark.sh", "/opt/"]
 ---> 1fc7c09a9537
Step 5/5 : RUN chmod 755 /opt/start-spark.sh /opt/stop-spark.sh
 ---> Running in 84a3537e2867
Removing intermediate container 84a3537e2867
 ---> 66e2167651e5
Successfully built 66e2167651e5
Successfully tagged custom-spark:v2.4.4
```

Display a list of images:

`docker image ls`

```
REPOSITORY                                TAG                 IMAGE ID            CREATED             SIZE
custom-spark                              v2.4.4              66e2167651e5        34 seconds ago      375MB
spark-r                                   latest              e20c83c11bb8        10 minutes ago      760MB
spark-py                                  latest              6343567afd81        14 minutes ago      466MB
spark                                     latest              e5d13f574244        16 minutes ago      375MB
```

You can run a bash interpreter in the custom image and check that all scripts copied successfully:

`docker run --name custom-spark-test -it custom-spark:v2.4.4 /bin/bash`

```
bash-4.4# ls /opt/
entrypoint.sh   spark           start-spark.sh  stop-spark.sh
bash-4.4# exit
```

Delete the container where the custom image was launched.

Print the last container:

`docker container ls -l`

```
CONTAINER ID        IMAGE                 COMMAND                  CREATED             STATUS                     PORTS               NAMES
7634f6045524        custom-spark:v2.4.4   "/opt/entrypoint.sh …"   3 minutes ago       Exited (0) 2 minutes ago                       custom-spark-test
```

Remove it by the conainer id:

`docker container rm 7634f6045524`

## Deploying Spark on Kubernetes

To deploy Spark, let's create two deployment yaml files to run master and worker nodes. Deployment files provide instructions to deploy pods in a declarative way.

In addition, we create a service yaml file to expose the master web ui port and use a discovery mechanism to get a master IP address in workers.

#### Master deployment file

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-master-deployment
  namespace: spark
  labels:
    environment: dev
    app: spark
    role: master
    version: 2.4.4
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spark
      role: master
  template:
    metadata:
      labels:
        app: spark
        role: master
    spec:
      hostname: spark-master
      containers:
        - name: spark-master
          image: custom-spark:v2.4.4
          imagePullPolicy: IfNotPresent
          command: ["/opt/start-spark.sh"]
          args: ["master"]
          ports:
            - containerPort: 7077
            - containerPort: 8080
          resources:
            requests:
              cpu: 500m
          lifecycle:
            preStop:
              exec:
                command: ["/opt/stop-spark.sh", "master"]
```

#### Worker deployment file

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-worker-deployment
  namespace: spark
  labels:
    environment: dev
    app: spark
    role: worker
    version: 2.4.4
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spark
      role: worker
  template:
    metadata:
      labels:
        app: spark
        role: worker
    spec:
      containers:
        - name: spark-worker
          image: custom-spark:v2.4.4
          imagePullPolicy: IfNotPresent
          env:
            - name: MASTER_IP_RESOLVER
              value: "*.spark-master-service.spark.svc.cluster.local"
            - name: MASTER_HOSTNAME
              value: "spark-master"
          command: ["/opt/start-spark.sh"]
          args: ["worker"]
          resources:
            requests:
              cpu: 500m
          lifecycle:
            preStop:
              exec:
                command: ["/opt/stop-spark.sh", "worker"]
```

#### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spark-master-service
  namespace: spark
  labels:
    environment: dev
    app: spark
    role: master
    version: 2.4.4
spec:
  selector:
    app: spark
    role: master
  ports:
    - protocol: TCP
      port: 9999
      targetPort: 8080
```


#### Running deployment ans service files

If you haven't run `K8S` yet, it's high time to do that.

Create the `spark` namespace:

`sudo kubectl create namespace spark`

```
namespace/spark created
```

Run the service at first:

`sudo kubectl apply -f $REPO/projects/k8s/spark/spark-master-service.yaml`

```
service/spark-master-service created
```

Print all services from the `spark` namespace:

`sudo kubectl get services -n spark`

```
NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
spark-master-service   ClusterIP   10.96.66.194   <none>        9999/TCP   12s
```

Then run the master deployment:

`sudo kubectl apply -f $REPO/projects/k8s/spark/spark-master-deployment.yaml`

```
deployment.apps/spark-master-deployment created
```

And the worker deployment:

`sudo kubectl apply -f $REPO/projects/k8s/spark/spark-worker-deployment.yaml`

```
deployment.apps/spark-worker-deployment created
```

`sudo kubectl get deployments -n spark`

```
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
spark-master-deployment   1/1     1            1           21s
spark-worker-deployment   1/1     1            1           11s
```

Display all running pods in the `spark` namespace:

`sudo kubectl get pods -n spark -o wide`

```
NAME                                       READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
spark-master-deployment-85b688cfbb-mbznc   1/1     Running   0          37s   172.17.0.4   minikube   <none>           <none>
spark-worker-deployment-5dfd4b788d-5ghfq   1/1     Running   0          26s   172.17.0.5   minikube   <none>           <none>
```

To fetch logs from the master pod, you can run the following command:

`sudo kubectl logs spark-master-deployment-85b688cfbb-mbznc -n spark`

```
MASTER
Using Spark's default log4j profile: org/apache/spark/log4j-defaults.properties
INFO Master: Started daemon with process name: 6@spark-master
...
INFO Utils: Successfully started service 'sparkMaster' on port 7077.
INFO Master: Starting Spark master at spark://spark-master:7077
INFO Master: Running Spark version 2.4.4
INFO Utils: Successfully started service 'MasterUI' on port 8080.
INFO MasterWebUI: Bound MasterWebUI to 0.0.0.0, and started at http://spark-master:8080
INFO Master: I have been elected leader! New state: ALIVE
```

You can run `bash` in a similar way as for a Docker container: 

`sudo kubectl exec -it spark-master-deployment-85b688cfbb-mbznc -n spark -- /bin/bash`

#### Scaling workers

As you may have noticed, we run only one worker. To increase the number of workers up to 3, run the following command with the `replicas` parameter equal to 3:

`sudo kubectl scale deployment.v1.apps/spark-worker-deployment --replicas=3 -n spark`

```
deployment.apps/spark-worker-deployment scaled
```

Now display all worker pods:

`sudo kubectl get pods -l app=spark,role=worker -o wide -n spark`

```
NAME                                       READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
spark-worker-deployment-5dfd4b788d-5ghfq   1/1     Running   0          94s   172.17.0.5   minikube   <none>           <none>
spark-worker-deployment-5dfd4b788d-q94p5   1/1     Running   0          10s   172.17.0.6   minikube   <none>           <none>
spark-worker-deployment-5dfd4b788d-qc4f2   1/1     Running   0          10s   172.17.0.7   minikube   <none>           <none>
```

Open your browser and go to `10.96.66.194:9999` (see your service IP) to see the Master Web UI:

![Spark Master Web UI](img/minikube/spark_k8s_dep_1.png "Spark Master Web UI")
<center><i>Figure 1. Spark Master Web UI</i></center>

## Running Pi Test

Simple way to test our Spark cluster is to run the standard Pi application that is under the `examples` directory:

```
sudo kubectl exec spark-master-deployment-85b688cfbb-mbznc -n spark -- \
  spark-submit \
    --master spark://spark-master:7077 \
    --name spark-pi \
    --class org.apache.spark.examples.SparkPi \
    local:///opt/spark/examples/jars/spark-examples_2.11-2.4.4.jar
```

```
...
INFO DAGScheduler: Job 0 finished: reduce at SparkPi.scala:38, took 6.191359 s
Pi is roughly 3.137515687578438
INFO SparkUI: Stopped Spark web UI at http://spark-master:4040
INFO StandaloneSchedulerBackend: Shutting down all executors
...
```

![Running Application](img/minikube/spark_k8s_dep_2.png "Running Application")
<center><i>Figure 2. Running Application</i></center>

![Application Details](img/minikube/spark_k8s_dep_3.png "Application Details")
<center><i>Figure 3. Application Details</i></center>

## Cleaning Up

To delete deployments with their pods, run the following command:

`sudo kubectl delete deployment spark-worker-deployment spark-master-deployment -n spark`

```
deployment.apps "spark-worker-deployment" deleted
deployment.apps "spark-master-deployment" deleted
```

Delete the service:

`sudo kubectl delete service spark-master-service -n spark`

```
service "spark-master-service" deleted
```

Stop the cluster:

`sudo minikube stop`

```
✋  Stopping "minikube" in none ...
✋  Stopping "minikube" in none ...
🛑  "minikube" stopped.
```

Delete the cluster:

`sudo minikube delete`

```
🔄  Uninstalling Kubernetes v1.17.0 using kubeadm ...
🔥  Deleting "minikube" in none ...
💔  The "minikube" cluster has been deleted.
🔥  Successfully deleted profile "minikube"
```


## References

- [Kubernetes: Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes: Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Deploying Spark on Kubernetes](https://github.com/testdrivenio/spark-kubernetes)



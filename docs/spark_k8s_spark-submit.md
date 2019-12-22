# Spark on Kubernetes: spark-submit

Sergei Yu. Papulin (papulin.study@yandex.ru)

## Contents

- Installing Minikube
- Building Spark Image
- Running Spark Application on Kubernetes
- Troubleshooting
- Cleaning Up
- References

## Prerequisites

To get started, you need to have done the following:
- Install and run Docker. See how to do it [here](https://docs.docker.com/install/linux/docker-ce/ubuntu/)


## Installing minikube

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

You can run a bash interpreter in the custom image and check that all scripts copied successfully:

`docker run --name spark-test -it spark:latest /bin/bash`

```
bash-4.4# ls /opt/
entrypoint.sh   spark
bash-4.4# exit
```

## Configuring Kubernetes

Create the `spark` namespace to distinguish resources for our cluster from others:

`sudo kubectl create namespace spark`

```
namespace/spark created
```

Create a service account named `spark-serviceaccount`:

`sudo kubectl create serviceaccount spark-serviceaccount --namespace spark`

```
serviceaccount/spark-serviceaccount created
```

Bind the `edit` role to `spark-serviceaccount`:

`sudo kubectl create rolebinding spark-rolebinding --clusterrole=edit --serviceaccount=spark:spark-serviceaccount --namespace=spark`

```
rolebinding.rbac.authorization.k8s.io/spark-rolebinding created
```

Launch the Kubernetes web UI in another terminal:

`sudo minikube dashboard`

```
🤔  Verifying dashboard health ...
🚀  Launching proxy ...
🤔  Verifying proxy health ...
http://127.0.0.1:42625/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/
```

![Kubernetes Web UI](img/minikube/spark_k8s_submit_1.png "Kubernetes Web UI")
<center><i>Figure 1. Kubernetes Web UI</i></center>

## Running Spark Application on Kubernetes

#### Requirements

To run a Spark application using the `spark-submit` command, it's mandatory to have a Spark distribution on your host. Moreover, you must have a compatible java version that is 8 in this case. 

Check your current Java version:

`java -version`

```
openjdk version "1.8.0_232"
OpenJDK Runtime Environment (build 1.8.0_232-8u232-b09-0ubuntu1~18.04.1-b09)
OpenJDK 64-Bit Server VM (build 25.232-b09, mixed mode)
```

If you have an older Java version, run the following commands to setup the Java 8:

`sudo add-apt-repository ppa:openjdk-r/ppa && sudo apt update && sudo apt -y install openjdk-8-jdk`


#### Run application

- *Cluster mode*

Run the command below to start the Spark Pi application:

```
sudo $SPARK_HOME/bin/spark-submit \
    --master k8s://https://localhost:8443 \
    --deploy-mode cluster \
    --name spark-pi \
    --class org.apache.spark.examples.SparkPi \
    --conf spark.executor.instances=3 \
    --conf spark.kubernetes.container.image=spark \
    --conf spark.kubernetes.namespace=spark \
    --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-serviceaccount \
    local:///opt/spark/examples/jars/spark-examples_2.11-2.4.4.jar
```

Open another terminal and print all pods in the `spark` namespace:

`sudo kubectl get pods -n spark -o wide`

```
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
spark-pi-1577001982580-driver   1/1     Running   0          24s   172.17.0.6   minikube   <none>           <none>
spark-pi-1577001982580-exec-1   1/1     Running   0          10s   172.17.0.8   minikube   <none>           <none>
spark-pi-1577001982580-exec-2   1/1     Running   0          10s   172.17.0.7   minikube   <none>           <none>
spark-pi-1577001982580-exec-3   0/1     Pending   0          10s   <none>       <none>     <none>           <none>
```

Wait a bit for the application to complete processing and repeat the previous command:

```
NAME                            READY   STATUS      RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
spark-pi-1577001982580-driver   0/1     Completed   0          52s   172.17.0.6   minikube   <none>           <none>
```

You should see a similar output of the application to the one below: 

```
INFO LoggingPodStatusWatcherImpl: State changed, new state: 
         pod name: spark-pi-1577001982580-driver
         namespace: spark
         ...
         phase: Pending
         ...
INFO LoggingPodStatusWatcherImpl: State changed, new state: 
         pod name: spark-pi-1577001982580-driver
         namespace: spark
         ...
         phase: Pending
         ...
INFO Client: Waiting for application spark-pi to finish...
INFO LoggingPodStatusWatcherImpl: State changed, new state: 
         pod name: spark-pi-1577001982580-driver
         namespace: spark
         ...
         phase: Running
         ...
INFO LoggingPodStatusWatcherImpl: State changed, new state: 
         pod name: spark-pi-1577001982580-driver
         namespace: spark
         ...
         phase: Succeeded
         ...
INFO LoggingPodStatusWatcherImpl: Container final statuses:

         Container name: spark-kubernetes-driver
         Container image: spark:latest
         Container state: Terminated
         Exit code: 0
INFO Client: Application spark-pi finished.

```

Fetch driver logs as follows:

`sudo kubectl logs spark-pi-1577001982580-driver --namespace spark`

If everything went well, you find the following line:

```
Pi is roughly 3.1426957134785676
```

If you got an error on your driver as below, you need to replace Kubernetes jar files. Go to the next troubleshooting section of this tutorial to fix the error.

```
INFO SparkUI: Bound SparkUI to 0.0.0.0, and started at http://spark-pi-1577001982580-driver-svc.spark.svc:4040
INFO SparkContext: Added JAR file:///opt/spark/examples/jars/spark-examples_2.11-2.4.4.jar at spark://spark-pi-1577001982580-driver-svc.spark.svc:7078/jars/spark-examples_2.11-2.4.4.jar with timestamp 1576677527031
INFO ExecutorPodsAllocator: Going to request 3 executors from Kubernetes.
WARN WatchConnectionManager: Exec Failure: HTTP 403, Status: 403 - 
java.net.ProtocolException: Expected HTTP 101 response but was '403 Forbidden'
        at okhttp3.internal.ws.RealWebSocket.checkResponse(RealWebSocket.java:216)
        at okhttp3.internal.ws.RealWebSocket$2.onResponse(RealWebSocket.java:183)
        at okhttp3.RealCall$AsyncCall.execute(RealCall.java:141)
        at okhttp3.internal.NamedRunnable.run(NamedRunnable.java:32)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
        at java.lang.Thread.run(Thread.java:748)
```

You can track a status of your application in the Kubernetes web UI.

![Application Details](img/minikube/spark_k8s_submit_2.png "Application Details")
<center><i>Figure 2. Application Details</i></center>

- *Client mode*

It's possible to run a Spark application in the `client` mode. In this case you should provide a jar file of your application located on the host (in contrast to the `cluster` mode where jar files should be in containers with the `local://` prefix). 

```
sudo /home/bigdata/spark/bin/spark-submit \
    --master k8s://https://localhost:8443 \
    --deploy-mode client \
    --name spark-pi \
    --class org.apache.spark.examples.SparkPi \
    --conf spark.executor.instances=3 \
    --conf spark.kubernetes.container.image=spark \
    --conf spark.kubernetes.namespace=spark \
    --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-serviceaccount \
    file:///home/bigdata/spark/examples/jars/spark-examples_2.11-2.4.4.jar
```

`sudo kubectl get pods -n spark -o wide`

```
spark-pi-1577006053868-exec-1   1/1     Running     0          14s   172.17.0.6   minikube   <none>           <none>
spark-pi-1577006055295-exec-2   1/1     Running     0          13s   172.17.0.7   minikube   <none>           <none>
spark-pi-1577006055387-exec-3   1/1     Running     0          13s   172.17.0.8   minikube   <none>           <none>
```

```
INFO DAGScheduler: ResultStage 0 (reduce at SparkPi.scala:38) finished in 1.496 s
INFO DAGScheduler: Job 0 finished: reduce at SparkPi.scala:38, took 1.702189 s
Pi is roughly 3.1458157290786453
INFO KubernetesClusterSchedulerBackend: Shutting down all executors
```

## Troubleshooting


#### Replace Kubernetes jar files

If you got an error on your driver as below, you need to replace Kubernetes jar files.

```
INFO SparkUI: Bound SparkUI to 0.0.0.0, and started at http://spark-pi-1577001982580-driver-svc.spark.svc:4040
INFO SparkContext: Added JAR file:///opt/spark/examples/jars/spark-examples_2.11-2.4.4.jar at spark://spark-pi-1577001982580-driver-svc.spark.svc:7078/jars/spark-examples_2.11-2.4.4.jar with timestamp 1576677527031
INFO ExecutorPodsAllocator: Going to request 3 executors from Kubernetes.
WARN WatchConnectionManager: Exec Failure: HTTP 403, Status: 403 - 
java.net.ProtocolException: Expected HTTP 101 response but was '403 Forbidden'
        at okhttp3.internal.ws.RealWebSocket.checkResponse(RealWebSocket.java:216)
        at okhttp3.internal.ws.RealWebSocket$2.onResponse(RealWebSocket.java:183)
        at okhttp3.RealCall$AsyncCall.execute(RealCall.java:141)
        at okhttp3.internal.NamedRunnable.run(NamedRunnable.java:32)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
        at java.lang.Thread.run(Thread.java:748)
```

This is the known issue that is described [here](https://andygrove.io/2019/08/apache-spark-regressions-eks/)

Replace the following files by the later version 4.4.2:

- $SPARK_HOME/jars/kubernetes-client-4.1.2.jar
- $SPARK_HOME/jars/kubernetes-model-4.1.2.jar
- $SPARK_HOME/jars/kubernetes-model-common-4.1.2.jar

Here is the bash script to do that:

```bash
# Back-up an old version of the kubernetes files
mkdir -p spark/jars_k8s_old && mv spark/jars/kuber* $_

LIB_VERSION="4.4.2"
REPO=https://search.maven.org/remotecontent?filepath=io/fabric8
JAR_DIR=/home/bigdata/spark/jars

# List of files to download
FileArray=("kubernetes-client"  "kubernetes-model"  "kubernetes-model-common")

# Download the files and set the default permission to them
for file in ${FileArray[*]}; do
    wget -O $JAR_DIR/$file-$LIB_VERSION.jar $REPO/$file/$LIB_VERSION/$file-$LIB_VERSION.jar && chmod 644 $JAR_DIR/$file-$LIB_VERSION.jar
done
```

If you don't want to create a bash script file, you can run it in termimal as follows:

```
bash -c 'YOUR_CODE'
```

## Cleaning Up

Delete the driver pod in the `spark` namespace:

`sudo /opt/k8s/kubectl delete pod spark-pi-1577001982580-driver --namespace spark`

Delete the service:

`sudo /opt/k8s/kubectl delete service spark-pi-1577001982580-driver-svc -n spark`

Stop the cluster:

`sudo /opt/k8s/minikube stop`

```
✋  Stopping "minikube" in none ...
✋  Stopping "minikube" in none ...
🛑  "minikube" stopped.
```

Delete the cluster:

`sudo /opt/k8s/minikube delete`

```
🔄  Uninstalling Kubernetes v1.17.0 using kubeadm ...
🔥  Deleting "minikube" in none ...
💔  The "minikube" cluster has been deleted.
🔥  Successfully deleted profile "minikube"
```


## References

- [Running Spark on Kubernetes](https://spark.apache.org/docs/2.4.4/running-on-kubernetes.html)
- [Quick Start Guide — Submit Spark (2.4) Jobs on Minikube/AWS](https://medium.com/@aelbuni/apache-spark-2-4-3-running-jobs-in-kubernetes-cluster-ebd7a28b99cd)
- [EKS security patches cause Apache Spark jobs to fail with permissions error](https://andygrove.io/2019/08/apache-spark-regressions-eks/)
- [Kubernetes Dashboard](https://github.com/kubernetes/dashboard)
- [Web UI (Dashboard)](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [Creating sample user](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md)



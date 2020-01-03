# Hadoop on Docker. Part 5: Deploying on multiple hosts using Docker Swarm Mode

Sergei Yu. Papulin (papulin.study@yandex.ru)

## Contents

- Enabling Swarm Mode
- Creating Private Registry Service
- Creating Hadoop Services
- Running MapReduce Application
- Cleaning Up
- References


## Prerequisites

- 2 nodes (bare or virtual hosts) with Docker Engine in same network
- Each node should have at least 2 vCPU and 4G memory
- Hadoop Master and Worker Images (see [Part 3](hadoop_docker_part_3.md))

## Previous steps

- [Part 1: Introduction](hadoop_docker_part_1.md)
- [Part 2: Building Base Hadoop Image](hadoop_docker_part_2.md)
- [Part 3: Building Hadoop Master and Worker Images](hadoop_docker_part_3.md)
- [Part 4: Deploying using Docker Compose and Running MapReduce Application](hadoop_docker_part_4.md)


## Enabling Swarm Mode

To activate Swarm Mode, you have to initialize one of your hosts as the manager node. There could be one or more managers on different hosts. After that join another host as a worker by running the `join` command. 

In this tutorial we will use single manager and worker nodes as shown below.

<center>

![ Namenode Web UI](img/docker/hd_swarm_1.png "Namenode Web UI")

<i>Figure 1. Two-node Swarm Cluster</i>
</center>

#### Creating manager node

Initialize the swarm on the manager node:

```
docker swarm init \
    --advertise-addr 192.168.5.5
```

```
Swarm initialized: current node (z86fwa4upl7lseecqlap3imlb) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-2l1ln3qg7d3i3dse67lnkcoojkh1zixkgy53st0h8s4m98eze0-9dt3zhk48rlvhkzu3ot1lke4l 192.168.5.5:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

The output of the command contains a worker join-token. This token is necessary to bind other nodes to the swarm as workers. You can print it by running the following command:

`docker swarm join-token worker`

Display all nodes of the swarm:

`docker node ls`

```
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
z86fwa4upl7lseecqlap3imlb *   vhost-1             Ready               Active              Leader              19.03.5
```

#### Creating worker node

On the worker node run the following command to join the node to the swarm:

```
docker swarm join \
    --token SWMTKN-1-2l1ln3qg7d3i3dse67lnkcoojkh1zixkgy53st0h8s4m98eze0-9dt3zhk48rlvhkzu3ot1lke4l \
    --advertise-addr enp0s3 \
    192.168.5.5:2377
```


```
This node joined a swarm as a worker.
```

Now, on the manager node display all nodes:

`docker node ls`

```
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
z86fwa4upl7lseecqlap3imlb *   vhost-1             Ready               Active              Leader              19.03.5
jqz1ctzdzugt6s6i8c45qw08z     vhost-2             Ready               Active                                  19.03.5
```

Note that this command works only on the manager.

Display the current state of the swarm:

`docker info`

```
...
 Swarm: active
  NodeID: z86fwa4upl7lseecqlap3imlb
  Is Manager: true
  ClusterID: p2nq1duiyegtnr6dvwptfn0jq
  Managers: 1
  Nodes: 2
  Default Address Pool: 10.0.0.0/8  
  SubnetSize: 24
  Data Path Port: 4789
  Orchestration:
   Task History Retention Limit: 5
  Raft:
   Snapshot Interval: 10000
   Number of Old Snapshots to Retain: 0
   Heartbeat Tick: 1
   Election Tick: 10
  Dispatcher:
   Heartbeat Period: 5 seconds
  CA Configuration:
   Expiry Duration: 3 months
   Force Rotate: 0
  Autolock Managers: false
  Root Rotation In Progress: false
  Node Address: 192.168.5.5
  Manager Addresses:
   192.168.5.5:2377
...
```

## Creating Private Registry Service

As said in the official doc:

> The Registry is a stateless, highly scalable server side application that stores and lets you distribute Docker images.

All nodes in a cluster have to be able to pull images for deploying services. For this purpose you can use the Docker Hub, Docker Trusted Registry, or create your private registry.

To deploy the private registry, let's take the following steps:

- Create self-signed certificate  
- Copy the public cert to the worker
- Deploy the registry service
- Push Hadoop images to the registry

<center>

![Private Registry as Service](img/docker/hd_swarm_2.png "Private Registry as Service")

<i>Figure 2. Private Registry as Service</i>
</center>

#### Creating self-signed certificate

In your working directory `$YOUR_PATH/projects/docker/hadoop` create a new directory named `certs` that will be used to store certificates and then we will mount it to the registry service:

`mkdir -p certs`

To use an ip address instead of hostname as a repository prefix add the following line to `/etc/ssl/openssl.cnf`:

```
subjectAltName=IP:192.168.5.5 # your manager node ip
```

Now, generate your certificate on the manager node:

```
openssl req \
  -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key \
  -x509 -days 365 -out certs/domain.crt
```

#### Copying the public cert to the worker

Copy the public part `domain.crt` to `/etc/docker/certs.d/192.168.5.5:5000`:

`sudo mkdir -p /etc/docker/certs.d/192.168.5.5:5000 && sudo cp certs/domain.crt $_`

Copy `domain.crt` to the worker node. Firstly, create the directory:

`ssh -t bigdata@192.168.5.6 "sudo mkdir -p /etc/docker/certs.d/192.168.5.5:5000 && sudo chown -R bigdata:bigdata /etc/docker/certs.d/192.168.5.5:5000"`

And then copy the file:

`scp certs/domain.crt bigdata@192.168.5.6:/etc/docker/certs.d/192.168.5.5:5000`

```
bigdata@192.168.5.6's password: 
domain.crt                                                                                                                                    100% 1964     1.0MB/s   00:00
```

#### Troubleshooting

Run the following command to generate HTTPS request to the registry:

`curl -v https://192.168.5.5:5000/`

If you get a response with status `200`, then everything is fine, your registry works like a charm. However, if there is an error status, try to do the following steps on both hosts:

`sudo cp certs/domain.crt /usr/local/share/ca-certificates/192.168.5.5.crt`

`sudo update-ca-certificates`

If still broken, try [this link](https://docs.docker.com/registry/insecure/). Maybe you will find something useful there.

#### Deploying the registry service

Now, it's time to launch the registry service. On the manager run the following command:

```
docker service create --name registry \
    --mount target=/certs,source="$(pwd)"/certs,type=bind \
    --mode replicated \
    --replicas 1 \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
    -p 5000:5000 \
    --constraint 'node.role == manager' \
    registry:2
```

```
u57qsxb1y278kttwqqbwudgbl
overall progress: 1 out of 1 tasks 
1/1: running   [==================================================>] 
verify: Service converged 
```

Print out running services in terminal:

`docker service ls`

```
ID                  NAME                MODE                REPLICAS            IMAGE               PORTS
u57qsxb1y278        registry            replicated          1/1                 registry:2          *:5000->5000/tcp
```

#### Pushing Hadoop images to the registry

In the 3d part of tutorial we have built two images: `hadoop-master-image` and `hadoop-worker-image`. So these images should be in your local repository (on the manager node). If not, see how to create them [here](hadoop_docker_part_3.md).

To make images available across multiple hosts we should tag them with our repository prefix `192.168.5.5:5000` and push them to the registry.

To tag the images run the following commands:

`docker tag hadoop-master-image 192.168.5.5:5000/hadoop-master-image`

`docker tag hadoop-worker-image 192.168.5.5:5000/hadoop-worker-image`

Now push `192.168.5.5:5000/hadoop-master-image` to the registry:

`docker push 192.168.5.5:5000/hadoop-master-image`

```
The push refers to repository [192.168.5.5:5000/hadoop-master-image]
c5017938b20e: Pushed 
922e6bdd6d66: Pushed 
624024164081: Pushed 
f259faf2354d: Pushed 
8d1f8522b26e: Pushed 
3d07e3f60663: Pushed 
fa44fd8460e9: Pushed 
438ee4e74576: Pushed 
34032783db35: Pushed 
7af1338539ab: Pushed 
72b49afd07bf: Pushed 
fbc3b2dba006: Pushed 
dfc3c372b2bb: Pushed 
831c5620387f: Pushed 
latest: digest: sha256:4a6904d313224b6a126b4d21b4fd2ede27b1d6aebbbcbc3d964fdfbcf19749d4 size: 3246
```

The same for the second image:

`docker push 192.168.5.5:5000/hadoop-worker-image`

```
The push refers to repository [192.168.5.5:5000/hadoop-worker-image]
f8562304087d: Pushed 
79e0b523c15a: Pushed 
0b6e5bf87ed6: Pushed 
8d1f8522b26e: Mounted from hadoop-master-image 
3d07e3f60663: Mounted from hadoop-master-image 
fa44fd8460e9: Mounted from hadoop-master-image 
438ee4e74576: Mounted from hadoop-master-image 
34032783db35: Mounted from hadoop-master-image 
7af1338539ab: Mounted from hadoop-master-image 
72b49afd07bf: Mounted from hadoop-master-image 
fbc3b2dba006: Mounted from hadoop-master-image 
dfc3c372b2bb: Mounted from hadoop-master-image 
831c5620387f: Mounted from hadoop-master-image 
latest: digest: sha256:e63c3073c5e495ba0b2bc2f05da02af0585bd2c79ae2b289c0f379574aa7e758 size: 3037
```

Now your images can be pulled by different hosts from your private repository.

## Creating Hadoop Services

To run Hadoop services, we will do the following activities:

- Create a custom overlay network
- Create Hadoop services
- Inspect running services
- Check Hadoop daemons
- Scale Services

The services should be deployed as shown below.

<center>

![Hadoop Services](img/docker/hd_swarm_3.png "Hadoop Services")

<i>Figure 3. Hadoop Services</i>
</center>


### Custom Overlay Network

Overlay network is a network that is distributed across multiple hosts. When you initialize the swarm, the `ingress` overlay network will be created automatically. 

To create your own custom network run the following command:

`docker network create -d overlay hadoop-network`

```
qbcx0qxqwjuis8vdd0iqiutoj
```

### Hadoop Services

Let's impose the following constraints for master and worker services:

- master:
    - it must be on the manager node
    - there need to be only one master
    - it should expose ports for Web UI

- worker:
    - there should be one replica per node

####  Creating Master Service

Create a service as follows:

```
docker service create \
    --name master \
    --hostname master \
    --mount target=/app,source="$(pwd)"/app,type=bind \
    --mount target=/data,source="$(pwd)"/data,type=bind \
    --network hadoop-network \
    --endpoint-mode dnsrr \
    --mode replicated \
    --replicas 1 \
    --publish published=9870,target=9870,mode=host \
    --publish published=8088,target=8088,mode=host \
    --publish published=19888,target=19888,mode=host \
    --constraint 'node.role == manager' \
    192.168.5.5:5000/hadoop-master-image
```

```
2k5h4cpr3eheqion88rbwwrw4
overall progress: 1 out of 1 tasks 
1/1: running   [==================================================>] 
verify: Service converged 
```

#### Creating Worker Service

Create a service as follows:

```
docker service create \
    --name worker \
    --network hadoop-network \
    --endpoint-mode dnsrr \
    --replicas 2 \
    --replicas-max-per-node 1 \
    192.168.5.5:5000/hadoop-worker-image
```

```
uiu4bwmoakzuwaol8cj83yvt7
overall progress: 2 out of 2 tasks 
1/2: running   [==================================================>] 
2/2: running   [==================================================>] 
verify: Service converged 
```

### Inspecting services

There are multiple objects related with services that can be inspected such as:

- Services themselves
- Tasks that are run based on service definitions
- Containers that is execution unit of tasks
- Network

#### Services

Display all services:

`docker service ls`

```
ID                  NAME                MODE                REPLICAS               IMAGE                                         PORTS
2k5h4cpr3ehe        master              replicated          1/1                    192.168.5.5:5000/hadoop-master-image:latest   
u57qsxb1y278        registry            replicated          1/1                    registry:2                                    *:5000->5000/tcp
uiu4bwmoakzu        worker              replicated          2/2 (max 1 per node)   192.168.5.5:5000/hadoop-worker-image:latest 
```

To go into details about the master service, for instance, run the following command:

`docker service inspect master`

```
ID:             2k5h4cpr3eheqion88rbwwrw4
Name:           master
Service Mode:   Replicated
 Replicas:      1
Placement:
 Constraints:   [node.role == manager]
UpdateConfig:
 Parallelism:   1
 On failure:    pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Update order:      stop-first
RollbackConfig:
 Parallelism:   1
 On failure:    pause
 Monitoring Period: 5s
 Max failure ratio: 0
 Rollback order:    stop-first
ContainerSpec:
 Image:         192.168.5.5:5000/hadoop-master-image:latest@sha256:4a6904d313224b6a126b4d21b4fd2ede27b1d6aebbbcbc3d964fdfbcf19749d4
 Init:          false
Mounts:
 Target:        /app
  Source:       /home/bigdata/docker/hadoop/app
  ReadOnly:     false
  Type:         bind
 Target:        /data
  Source:       /home/bigdata/docker/hadoop/data
  ReadOnly:     false
  Type:         bind
Resources:
Networks: hadoop-network 
Endpoint Mode:  dnsrr
Ports:
 PublishedPort = 9870
  Protocol = tcp
  TargetPort = 9870
  PublishMode = host
 PublishedPort = 8088
  Protocol = tcp
  TargetPort = 8088
  PublishMode = host
 PublishedPort = 19888
  Protocol = tcp
  TargetPort = 19888
  PublishMode = host 
```

#### Tasks

To display all tasks related to a particular service, use the `docker service ps` command as follows:

`docker service ps master`

```
ID                  NAME                IMAGE                                         NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
una5z7xy6jyc        master.1            192.168.5.5:5000/hadoop-master-image:latest   vhost-1             Running             Running about a minute ago                       *:8088->8088/tcp,*:19888->19888/tcp,*:9870->9870/tcp
```


`docker service ps worker`

```
ID                  NAME                IMAGE                                         NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
qlsegw44l55j        worker.1            192.168.5.5:5000/hadoop-worker-image:latest   vhost-2             Running             Running about a minute ago                       
53kgs6623q9z        worker.2            192.168.5.5:5000/hadoop-worker-image:latest   vhost-1             Running             Running about a minute ago    
```

#### Containers

There is no command to show all containers in a cluster. You can display containers on each host of the cluster by running the `docker ps` command.

So on the manager node run the following command to show all running conainers on this host:

`docker ps`

```
CONTAINER ID        IMAGE                                         COMMAND                  CREATED              STATUS              PORTS                                                                      NAMES
6f07e08a706d        192.168.5.5:5000/hadoop-worker-image:latest   "sh /usr/local/bin/e…"   About a minute ago   Up About a minute                                                                              worker.2.53kgs6623q9z6tcsbvbwalrz7
4e633b29a6d5        192.168.5.5:5000/hadoop-master-image:latest   "sh /usr/local/bin/e…"   About a minute ago   Up About a minute   0.0.0.0:8088->8088/tcp, 0.0.0.0:9870->9870/tcp, 0.0.0.0:19888->19888/tcp   master.1.una5z7xy6jyc7yyn3owmske9z
87ad20bddde7        registry:2                                    "/entrypoint.sh /etc…"   4 minutes ago        Up 4 minutes        5000/tcp                                                                   registry.1.nw987d8mwjyzqw02ceeszdeaw
```

The same way for the worker node:

`docker ps`

```
CONTAINER ID        IMAGE                                         COMMAND                  CREATED              STATUS              PORTS               NAMES
40bebebe0d27        192.168.5.5:5000/hadoop-worker-image:latest   "sh /usr/local/bin/e…"   About a minute ago   Up About a minute                       worker.1.qlsegw44l55jws2t6oq5aqk86
```

#### Network

Similar to the previous case, networks must be inspected on each host.

On the manager run the following command:

`docker network inspect hadoop-network`

```
[
    {
        "Name": "hadoop-network",
        "Scope": "swarm",
        "Driver": "overlay",
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "10.0.1.0/24",
                    "Gateway": "10.0.1.1"
                }
            ]
        },,
        "Containers": {
            "4e633b29a6d57d5c961737e0606d3be8bfca5a63bae05e08ef46ae2bdfa964c7": {
                "Name": "master.1.una5z7xy6jyc7yyn3owmske9z",
                "IPv4Address": "10.0.1.2/24",
            },
            "6f07e08a706d8e832d205e1017d62acc8135035d5d5ca03816609e5ed0e5f73e": {
                "Name": "worker.2.53kgs6623q9z6tcsbvbwalrz7",
                "IPv4Address": "10.0.1.5/24",
            },
            "lb-hadoop-network": {
                "Name": "hadoop-network-endpoint",
                "IPv4Address": "10.0.1.3/24",
            }
        },
        "Options": {
            "com.docker.network.driver.overlay.vxlanid_list": "4097"
        },
        "Peers": [
            {
                "Name": "44ee58f44849",
                "IP": "192.168.5.5"
            },
            {
                "Name": "9242fd08a9aa",
                "IP": "192.168.5.6"
            }
        ]
    }
]
```

And for the worker:

`docker network inspect hadoop-network`

```
[
    {
        "Name": "hadoop-network",
        "Scope": "swarm",
        "Driver": "overlay",
        "IPAM": {
            "Driver": "default",
            "Config": [
                {
                    "Subnet": "10.0.1.0/24",
                    "Gateway": "10.0.1.1"
                }
            ]
        },
        "Containers": {
            "40bebebe0d27f1f282755300c2c3d2dd38fa2ada24aafe2fc168e3a2c77b545c": {
                "Name": "worker.1.qlsegw44l55jws2t6oq5aqk86",
                "IPv4Address": "10.0.1.4/24",
            },
            "lb-hadoop-network": {
                "Name": "hadoop-network-endpoint",
                "IPv4Address": "10.0.1.6/24",
            }
        },
        "Options": {
            "com.docker.network.driver.overlay.vxlanid_list": "4097"
        },
        "Peers": [
            {
                "Name": "44ee58f44849",
                "IP": "192.168.5.5"
            },
            {
                "Name": "9242fd08a9aa",
                "IP": "192.168.5.6"
            }
        ]
    }
]
```

### Hadoop Daemons

Now, as we checked all running services, let's dive into Hadoop daemons. For this purpose we will inspect:

- Service Logs
- HDFS Namenode
- YARN ResourceManager

#### Service Logs

`docker service logs master`

```
master.1.una5z7xy6jyc@vhost-1    | Start SSH service
master.1.una5z7xy6jyc@vhost-1    | Starting OpenBSD Secure Shell server: sshd.
master.1.una5z7xy6jyc@vhost-1    | Start Hadoop daemons
master.1.una5z7xy6jyc@vhost-1    | The entrypoint script is completed
```


`docker service logs worker`

```
worker.2.53kgs6623q9z@vhost-1    | Start SSH service
worker.2.53kgs6623q9z@vhost-1    | Starting OpenBSD Secure Shell server: sshd.
worker.2.53kgs6623q9z@vhost-1    | Start Hadoop daemons
worker.2.53kgs6623q9z@vhost-1    | WARNING: /home/bigdata/hadoop/logs does not exist. Creating.
worker.1.qlsegw44l55j@vhost-2    | Start SSH service
worker.1.qlsegw44l55j@vhost-2    | Starting OpenBSD Secure Shell server: sshd.
worker.1.qlsegw44l55j@vhost-2    | Start Hadoop daemons
worker.1.qlsegw44l55j@vhost-2    | WARNING: /home/bigdata/hadoop/logs does not exist. Creating.
```

#### HDFS Namenode

To run commands in running containers we use `docker exec` and supply a container id or name. To extract a container id of the master task, run the following command on the manager node:

`docker ps --filter name=master --format "{{.ID}}"`

```
MASTER_CONTAINER_ID
```

Now, display a HDFS topology by running the command below:

`docker exec MASTER_CONTAINER_ID bash hdfs dfsadmin -printTopology`

```
Rack: /default-rack
   10.0.1.4:9866 (worker.1.qlsegw44l55jws2t6oq5aqk86.hadoop-network)
   10.0.1.5:9866 (worker.2.53kgs6623q9z6tcsbvbwalrz7.hadoop-network)
```


#### YARN ResourceManager

Print out all nodes that participate in YARN:

`docker exec MASTER_CONTAINER_ID bash yarn node --list`

```
INFO client.RMProxy: Connecting to ResourceManager at master/10.0.1.2:8032
Total Nodes:2
         Node-Id             Node-State Node-Http-Address       Number-of-Running-Containers
40bebebe0d27:45454              RUNNING 40bebebe0d27:8042                                  0
6f07e08a706d:45454              RUNNING 6f07e08a706d:8042                                  0
```

### Scaling Services

To scale your services you should consider the following options:

- increase worker nodes by `docker swarm join`
- update `replicas-max-per-node` (0 = unlimited) by `docker service update --replicas-max-per-node N worker`
- increase the number of workers by `docker service scale worker=M`


## Running MapReduce Application

Now when everything is started and working properly, it's time to launch a test MapReduce application in two steps:

- Copy a sample dataset with reviews to HDFS
- Submit the application


#### Copying data to HDFS

To copy data from bound directory of your master task to HDFS, run the following command:

`docker exec MASTER_CONTAINER_ID bash hdfs dfs -copyFromLocal /data /`

Check whether the process was completed successfully:

`docker exec MASTER_CONTAINER_ID bash hdfs dfs -ls /data`

```
Found 2 items
-rw-r--r--   3 bigdata supergroup 1478965298 2019-12-30 18:59 /data/reviews.json
-rw-r--r--   3 bigdata supergroup      69053 2019-12-30 18:59 /data/samples_100.json
```

#### Running application

```
docker exec MASTER_CONTAINER_ID bash \
    yarn jar /app/average-rating-app-1.1.jar \
        -D mapreduce.job.reduces=2 \
        /data/reviews.json \
        /data/output/ratings/
```

```
...
INFO mapreduce.Job: The url to track the job: http://master:8088/proxy/application_1577732140960_0001/
INFO mapreduce.Job: Running job: job_1577732140960_0001
INFO mapreduce.Job: Job job_1577732140960_0001 running in uber mode : false
INFO mapreduce.Job:  map 0% reduce 0%
INFO mapreduce.Job:  map 9% reduce 0%
INFO mapreduce.Job:  map 18% reduce 0%
INFO mapreduce.Job:  map 27% reduce 0%
INFO mapreduce.Job:  map 38% reduce 0%
INFO mapreduce.Job:  map 48% reduce 5%
INFO mapreduce.Job:  map 55% reduce 5%
INFO mapreduce.Job:  map 65% reduce 5%
INFO mapreduce.Job:  map 72% reduce 5%
INFO mapreduce.Job:  map 78% reduce 5%
INFO mapreduce.Job:  map 88% reduce 5%
INFO mapreduce.Job:  map 100% reduce 5%
INFO mapreduce.Job:  map 100% reduce 50%
INFO mapreduce.Job:  map 100% reduce 100%
INFO mapreduce.Job: Job job_1577732140960_0001 completed successfully
...
```

Check the output directory:

`docker exec MASTER_CONTAINER_ID bash hdfs dfs -ls -R /data/output`

```
drwxr-xr-x   - bigdata supergroup          0 2019-12-30 19:02 /data/output/ratings
-rw-r--r--   3 bigdata supergroup          0 2019-12-30 19:02 /data/output/ratings/_SUCCESS
-rw-r--r--   3 bigdata supergroup     741683 2019-12-30 19:02 /data/output/ratings/part-r-00000
-rw-r--r--   3 bigdata supergroup     742080 2019-12-30 19:02 /data/output/ratings/part-r-00001
```

Display first lines of `part-r-00000`:

`docker exec MASTER_CONTAINER_ID bash hdfs dfs -head /data/output/ratings/part-r-00000`

```
0528881469      2.4
0594451647      4.2
0594481813      4.0
0972683275      4.461187214611872
1400501466      3.953488372093023
1400501776      4.15
1400532620      3.6097560975609757
...
```

Display all applications with the `FINISHED` state:

`docker exec MASTER_CONTAINER_ID bash yarn app -list -appStates FINISHED`

```
2019-12-30 19:15:32,165 INFO client.RMProxy: Connecting to ResourceManager at master/10.0.1.2:8032
Total number of applications (application-types: [], states: [FINISHED] and tags: []):1
                Application-Id      Application-Name        Application-Type          User           Queue                   State             Final-State             Progress                       Tracking-URL
application_1577732140960_0001      AverageRatingApp               MAPREDUCE       bigdata             dev                FINISHED               SUCCEEDED                 100%http://master:19888/jobhistory/job/job_1577732140960_0001
```

That's all. The next step is to clean up your environment.


## Cleaning Up

This part includes the following steps:

- Remove Services: Worker, Master, Registry
- Remove Custom Network
- Turn down the swarm
- Remove Hadoop Images
- Remove certificate used for the Registry

Remove the services:

`docker service rm worker master registry`

```
worker
master
registry
```

Remove the network

`docker network rm hadoop-network`

```
hadoop-network
```

Leave the swarm on the worker node:

`docker swarm leave`

```
Node left the swarm.
```

Leave the swarm on the manager node:

`docker swarm leave --force`

```
Node left
```

Remove images on both hosts:

- all images will be deleted:

`docker rmi $(docker images -a -q)`

- images with the `192.168.5.5:5000` repo prefix  will be deleted:

`docker rmi -f $(docker image ls --filter=reference='192.168.5.5:5000*/*' -q)`


Remove the certificate on both hosts:

```
TODO: delete cert
```

## References


- [Swarm mode overview](https://docs.docker.com/engine/swarm/)
- [Swarm mode key concepts](https://docs.docker.com/engine/swarm/key-concepts/)
- [Getting started with swarm mode](https://docs.docker.com/engine/swarm/swarm-tutorial/)
- [Deploy services to a swarm](https://docs.docker.com/engine/swarm/services/)
- [Use overlay networks](https://docs.docker.com/network/overlay/)
- [Networking with overlay networks](https://docs.docker.com/network/network-tutorial-overlay/)
- [Deploy a registry server](https://docs.docker.com/registry/deploying/)
- [Test an insecure registry](https://docs.docker.com/registry/insecure/)

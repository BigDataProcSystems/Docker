# HOWTO: Install Docker and Docker-Compose

Sergei Yu. Papulin (papulin.study@yandex.ru)

## Contents

- [Installing Docker](#Installing-Docker)
- [Installing Docker Compose](#Installing-Docker-Compose)
- [References](#References)


## Installing Docker

```
sudo apt update

sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"


sudo apt-get install -y \
    docker-ce=5:19.03.14~3-0~ubuntu-bionic \
    docker-ce-cli=5:19.03.14~3-0~ubuntu-bionic \
    containerd.io=1.3.9-1
```

Display the docker version:
```cmd
ubuntu@linux:~$ docker --version
Docker version 19.03.14, build 5eb3275d40
```

`sudo docker run hello-world`

```cmd
ubuntu@linux:~$ sudo docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
0e03bdcc26d7: Pull complete 
Digest: sha256:1a523af650137b8accdaed439c17d684df61ee4d74feac151b5b337bd29e7eec
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.
...
```

But when you run the same command without the root privilege, you get the following error:

```
docker: Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Post http://%2Fvar%2Frun%2Fdocker.sock/v1.40/containers/create: dial unix /var/run/docker.sock: connect: permission denied.
```

To rid of the `sudo` prefix when run `docker` commands, do the following steps.

Create the `docker` group if it doesn't exist:

`sudo groupadd docker`

Add the current user to the `docker` group:

 `sudo usermod -G docker -a $USER`

Apply changes (only for Linux, otherwise restart the system):

`newgrp docker`

Test whether everything is working correctly:

`docker run hello-world`


## Installing Docker Compose

`sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose`

If there is the error "ERROR: client and server don't have same version (client : 1.38, server: 1.18)", download another compatible version of docker-compose from [here](https://github.com/docker/compose/releases)

Make it executable:

`sudo chmod +x /usr/local/bin/docker-compose`

Create a soft symbolic link to `docker-compose` to use it in the `/usr/bin` directory:

`sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose`

Now check whether the `docker-compose` works by printing its version:

```cmd
ubuntu@linux:~$ docker-compose --version
docker-compose version 1.27.4, build 40524192
```


## References

- [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) (official doc)
- [Post-installation steps for Linux](https://docs.docker.com/engine/install/linux-postinstall/) (official doc)
- [Install Docker Compose](https://docs.docker.com/compose/install/) (official doc)
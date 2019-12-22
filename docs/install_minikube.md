# HOWTO: Install Minikube

Sergei Yu. Papulin (papulin.study@yandex.ru)


## Install kubectl on Linux:

Download the `Kubernetes` command-line tool:

`wget -P $HOME/Downloads https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl`

Then create the `/usr/local/bin` directory if needed, move the tool to the directory and change the permission to make the file executable for all users:

```bash
sudo mkdir -p /usr/local/bin \
  && sudo mv $HOME/Downloads/kubectl $_ \
  && sudo chmod +x /usr/local/bin/kubectl
```

If the directory is not in your `PATH` variable, add it by the following command (a better way is to append this line to the `.profile` file of your current user):

`export PATH=/usr/local/bin:$PATH`

Now check whether everything is fine by printing version of `kubectl`:

`kubectl version`

```
Client Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.0", GitCommit:"70132b0f130acc0bed193d9ba59dd186f0e634cf", GitTreeState:"clean", BuildDate:"2019-12-07T21:20:10Z", GoVersion:"go1.13.4", Compiler:"gc", Platform:"linux/amd64"}
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```


## Install minikube

Download `minikube` that is a tool for local Kubernetes application development:

`wget -O $HOME/Downloads/minikube /opt/k8s/minikube https://storage.googleapis.com/minikube/releases/v1.6.1/minikube-linux-amd64`

The same way as for `kubectl`, create the `/usr/local/bin directry` if needed, move the tool to the directory and change the permission to make the file executable for all users:

```bash
sudo mkdir -p /usr/local/bin \
  && sudo mv $HOME/Downloads/minikube $_ \
  && sudo chmod +x /usr/local/bin/minikube
```

Now check your version of `minikube`:

`minikube version`

```
minikube version: v1.6.1
```

## References

[Install and Set Up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux)

[Install Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
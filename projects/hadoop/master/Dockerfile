FROM hadoop-base-image

LABEL maintainer="Sergei Papulin <papulin_bmstu@mail.ru>"

#RUN ssh-keyscan -H 192.168.1.162 >> ~/.ssh/known_hosts

USER root

# only for master
COPY ./base/keys/id_rsa .ssh/
RUN chown -R bigdata:bigdata .ssh && chmod 400 .ssh/id_rsa

COPY ./master/entrypoint.sh /usr/local/bin/
RUN chown -R bigdata:bigdata /usr/local/bin/entrypoint.sh 
RUN chmod +x /usr/local/bin/entrypoint.sh

USER bigdata

# Only for Namenode
RUN hdfs namenode -format -force

ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]
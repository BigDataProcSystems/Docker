FROM spark-base-image

USER root

# ======================
#
# SSH setup
#
# ======================

# TODO: for slaves
COPY ./base/keys/id_rsa.pub .ssh/

#RUN mkdir .ssh

RUN cat .ssh/id_rsa.pub >> .ssh/authorized_keys \
    && chown -R bigdata:bigdata .ssh/id_rsa.pub

COPY ./worker/entrypoint.sh /usr/local/bin/
RUN chown -R bigdata:bigdata /usr/local/bin/entrypoint.sh 
RUN chmod +x /usr/local/bin/entrypoint.sh

USER bigdata

ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]
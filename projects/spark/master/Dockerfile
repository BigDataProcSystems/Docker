FROM spark-base-image

LABEL maintainer="Sergei Papulin <papulin_bmstu@mail.ru>"

#RUN ssh-keyscan -H 192.168.1.162 >> ~/.ssh/known_hosts

# Change the current user to root
USER root

# Copy a master private key (only for the master)
COPY ./base/keys/id_rsa .ssh/
RUN chown -R bigdata:bigdata .ssh && chmod 400 .ssh/id_rsa

# Copy an entrypoint script for the master node
COPY ./master/entrypoint.sh /usr/local/bin/
RUN chown -R bigdata:bigdata /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

# Install the Jupyter Notebook Server
RUN python3 -m pip install jupyter

# Copy a Jupyter configuration file
COPY ./base/config/jupyter/jupyter_notebook_config.py .jupyter/
RUN chown -R bigdata:bigdata .jupyter && chmod -R 500 .jupyter

# Copy a kernel specification to enable PySpark functionality in Jupyter notebooks
COPY ./base/config/jupyter/pyspark-kernel.json .local/share/jupyter/kernels/pyspark/kernel.json
RUN chown -R bigdata:bigdata .local

# Change the current user to bigdata
USER bigdata

# Create a directory for Spark logs and Jupyter notebooks
RUN mkdir -p tmp/spark-events && mkdir notebooks

# Format HDFS (only for Namenode)
RUN hdfs namenode -format -force

# Run an entrypoint script on startup
ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]
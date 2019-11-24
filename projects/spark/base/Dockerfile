FROM ubuntu:14.04

LABEL maintainer="Sergei Papulin <papulin_bmstu@mail.ru>"


# ======================
#
# Install packages
#
# ======================

RUN apt update && apt install -y openssh-server software-properties-common nano \
    && add-apt-repository ppa:openjdk-r/ppa \
    && apt update && apt -y install openjdk-8-jdk

RUN apt-get clean && rm -rf /var/lib/apt/lists/*


# ======================
#
# Create user
#
# ======================

# User home directory
ENV BASE_USER_DIR /home/bigdata

# Create user
RUN useradd -m -d $BASE_USER_DIR -s /bin/bash -p "$(openssl passwd -1 54321)" bigdata 

# Set current dir
WORKDIR /home/bigdata


# ======================
#
# Install Hadoop
#
# ======================

# TODO: try it out instead of wget
#ADD http://example.com/big.tar.xz /usr/src/things/

# Install Hadoop
RUN mkdir hadoop \
    && wget -P /home/bigdata/sources https://archive.apache.org/dist/hadoop/common/hadoop-3.1.2/hadoop-3.1.2.tar.gz \
    && tar -xvf sources/hadoop-3.1.2.tar.gz --directory hadoop --strip-components 1 \
    && rm sources/hadoop-3.1.2.tar.gz

# Set Hadoop environment variables
ENV HADOOP_HOME $BASE_USER_DIR/hadoop
ENV HADOOP_CONF_DIR $HADOOP_HOME/etc/hadoop
ENV PATH $HADOOP_HOME/bin:$HADOOP_HOME:$PATH

# Copy Hadoop configuration files
COPY ["config/hdfs", "config/yarn", "config/mapreduce", "$HADOOP_CONF_DIR/"]

# Change an owner of the Hadoop directory
RUN chown -R bigdata:bigdata $HADOOP_HOME 


# ======================
#
# Install Spark
#
# ======================

# Install Spark
RUN mkdir spark \
    && wget -P /home/bigdata/sources https://archive.apache.org/dist/spark/spark-2.3.3/spark-2.3.3-bin-hadoop2.7.tgz \
    && tar -xvf sources/spark-2.3.3-bin-hadoop2.7.tgz --directory spark --strip-components 1 \
    && rm sources/spark-2.3.3-bin-hadoop2.7.tgz

# Set Spark environment variables
ENV SPARK_HOME $BASE_USER_DIR/spark
ENV SPARK_CONF_DIR $SPARK_HOME/conf
ENV PATH $SPARK_HOME/bin:$SPARK_HOME:$PATH

# Copy Hadoop configuration files
COPY ["config/spark", "$SPARK_CONF_DIR/"]

# Change an owner of the Spark directory
RUN chown -R bigdata:bigdata $SPARK_HOME 


# ======================
#
# Install pip3 for Python
#
# ======================

RUN apt update && apt -y install python3-pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade pip

# Add sudo permission for the bigdata user to start ssh service
RUN echo "bigdata ALL=NOPASSWD:/usr/sbin/service ssh start" >> /etc/sudoers


# COPY entrypoint.sh /usr/local/bin/
# RUN chown -R bigdata:bigdata /usr/local/bin/entrypoint.sh 
# RUN chmod +x /usr/local/bin/entrypoint.sh

# change root to the bigdata user
# USER bigdata

# ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]
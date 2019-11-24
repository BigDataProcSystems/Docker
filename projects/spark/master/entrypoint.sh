# Start the SSH service
sudo service ssh start

# Start Hadoop daemons
hdfs --daemon start namenode
hdfs --daemon start datanode 
hdfs --daemon start secondarynamenode
yarn --daemon start resourcemanager
yarn --daemon start nodemanager

# Start the MapReduce History Server
# mapred --daemon start historyserver

# Start the Spark History Server
$SPARK_HOME/sbin/start-history-server.sh

# FOR DEBUG
# hdfs dfs -mkdir /data && hdfs dfs -copyFromLocal /home/bigdata/data/Electronics_5.json /data/ && hdfs dfs -copyFromLocal /home/bigdata/data/samples_100.json /data/

# Run the Jupyter notebook server
jupyter notebook --config .jupyter/jupyter_notebook_config.py

tail -f /dev/null
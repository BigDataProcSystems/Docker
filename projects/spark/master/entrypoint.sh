sudo service ssh start
hdfs --daemon start namenode
hdfs --daemon start datanode 
hdfs --daemon start secondarynamenode
yarn --daemon start resourcemanager
yarn --daemon start nodemanager
mapred --daemon start historyserver

# FOR DEBUG
hdfs dfs -mkdir /data && hdfs dfs -copyFromLocal /home/bigdata/data/Electronics_5.json /data/ && hdfs dfs -copyFromLocal /home/bigdata/data/samples_100.json /data/

tail -f /dev/null
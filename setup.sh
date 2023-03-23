#!/bin/bash
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin"; pwd`
DEFAULT_DOWNLOAD_DIR="$bin"/download
DEFAULT_DOWNLOAD_DIR=${DEFAULT_DOWNLOAD_DIR:-$DEFAULT_DOWNLOAD_DIR}
[ ! -d $DEFAULT_DOWNLOAD_DIR ] && mkdir -p $DEFAULT_DOWNLOAD_DIR

INSTALL_PATH=/opt/module
HOST_NAME=hadoop

# https://github.com/martinprobson/vagrant-hadoop-hive-spark/blob/master/DEVELOP.md
# Install url
JAVA_URL=https://repo.huaweicloud.com/java/jdk/8u201-b09/jdk-8u201-linux-x64.tar.gz
HADOOP_URL=https://mirrors.huaweicloud.com/apache/hadoop/core/hadoop-2.7.7/hadoop-2.7.7.tar.gz
HIVE_URL=https://mirrors.huaweicloud.com/apache/hive/hive-2.3.4/apache-hive-2.3.4-bin.tar.gz
SCALA_URL=https://downloads.lightbend.com/scala/2.11.12/scala-2.11.12.tgz
SPARK_URL=https://mirrors.huaweicloud.com/apache/spark/spark-2.0.2/spark-2.0.2-bin-hadoop2.7.tgz
ZOOKEEPER_URL=https://mirrors.huaweicloud.com/apache/zookeeper/zookeeper-3.5.7/apache-zookeeper-3.5.7-bin.tar.gz
HBASE_URL=https://mirrors.huaweicloud.com/apache/hbase/1.4.8/hbase-1.4.8-bin.tar.gz
PHOENIX_URL=https://archive.apache.org/dist/phoenix/apache-phoenix-4.14.0-HBase-1.4/bin/apache-phoenix-4.14.0-HBase-1.4-bin.tar.gz
KAFKA_URL=https://mirrors.huaweicloud.com/apache/kafka/2.4.1/kafka_2.11-2.4.1.tgz

# Add environment variables to the profile file
setupEnv_app() {
    local app_name=$1
    local type_name=$2
    echo "creating $app_name environment variables"
    local app_path=${INSTALL_PATH}/$app_name
    local app_name_uppercase=$(echo $app_name | tr '[a-z]' '[A-Z]')
    echo "# $app_name environment" >> /etc/profile
    echo "export ${app_name_uppercase}_HOME=$app_path" >> /etc/profile
    if [ ! -n "$type_name" ];then
        echo 'export PATH=${'$app_name_uppercase'_HOME}/bin:$PATH' >> /etc/profile
    else
        echo 'export PATH=${'$app_name_uppercase'_HOME}/bin:${'$app_name_uppercase'_HOME}/sbin:$PATH' >> /etc/profile
    fi
    echo -e "\n" >> /etc/profile
}

# Convert configuration to xml format
set_property() {
    local properties_file=$1
    local name=$2
    local value=$3
    local is_create=$4
    [ -z "${is_create}" ] && is_create=false

    if [ "${is_create}" == "false" ]
    then
        sed -i "/<\/configuration>/Q" ${properties_file}
    else
        [ ! -f ${properties_file} ] && touch ${properties_file}
        echo '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' >> ${properties_file}
        echo '<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>' >> ${properties_file}
        echo '<configuration>' >> ${properties_file}
    fi
    echo "  <property>" >> ${properties_file}
    echo "    <name>$name</name>" >> ${properties_file}
    echo "    <value>$value</value>" >> ${properties_file}
    echo "  </property>" >> ${properties_file}
    echo "</configuration>" >> ${properties_file}
}

# Download mysql connector to specified directory
wget_mysql_connector(){
    local cp_path=$1
    local file=mysql-connector-java-5.1.49.tar.gz
    local url=https://repo.huaweicloud.com/mysql/Downloads/Connector-J/mysql-connector-java-5.1.49.tar.gz
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    cp ${INSTALL_PATH}/${file:0:27}/${file:0:27}.jar $cp_path
    rm -rf ${INSTALL_PATH}/${file:0:27}
}

# Initial configuration
install_init(){
    echo "install init"
    # Set SSH to allow password login
    sed -i 's@^PasswordAuthentication no@PasswordAuthentication yes@g' /etc/ssh/sshd_config
    sed -i 's@^#PubkeyAuthentication yes@PubkeyAuthentication yes@g' /etc/ssh/sshd_config
    systemctl restart sshd.service

    # Install CentOS basic software
    yum install -y -q net-tools vim-enhanced sshpass expect wget

    # Configure the vagrant user to have root privileges
    sed -i "/## Same thing without a password/ivagrant   ALL=(ALL)     NOPASSWD:ALL" /etc/sudoers

    # Add ip address to hosts file
    sed -i '/^127.0.1.1/'d /etc/hosts
    echo "192.168.10.101  ${HOST_NAME}" >> /etc/hosts

    # Modify DNS
    sed -i "s@^nameserver.*@nameserver 114.114.114.114@" /etc/resolv.conf

    # Create an installation directory and change directory owner permissions
    mkdir /opt/module
    chown -R vagrant:vagrant /opt/
    complete_url=https://raw.githubusercontent.com/yiluohan1234/vagrant_hdp_single_node/main/complete_tool.sh
    bigstart_url=https://raw.githubusercontent.com/yiluohan1234/vagrant_hdp_single_node/main/bigstart
    # curl -o /vagrant/complete_tool.sh -O -L ${complete_url}
    # curl -o /vagrant/bigstart -O -L ${bigstart_url}
    wget -P /vagrant/ ${complete_url}
    wget -P /vagrant/ ${bigstart_url}
    
    [ -f /vagrant/bigstart ] && cp /vagrant/bigstart /usr/bin && chmod a+x /usr/bin/bigstart
    [ -f /vagrant/complete_tool.sh ] && cp /vagrant/complete_tool.sh /etc/profile.d
}

# install java
install_jdk()
{
    local app=java
    local url=${JAVA_URL}
    local file=${url##*/}
    if [ `yum list installed | grep java-${jdk_version}|wc -l` -gt 0 ];then
        yum -y remove java-${jdk_version}-openjdk*
        yum -y remove tzdata-java.noarch
    fi

    echo "install ${app}"
    # Install
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    mv ${INSTALL_PATH}/jdk1.8.0_201 ${INSTALL_PATH}/${app}
 	  if [ -d ${INSTALL_PATH}/${app} ]
    then
        # Add environment variables to /etc/profile
        echo "# jdk environment" >> /etc/profile
        echo "export JAVA_HOME=${INSTALL_PATH}/${app}" >> /etc/profile
        echo 'export JRE_HOME=${JAVA_HOME}/jre' >> /etc/profile
        echo 'export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib' >> /etc/profile
        echo 'export PATH=${JAVA_HOME}/bin:${JAVA_HOME}/sbin:$${JRE_HOME}/bin:$PATH' >> /etc/profile
        echo -e "\n" >> /etc/profile
        source /etc/profile
    fi
}

# Install hadoop
install_hadoop()
{
    local app=hadoop
    local url=${HADOOP_URL}
    local file=${url##*/}

    echo "install ${app}"
    # Install
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    mv ${INSTALL_PATH}/${file:0:12} ${INSTALL_PATH}/${app}

    if [ -d ${INSTALL_PATH}/${app} ]
    then
        # Configure hadoop-env.sh core-site.xml hdfs-site.xml yarn-site.xml mapred-site.xml slaves
        sed -i "s@^export JAVA_HOME=.*@export JAVA_HOME=${INSTALL_PATH}/java@" ${INSTALL_PATH}/${app}/etc/hadoop/hadoop-env.sh
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/core-site.xml "fs.defaultFS" "hdfs://${HOST_NAME}:9000"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/core-site.xml "hadoop.tmp.dir" "${INSTALL_PATH}/hadoop/hadoopdata"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/core-site.xml "hadoop.http.staticuser.user" "root"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/core-site.xml "hadoop.proxyuser.root.hosts" "*"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/core-site.xml "hadoop.proxyuser.root.groups" "*"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/core-site.xml "hadoop.proxyuser.root.users" "*"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/hdfs-site.xml "dfs.replication" "1"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/hdfs-site.xml "dfs.datanode.name.dir" "${INSTALL_PATH}/hadoop/hadoopdata/name"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/hdfs-site.xml "dfs.datanode.data.dir" "${INSTALL_PATH}/hadoop/hadoopdata/data"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/hdfs-site.xml "dfs.webhdfs.enabled" "true"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/hdfs-site.xml "dfs.permissions.enabled" "false"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/yarn-site.xml "yarn.nodemanager.aux-services" "mapreduce_shuffle"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/yarn-site.xml "yarn.resourcemanager.hostname" "${HOST_NAME}"
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/yarn-site.xml "yarn.nodemanager.aux-services.mapreduce.shuffle.class" "org.apache.hadoop.mapred.ShuffleHandler"
        cp ${INSTALL_PATH}/${app}/etc/hadoop/mapred-site.xml.template ${INSTALL_PATH}/${app}/etc/hadoop/mapred-site.xml
        set_property ${INSTALL_PATH}/${app}/etc/hadoop/mapred-site.xml "mapreduce.framework.name" "yarn"
        # slaves
        echo -e "${HOST_NAME}" > ${INSTALL_PATH}/${app}/etc/hadoop/slaves
        echo "export JAVA_HOME=${INSTALL_PATH}/java" >> ${INSTALL_PATH}/${app}/etc/hadoop/yarn-env.sh
        # Add environment variables
        setupEnv_app ${app} sbin
    fi
}

# Install mysql
install_mysql() {
    # Install mysql57
    curl -o /root/mysql57-community-release-el7-11.noarch.rpm -O -L http://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
    rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
    yum -y -q install /root/mysql57-community-release-el7-11.noarch.rpm
    yum -y -q install mysql-community-server

    # Start and set up to start automatically
    systemctl start mysqld.service
    systemctl enable mysqld.service

    # Change initial password
    # Obtain the temporary password during installation (this password is used when logging in for the first time)
    local PASSWORD=`grep 'temporary password' /var/log/mysqld.log|awk -F "root@localhost: " '{print $2}'`
    local USERNAME="root"
    local MYSQL_PASSWORD="123456"
    local PORT="3306"
    
    mysql -u${USERNAME} -p${PASSWORD} -e "set global validate_password_policy=0; \
        set global validate_password_length=4; \
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}'; \
        use mysql; \
        update user set host='%' where user='root'; \
        create user 'hive'@'%' IDENTIFIED BY 'hive'; \
        CREATE DATABASE hive; \
        GRANT ALL PRIVILEGES ON *.* TO 'hive'@'%' WITH GRANT OPTION; \
        flush privileges;" --connect-expired-password
    
    # Delete rpm and noarch
    yum -y remove mysql57-community-release-el7-11.noarch
    rm -rf /root/mysql57-community-release-el7-11.noarch.rpm

}

# Configure ssh password-free login
install_ssh() {
    local HOSTNAME_LIST=("${HOST_NAME}")
    local PASSWD_LIST=("vagrant")
    yum install -y -q expect
    if [ ! -f ~/.ssh/id_rsa ];then
        expect -c "
            spawn ssh-keygen
            expect {
                \"Enter file in which to save the*\" { send \"\r\"; exp_continue}
                \"Overwrite*\" { send \"n\r\" ; exp_continue}
                \"Enter passphrase*\" { send \"\r\"; exp_continue}
                \"Enter same passphrase again:\" { send \"\r\" ; exp_continue}
            }";
    fi
    
    length=${#HOSTNAME_LIST[@]}
    for ((i=0; i<$length; i++));do
        expect -c "
            set timeout 5;
            spawn ssh-copy-id -i ${HOSTNAME_LIST[$i]};
            expect {
                \"*assword\" { send \"${PASSWD_LIST[$i]}\r\";exp_continue}
                \"yes/no\" { send \"yes\r\"; exp_continue }
                eof {exit 0;}
            }";
        echo "========The hostname is: ${HOSTNAME_LIST[$i]}, and the password free login is completed ========"
    done
}

# Install hive
install_hive()
{
    local app=hive
    local url=${HIVE_URL}
    local file=${url##*/}

    echo "install ${app}"
    # Install
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    mv ${INSTALL_PATH}/${file:0:21} ${INSTALL_PATH}/${app}
    if [ -d ${INSTALL_PATH}/${app} ]
    then
        # Configure hive-site.xml
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "javax.jdo.option.ConnectionURL" "jdbc:mysql://${HOST_NAME}:3306/hive?createDatabaseIfNotExist=true&amp;useSSL=false" true
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "javax.jdo.option.ConnectionDriverName" "com.mysql.jdbc.Driver"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "javax.jdo.option.ConnectionUserName" "hive"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "javax.jdo.option.ConnectionPassword" "hive"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.metastore.schema.verification" "false"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "datanucleus.schema.autoCreateALL" "true"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.cli.print.current.db" "true"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.cli.print.header" "true"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.metastore.local" "false"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.server2.thrift.port" "10000"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.server2.thrift.bind.host" "${HOST_NAME}"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.metastore.uris" "thrift://${HOST_NAME}:9083"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.exec.mode.local.auto" "true"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.strict.checks.cartesian.product" "false"
        set_property ${INSTALL_PATH}/${app}/conf/hive-site.xml "hive.mapred.mode" "nonstrict"

        wget_mysql_connector ${INSTALL_PATH}/${app}/lib
        # Add environment variables
        setupEnv_app ${app}
    fi
}

# Install scala
install_scala()
{
    local app=scala
    local url=${SCALA_URL}
    local file=${url##*/}

    echo "install ${app}"
    # Install
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    mv ${INSTALL_PATH}/${file:0:13} ${INSTALL_PATH}/${app}
    if [ -d ${INSTALL_PATH}/${app} ]
    then
        # Add environment variables
        setupEnv_app ${app}
    fi
}

# Install Spark
install_spark()
{
    local app=spark
    local url=${SPARK_URL}
    local file=${url##*/}

    echo "install ${app}"
    # Install
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    mv ${INSTALL_PATH}/${file:0:25} ${INSTALL_PATH}/${app}
    if [ -d ${INSTALL_PATH}/${app} ]
    then
        # Configure spark-env.sh, spark-defaults.conf, slaves
        cp ${INSTALL_PATH}/${app}/conf/spark-env.sh.template ${INSTALL_PATH}/${app}/conf/spark-env.sh
        echo "export SPARK_MASTER_IP=${HOST_NAME}" >> ${INSTALL_PATH}/${app}/conf/spark-env.sh
        echo "export SCALA_HOME=${INSTALL_PATH}/scala" >> ${INSTALL_PATH}/${app}/conf/spark-env.sh
        echo "export SPARK_WORKER_MEMORY=1g" >> ${INSTALL_PATH}/${app}/conf/spark-env.sh
        echo "export JAVA_HOME=${INSTALL_PATH}/java" >> ${INSTALL_PATH}/${app}/conf/spark-env.sh
        echo "export HADOOP_HOME=${INSTALL_PATH}/hadoop" >> ${INSTALL_PATH}/${app}/conf/spark-env.sh
        echo 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop' >> ${INSTALL_PATH}/${app}/conf/spark-env.sh
        echo 'export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop' >> ${INSTALL_PATH}/${app}/conf/spark-env.sh
        echo 'export SPARK_HISTORY_OPTS="-Dspark.history.ui.port=18080 -Dspark.history.retainedApplications=3 -Dspark.history.fs.logDirectory=hdfs://'${HOST_NAME}':9000/spark-log"' >> ${INSTALL_PATH}/${app}/conf/spark-env.sh

        cp ${INSTALL_PATH}/${app}/conf/spark-defaults.conf.template ${INSTALL_PATH}/${app}/conf/spark-defaults.conf
        echo "spark.master                     yarn" >> ${INSTALL_PATH}/${app}/conf/spark-defaults.conf
        echo "spark.eventLog.enabled           true" >> ${INSTALL_PATH}/${app}/conf/spark-defaults.conf
        echo "spark.eventLog.dir               hdfs://${HOST_NAME}:9000/spark-log" >> ${INSTALL_PATH}/${app}/conf/spark-defaults.conf
        echo "spark.eventLog.compress          true" >> ${INSTALL_PATH}/${app}/conf/spark-defaults.conf
        echo "spark.serializer                 org.apache.spark.serializer.KryoSerializer" >> ${INSTALL_PATH}/${app}/conf/spark-defaults.conf
        echo "spark.executor.memory            1g" >> ${INSTALL_PATH}/${app}/conf/spark-defaults.conf
        echo "spark.driver.memory              1g" >> ${INSTALL_PATH}/${app}/conf/spark-defaults.conf
        echo 'spark.executor.extraJavaOptions  -XX:+PrintGCDetails -Dkey=value -Dnumbers="one two three"' >> ${INSTALL_PATH}/${app}/conf/spark-defaults.conf

        cp ${INSTALL_PATH}/${app}/conf/slaves.template ${INSTALL_PATH}/${app}/conf/slaves
        echo '${HOST_NAME}' > ${INSTALL_PATH}/${app}/conf/slaves
        wget_mysql_connector ${INSTALL_PATH}/${app}/jars
        # Add environment variables
        setupEnv_app ${app}
    fi
}

# Install Zookeeper
install_zk()
{
    local app=zookeeper
    local url=${ZOOKEEPER_URL}
    local file=${url##*/}

    echo "install ${app}"
    # Install
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    mv ${INSTALL_PATH}/${file:0:26} ${INSTALL_PATH}/${app}
    if [ -d ${INSTALL_PATH}/${app} ]
    then
        # Configure zoo.cfg
        cp  ${INSTALL_PATH}/${app}/conf/zoo_sample.cfg ${INSTALL_PATH}/${app}/conf/zoo.cfg
        sed -i "s@^dataDir=.*@dataDir=${INSTALL_PATH}/${app}/data@" ${INSTALL_PATH}/${app}/conf/zoo.cfg
        mkdir -p ${INSTALL_PATH}/${app}/data
        echo "1" >> ${INSTALL_PATH}/${app}/data/myid
        # Add environment variables
        setupEnv_app ${app}
    fi
}

# Install Hbase
install_hbase()
{
    local app=hbase
    local url=${HBASE_URL}
    local file=${url##*/}

    echo "install ${app}"
    # Install
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    mv ${INSTALL_PATH}/${file:0:11} ${INSTALL_PATH}/${app}
    if [ -d ${INSTALL_PATH}/${app} ]
    then
        # Configure
        sed -i "s@^# export HBASE_MANAGES_ZK=.*@export HBASE_MANAGES_ZK=false@" ${INSTALL_PATH}/${app}/conf/hbase-env.sh
        sed -i "s@^# export JAVA_HOME=.*@export JAVA_HOME=${INSTALL_PATH}/java@" ${INSTALL_PATH}/${app}/conf/hbase-env.sh
        set_property ${INSTALL_PATH}/${app}/conf/hbase-site.xml "hbase.rootdir" "hdfs://${HOST_NAME}:9000/hbase"
        set_property ${INSTALL_PATH}/${app}/conf/hbase-site.xml "hbase.zookeeper.quorum" "${HOST_NAME}"
        set_property ${INSTALL_PATH}/${app}/conf/hbase-site.xml "hbase.cluster.distributed" "true"
        set_property ${INSTALL_PATH}/${app}/conf/hbase-site.xml "phoenix.schema.isNamespaceMappingEnabled" "true"
        set_property ${INSTALL_PATH}/${app}/conf/hbase-site.xml "phoenix.schema.mapSystemTablesToNamespace" "true"
        echo -e "${HOST_NAME}" > ${INSTALL_PATH}/${app}/conf/regionservers
        # Add environment variables
        setupEnv_app ${app}
    fi
}

# Install Phoenix
install_phoenix()
{
    local app=phoenix
    local url=${PHOENIX_URL}
    local file=${url##*/}

    echo "install ${app}"
    # Install
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    mv ${INSTALL_PATH}/${file:0:35} ${INSTALL_PATH}/${app}
    if [ -d ${INSTALL_PATH}/${app} ]
    then
        # Configure
        cp ${INSTALL_PATH}/${app}/phoenix-4.14.0-HBase-1.4-server.jar ${INSTALL_PATH}/hbase/lib
        cp ${INSTALL_PATH}/hbase/conf/hbase-site.xml ${INSTALL_PATH}/phoenix/bin
        # Add environment variables
        setupEnv_app ${app}
    fi
}

# Install Kafka
install_kafka()
{
    local app=kafka
    local url=${KAFKA_URL}
    local file=${url##*/}

    echo "install ${app}"
    # Install
    if [ ! -f ${DEFAULT_DOWNLOAD_DIR}/${file} ]
    then
        curl -o ${DEFAULT_DOWNLOAD_DIR}/${file} -O -L ${url}
    fi
    tar -zxf ${DEFAULT_DOWNLOAD_DIR}/${file} -C ${INSTALL_PATH}
    mv ${INSTALL_PATH}/${file:0:16} ${INSTALL_PATH}/${app}
    if [ -d ${INSTALL_PATH}/${app} ]
    then
        # Configure
        value="listeners=PLAINTEXT://${HOST_NAME}:9092"
        sed -i 's@^#listeners=.*@listeners='${value}'@' ${INSTALL_PATH}/${app}/config/server.properties
        sed -i 's@^#advertised.listeners=.*@advertised.listeners='${value}'@' ${INSTALL_PATH}/${app}/config/server.properties
        sed -i "s@^zookeeper.connect=.*@zookeeper.connect=${HOST_NAME}:2181/kafka@" ${INSTALL_PATH}/${app}/config/server.properties

        # Add environment variables
        setupEnv_app ${app}
    fi
}

main(){
  install_init
  install_jdk
  install_hadoop
  install_mysql
  install_ssh
  install_hive
  install_scala
  install_spark
  install_zk
  install_hbase
  install_phoenix
  install_kafka
}

main


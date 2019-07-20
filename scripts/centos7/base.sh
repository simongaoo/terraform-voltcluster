#!/bin/bash

# 安装一些必备工具
yum install -y unzip tmux bzip2

cd /usr/src
wget https://basin.oss-ap-northeast-1.aliyuncs.com/deposit/Python-2.7.15.tgz
tar xzf Python-2.7.15.tgz
cd Python-2.7.15
./configure --enable-optimizations
make altinstall

#yum -y install pip
yum -y install expect
yum -y install git
pip install --upgrade pip
 
# 安装Chrony并配置，保证集群节点间时间一致
yum install chrony -y
mkdir -p /etc/chrony
cat > /etc/chrony/chrony.conf << EOF
server ntp1.aliyun.com iburst minpoll 4 maxpoll 10
server ntp2.aliyun.com iburst minpoll 4 maxpoll 10
server ntp3.aliyun.com iburst minpoll 4 maxpoll 10
stratumweight 0
driftfile /var/lib/chrony/drift
rtcsync
makestep 10 3
allow 192.168.1.0/24
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
keyfile /etc/chrony/chrony.keys
commandkey 1
generatecommandkey
noclientlog
logchange 0.5
logdir /var/log/chrony
EOF
 
#启动Chrony
chronyd -f /etc/chrony/chrony.conf
 
# 按个人喜好，如果已经预装了OpenJDK就移除
yum remove --assumeyes *openjdk*
 
# 安装JDK并配置环境变量
wget https://basin.oss-ap-northeast-1.aliyuncs.com/deposit/jdk-8u151-linux-x64.rpm
rpm -Uvh jdk-8u151-linux-x64.rpm
echo 'JAVA_HOME=/usr/java/jdk1.8.0_151' >> /etc/profile
echo 'PATH=$PATH:$JAVA_HOME/bin' >> /etc/profile

wget https://basin.oss-ap-northeast-1.aliyuncs.com/deposit/gradle-5.1-bin.zip -P /tmp
unzip -d /opt/gradle /tmp/gradle-5.1-bin.zip
ln -s /opt/gradle/gradle-5.1/bin/gradle /usr/bin/gradle

setenforce 0 || /bin/true
iptables -F

#yum install -y cloudera-manager-daemons cloudera-manager-agent
#sed -i 's/server_host=localhost/server_host='"$HD_SERVER_PRIVATE_IP"'/' /etc/cloudera-scm-agent/config.ini
#service cloudera-scm-agent start

#############
# Performance
#############

# Swappiness to 1
sysctl vm.swappiness=1  # Sets at runtime
bash -c "echo 'vm.swappiness = 1' >> /etc/sysctl.conf"  # Persists after reboot

# Disable Transparent Huge Page Compaction
bash -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"   # At runtime
bash -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"  # At runtime
bash -c "echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.d/rc.local"   # Persists after reboot
bash -c "echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.d/rc.local"  # Persists after reboot
chmod +x /etc/rc.d/rc.local  # Activate script

echo y | ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa > /dev/null


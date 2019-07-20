#!/bin/bash

#VoltDB企业版需要的License文件，可以在线申请。
echo -e '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <license>
                <permit version="1" scheme="0">
                <type>Enterprise Edition</type>
                <issuer>
                <company>VoltDB</company>
                <email>support@voltdb.com</email>
                <url>http://voltdb.com/</url>
                </issuer>
                <issuedate>2019-01-09</issuedate>
                <licensee>VoltDB Field Engineering</licensee>
                <expiration>2020-01-09</expiration>
                <hostcount max="200"/>
                <features trial="false">
                <wanreplication>true</wanreplication>
                <dractiveactive>true</dractiveactive>
                </features>
                </permit>
                <signature>
                302C02147F6B637FC0267E4F46F4E4E704A41FB8FD44AD
                4802146DD24AB72C167F63E069894C460F9028AE3559FF
                </signature>
                </license>' > ~/license.xml
            
echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
              <deployment>
                <cluster sitesperhost=\"8\" kfactor=\"1\" />
                <commandlog synchronous=\"false\" enabled=\"true\" logsize=\"10000\"/>
                <snapshot enabled=\"false\"/>
                <httpd enabled=\"true\">
                    <jsonapi enabled=\"true\" />
                </httpd>
                <systemsettings>
                <temptables maxsize=\"1024\"/>
                <query timeout=\"30000\"/>
                </systemsettings>
                <export>
                    <configuration target=\"hadoop\" enabled=\"true\" type=\"http\">
                        <property name=\"endpoint\">
                            http://$1:50070/webhdfs/v1/%t/data%p-%g.%d.csv
                        </property>
                        <property name=\"batch.mode\">true</property>
                        <property name=\"period\">2</property>
                    </configuration>
                    <configuration target=\"mysql\" enabled=\"true\" type=\"jdbc\">
                        <property name=\"jdbcurl\">
                            jdbc:mysql://$1:3306/bigdb
                        </property>
                        <property name=\"jdbcuser\">root</property>
                        <property name=\"jdbcpassword\">Mypass#234</property>
                        <property name=\"createtable\">true</property>
                        <property name=\"ignoregenerations\">true</property>
                        <property name=\"lowercase\">true</property>
                    </configuration>
                </export>
              </deployment>" > ~/deployment.xml

curl -L -o /opt/voltdb-ent-9.0.tar.gz -O https://basin.oss-ap-northeast-1.aliyuncs.com/deposit/voltdb-ent-9.0.tar.gz
tar -xzvf /opt/voltdb-ent-9.0.tar.gz -C /opt/
mv /opt/voltdb-ent-9.0 /opt/voltdb

cat >> ~/.bashrc << \EOF
export VOLT=/opt/voltdb
export VOLTDB_HEAPMAX="2048"
export PATH=$PATH:$VOLT/bin
EOF

cat >> /etc/profile << \EOF
export VOLT=/opt/voltdb
export VOLTDB_HEAPMAX="2048"
export PATH=$PATH:$VOLT/bin
EOF


mv -f ~/license.xml /opt/voltdb/voltdb/
/opt/voltdb/bin/voltdb init -f -C ~/deployment.xml --dir=/opt --force >> ~/voltdb_init.log
export VOLTDB_HEAPMAX="2048"
pip install -r /opt/voltdb/lib/python/voltsql/requirements.txt

wget https://basin.oss-ap-northeast-1.aliyuncs.com/deposit/mysql-connector-java-5.1.24-bin.jar.zip -P /opt/voltdb/lib/extension
unzip -o /opt/voltdb/lib/extension/mysql-connector-java-5.1.24-bin.jar.zip -d /opt/voltdb/lib/extension/


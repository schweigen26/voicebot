#!/bin/bash

#Global
inst_path=/usr/local
local_path=`pwd`
lic_path=$local_path/License
dependence_path=$local_path/Dependence
internal_ip=$(ip a|grep -Ev 'virbr|vmnet|docker'|grep -w 'inet'|grep 'global'|sed 's/^.*inet //g'|sed 's/\/[0-9][0-9].*$//g')
netcard=$(ip a|grep $internal_ip|awk -F " " '{print $8}')
external_ip=
password=Pachira@123



function status()
{
VCG_status=`ps -ef|grep -v grep|grep apache-tomcat-9.0.6_vcg|wc -l`
		
PSTT_status=`ps -ef|grep -v grep|grep pstt|grep 5562|wc -l`
		
PTTS_status=`ps -ef|grep -v grep|grep apache-tomcat-9.0.6_tts|wc -l`
		
MRCP_status=`ps -ef|grep -v grep|grep unimrcp|wc -l`
		
DIALER_status=`ps -ef|grep -v grep|grep dialer|wc -l`
		
PIOD_status=`ps -ef|grep -v grep|grep piod|wc -l`
		
PNLP_status=`ps -ef|grep -v grep|grep pnlp|wc -l`
		
if [[ $PNLP_status != 6 ]]
then
	PNLP_status=0
fi

declare -A stat

stat[VCG]=$VCG_status

stat[PSTT]=$PSTT_status

stat[PTTS]=$PTTS_status

stat[MRCP]=$MRCP_status

stat[DIALER]=$DIALER_status

stat[PIOD]=$PIOD_status

stat[PNLP]=$PNLP_status

for i in ${!stat[*]}
do
	if [[ ${stat[$i]} == 0 ]]
	then
			stat[$i]="not running"
	else
			stat[$i]="running"
	fi
	
	echo "$i is ${stat[$i]}"
done
}


function start()
{
cd $inst_path/apache-tomcat-9.0.6_vcg/bin/
./startup.sh

cd $inst_path/pstt
pstt_lic=license.data

if [ ! -f "$lic_path/$pstt_lic" ]
	then
		echo "ERROR: PSTT授权不存在！"
	else
		if [ ! -f "$inst_path/pstt/etc/$pstt_lic" ]
		then
			cp $lic_path/$pstt_lic $inst_path/pstt/etc
		fi
		./startup.sh start
fi

cd $lic_path && ptts_lic=`basename *.xml`
cd $inst_path/apache-tomcat-9.0.6_tts/bin/

if [ ! -f "$lic_path/$ptts_lic" ]
    then
        echo "ERROR: PTTS授权不存在！"
	else
#重复安装
#		if [ ! -f "$inst_path/pstt/etc/$pstt_lic" ]
#		then
	./ptts.sh inst-lic $lic_path/$ptts_lic
	./startup.sh
fi

mrcp_lic=LICENSE

if [ ! -f "$lic_path/$mrcp_lic" ]
	then
		echo "ERROR: MRCP授权不存在！"
	else
		if [ ! -f "$inst_path/unimrcp/conf/$mrcp_lic" ]
		then
			cp $lic_path/$mrcp_lic $inst_path/unimrcp/conf
		fi
		systemctl start unimrcpserver
fi

dialer_lic=LICENSE

if [ ! -f "$lic_path/$dialer_lic" ]
	then
		echo "ERROR: DIALER授权不存在！"
	else
		if [ ! -f "$inst_path/dialer/$dialer_lic" ]
		then
			cp $lic_path/$dialer_lic $inst_path/dialer
		fi
		systemctl start dialer
fi

systemctl start piod
systemctl start NLPManagement
systemctl start NLUService DMService ContentService ClassifyService NLPCaddy
}


function stop()
{
cd $inst_path/apache-tomcat-9.0.6_vcg/bin/
./shutdown.sh

cd $inst_path/pstt
./startup.sh stop

cd $inst_path/apache-tomcat-9.0.6_tts/bin/
./shutdown.sh

systemctl stop unimrcpserver
systemctl stop dialer
systemctl stop piod
systemctl stop NLPManagement
systemctl stop NLUService DMService ContentService ClassifyService NLPCaddy
}


function check_path()
{
service=(apache-tomcat-9.0.6_vcg apache-tomcat-9.0.6_tts pstt unimrcp dialer piod tts redis pnlp)

for i in ${service[*]}
do
	if [ -d "$inst_path/$i" ]
    then
        echo "ERROR: 请将原服务$i停止并进行备份后再执行安装！"
    fi
done
}


function check_database()
{
mysqldata_path=`mysql -uroot -p$password -e "show variables like 'datadir';"|grep datadir|awk '{print $2}'`

database=(voice piod pnlp)

for i in ${database[*]}
do
	if [ -d "$mysqldata_path/$i" ]
	then
		echo "ERROR: 数据库$i已存在，请进行备份后再执行安装！"
	fi
done
}


function deploy()
{
tar -xzvf $local_path/Main/$1 -C $inst_path
}


function changeIP()
{
sed -i "s/192.168.0.147/$internal_ip/g" `grep -rl "192.168.0.147" $inst_path/$1`

sed -i "s/114.116.229.239/$external_ip/g" `grep -rl "114.116.229.239" $inst_path/$1`
}


function changePASW()
{
sed -i "s/Pachir@,123./$password/g" `grep -rl "Pachir@,123." $inst_path/$1`
}


function inst_VCG()
{
deploy apache-tomcat-9.0.6_vcg.tar.gz && changeIP apache-tomcat-9.0.6_vcg && changePASW apache-tomcat-9.0.6_vcg

mysql -uroot -p$password -e "source $inst_path/apache-tomcat-9.0.6_vcg/webapps/QianYuSrv/WEB-INF/classes/sql/oamptables_linux.sql"

mysql -uroot -p$password -e "source $inst_path/apache-tomcat-9.0.6_vcg/webapps/QianYuSrv/WEB-INF/classes/sql/qianyutables_linux.sql"
#指定JDK
#vim /usr/local/apache-tomcat-9.0.6_vcg/bin/catalina.sh
#JAVA_HOME=/usr/java/jdk1.8.0_131
#export JRE_HOME=$JAVA_HOME/jre
#export CLASSPATH=$JAVA_HOME/lib:$JRE_HOME/lib:$CLASSPATH
#export PATH=$JAVA_HOME/bin:$JAR_HOME/bin:$PATH

deploy pstt.tar.gz
#绑定模型与配置(已兼容0723)

}
 
 
function inst_TTS()
{
deploy apache-tomcat-9.0.6_tts.tar.gz && changeIP apache-tomcat-9.0.6_tts && changePASW apache-tomcat-9.0.6_tts

mysql -uroot -p$password -e "create database voice default character set utf8mb4 collate utf8mb4_general_ci;"

mysql -uroot -p$password voice -e "CREATE TABLE t_tts_file (
id varchar(64) NOT NULL,
voice_name varchar(20) NOT NULL,
sample_rate int(11) NOT NULL,
volume decimal(5,2) NOT NULL,
speed decimal(5,2) NOT NULL,
pitch decimal(5,2) NOT NULL,
tag_mode int(2) NOT NULL,
eng_mode int(2) NOT NULL,
text varchar(1024) NOT NULL,
file_path varchar(255) NOT NULL,
create_time datetime NOT NULL,
visit_time datetime NOT NULL,
text_index varchar(35) NOT NULL,
PRIMARY KEY (id),
KEY IDX_TEXTINDEX (text_index) USING BTREE,
KEY IDX_VOICENAME (voice_name) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
#指定JDK
#vim /usr/local/apache-tomcat-9.0.6_tts/bin/catalina.sh
#JAVA_HOME=/usr/java/jdk1.8.0_131
#export JRE_HOME=$JAVA_HOME/jre
#export CLASSPATH=$JAVA_HOME/lib:$JRE_HOME/lib:$CLASSPATH
#export PATH=$JAVA_HOME/bin:$JAR_HOME/bin:$PATH

#convmv -f gbk -t utf-8 -r --notest $inst_path/apache-tomcat-9.0.6_tts
}


function inst_SRV()
{
deploy services.tar.gz
\mv $inst_path/services/* /usr/lib/systemd/system
systemctl daemon-reload
}


function inst_MRCP()
{
deploy unimrcp.tar.gz && changeIP unimrcp

sed -i "s/eth0/$netcard/g" $inst_path/unimrcp/conf/unimrcpclient.xml

sed -i "s/eth0/$netcard/g" $inst_path/unimrcp/conf/unimrcpserver.xml

cd $inst_path/unimrcp/lib
#libasrclient.so -> libasrclient.so.0.5.0
#libasrclient.so.0 -> libasrclient.so.0.5.0
#libunimrcpclient.so -> libunimrcpclient.so.0.5.0
#libunimrcpclient.so.0 -> libunimrcpclient.so.0.5.0
#libunimrcpserver.so -> libunimrcpserver.so.0.5.0
#libunimrcpserver.so.0 -> libunimrcpserver.so.0.5.0
ln -s libasrclient.so.0.5.0 libasrclient.so.0

ln -s libasrclient.so.0.5.0 libasrclient.so

ln -s libunimrcpclient.so.0.5.0 libunimrcpclient.so.0

ln -s libunimrcpclient.so.0.5.0 libunimrcpclient.so

ln -s libunimrcpserver.so.0.5.0 libunimrcpserver.so.0

ln -s libunimrcpserver.so.0.5.0 libunimrcpserver.so

cd $inst_path/unimrcp/plugin

ln -s demorecog.so.0.5.0 demorecog.so

ln -s demorecog.so.0.5.0 demorecog.so.0

ln -s demosynth.so.0.5.0 demosynth.so

ln -s demosynth.so.0.5.0 demosynth.so.0

ln -s demoverifier.so.0.5.0 demoverifier.so

ln -s demoverifier.so.0.5.0 demoverifier.so.0

ln -s mrcprecorder.so.0.5.0 mrcprecorder.so

ln -s mrcprecorder.so.0.5.0 mrcprecorder.so.0
}


function inst_DIALER()
{
deploy dialer.tar.gz

cp -r $dependence_path/fs $inst_path/dialer

changeIP dialer

\cp $inst_path/dialer/fs/hl.xml /etc/freeswitch/sip_profiles/external/
\cp $inst_path/dialer/fs/unimrcp.xml /etc/freeswitch/mrcp_profiles/
\cp $inst_path/dialer/fs/public.xml /etc/freeswitch/dialplan/
\cp $inst_path/dialer/fs/modules.conf.xml /etc/freeswitch/autoload_configs/
\cp $inst_path/dialer/fs/unimrcp.conf.xml /etc/freeswitch/autoload_configs/
\cp $inst_path/dialer/mod_unimrcp.so /usr/lib64/freeswitch/mod/
\cp $inst_path/dialer/yesno.gram /usr/share/freeswitch/grammar/
}


function inst_PIOD()
{
deploy piod.tar.gz && changeIP piod && changePASW piod

mysql -uroot -p$password -e "create database piod character set utf8;"

cd $inst_path/piod && ./PIOD.sh init_db	
}


function inst_REDIS()
{
deploy redis.tar.gz && changeIP redis

#rm -rf redis-sentinel
#ln -s redis-server redis-sentinel

$inst_path/redis/bin/redis-server $inst_path/redis/conf/cache.conf
$inst_path/redis/bin/redis-server $inst_path/redis/conf/lock.conf
$inst_path/redis/bin/redis-sentinel $inst_path/redis/conf/sentinel.conf
}


function inst_PNLP()
{
inst_REDIS

deploy pnlp.tar.gz && changeIP pnlp && changePASW pnlp

mysql -uroot -p$password -e "create database pnlp default character set utf8 collate utf8_general_ci;"
 
mysql -uroot -p$password pnlp < $inst_path/pnlp/pnlp-v4.3.8_2.3-init.sql
}


#Main
function install()
{
if [ ! -n "$internal_ip" ]
then
	echo "ip获取失败，请手动输入！"
	exit
else
	if [ ! -n "$external_ip" ]
	then
		external_ip=$internal_ip
	fi
fi
echo "checking environment..."
gcc1=`whereis gcc|wc -l`
gcc2=`whereis g++|wc -l`
if [[ $gcc1 -eq 1 && $gcc2 -eq 1 ]]
then
	echo "check gcc ...... yes"
else
	tar -xzvf $dependence_path/gcc.tar.gz -C $dependence_path
	cd $dependence_path/gcc && rpm -ivh * --force
fi
if [ -d /opt/intel/mkl ]
then
	echo "check mkl ...... yes"
else
	tar -xzvf $dependence_path/l_mkl_2020.0.166.tgz -C $dependence_path
	cd $dependence_path/l_mkl_2020.0.166 && sh install.sh
fi
if [ -d /usr/java/jdk1.8.0_131 ]
then
	echo "check jdk ...... yes"
else
	echo "请确保jdk已正确安装！"
	exit
fi
mysql=`ps -ef|grep mysql|grep -v grep|wc -l`
if [[ $mysql -eq 0 ]]
then
	echo "请确保mysql已正确安装并启动！"
	exit
else
	echo "check mysql ...... yes"
fi
#redis=`ps -ef|grep redis|grep -v grep|wc -l`
#if [[ $redis -eq 0 ]]
#then
#	inst_REDIS
#else
#	echo "check redis ...... yes"
#fi
freeswitch=`ps -ef|grep freeswitch|grep -v grep|wc -l`
if [[ $freeswitch -eq 0 ]]
then
	echo "请确保freeswich已正确安装并启动！"
	exit
else
	echo "check freeswitch ...... yes"
fi
#检查安装
if [ ! $(check_path) ] 2> /dev/null
then
    if [ ! $(check_database) ] 2> /dev/null
	then
		inst_VCG && inst_TTS && inst_SRV && inst_MRCP && inst_DIALER && inst_PIOD && inst_PNLP
	else
        check_database
		exit
	fi
else
        check_path
		exit
fi
}


#choice
case $1 in
install)
	install
	;;
status)
	status
	;;
start)
	start
	;;
stop)
	stop
	;;
*)
	echo "$0 [install|start|status]"
	;;
esac



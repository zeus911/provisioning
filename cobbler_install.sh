#此cobbler 需要管理的网段
DHCP_RANGE=172.16.1.10,172.28.234.250

#默认root密码 默认为 test
#rootpassword=`openssl passwd -1 -salt 'NIYw43' 'test'`
ROOTPASSWORD='$6$w40ZiviI89ucL5Oo$JkcXr9jQ3Tu5HBZKCjFV5ndsN8ha0af9klY3qlSAL1EEmQ9rndAdS3/twgkhkFCjYD6O0/tw2cB17PjRJz7QQ/'

#cobbler的域名
COBBLER_DOMAIN=cobbler.meizu.mz

#cobbler 的 ip 一般为本机ip
Ipaddr=`/sbin/ifconfig |grep -A2 "eth0" |awk -F':' '{if($2 ~ /^[0-9][0-9][0-9]\./)print $2}' |cut -d" " -f 1`
SERVER=$Ipaddr

yum -y install cman tftp-server cobbler cobbler-web pykickstart dnsmasq ansible

iptables -F

echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/sysctl.conf

chkconfig httpd on 
chkconfig cobblerd on
chkconfig dnsmasq on

sed -i '/disable/c\\tdisable\t\t\t= no' /etc/xinetd.d/tftp
sed -i -e 's/\=\ yes/\=\ no/g' /etc/xinetd.d/rsync 
service xinetd restart

cobbler get-loaders


#移动目录
mv /var/www/cobbler /data/

sed -i 's|/var/www/html|/data/cobbler|g' /etc/httpd/conf/httpd.conf 
sed -i 's|/var/www/cobbler|/data/cobbler|g' /etc/httpd/conf.d/cobbler.conf


sed -i 's/authn_denyall/authn_configfile/g' /etc/cobbler/modules.conf

#修改cobbler web登录密码
#htdigest /etc/cobbler/users.digest "Cobbler" cobbler

#修改 dnsmasq.template
sed -i 's/dhcp-range=192.168.1.5,192.168.1.200/dhcp-range='$DHCP_RANGE'/g' /etc/cobbler/dnsmasq.template


#修改moddules.conf
sed -i 's/#module = manage_bind/module = manage_dnsmasq/g' /etc/cobbler/modules.conf
sed -i 's/#module = manage_isc/module = manage_dnsmasq/g' /etc/cobbler/modules.conf


sed -i 's/^[[:space:]]\+/ /' /etc/cobbler/settings
sed -i 's/allow_dynamic_settings: 0/allow_dynamic_settings: 1/g' /etc/cobbler/settings

/etc/init.d/cobblerd restart
/etc/init.d/httpd restart

cobbler setting edit --name=server --value=$SERVER

cobbler setting edit --name=pxe_just_once --value=1

cobbler setting edit --name=next_server --value=$SERVER

cobbler setting edit --name=manage_rsync --value=1
cobbler setting edit --name=manage_dhcp --value=1
cobbler setting edit --name=manage_dns --value=1
cobbler setting edit --name=anamon_enabled --value=1

cobbler setting edit --name=default_virt_bridge --value=br0
cobbler setting edit --name=default_virt_file_size --value=200
cobbler setting edit --name=default_virt_disk_driver --value=raw
cobbler setting edit --name=default_virt_type --value=kvm
cobbler setting edit --name=default_virt_ram --value=4096

cobbler setting edit --name=default_name_servers --value=[114.114.114.114]
cobbler setting edit --name=scm_track_enabled --value=1

cobbler setting edit --name=default_kickstart --value=/var/lib/cobbler/kickstarts/base.ks

cobbler setting edit --name=webdir --value=/data/cobbler

sed -i 's|$1$mF86/UHC$WvcIcX2t6crBz2onWxyac.|'$ROOTPASSWORD'|' /etc/cobbler/settings


/etc/init.d/cobblerd restart

cobbler repo add --name=epel6-x86_64 --mirror=http://mirrors.ustc.edu.cn/epel/6/x86_64/ --arch=x86_64 --breed=yum
cobbler repo add --name=epel6-x86_64-testing --mirror=http://mirrors.ustc.edu.cn/epel/testing/6/x86_64/  --arch=x86_64 --breed=yum
cobbler repo add --name=centos6-updates --mirror=http://mirrors.ustc.edu.cn/centos/6/updates/x86_64/ --arch=x86_64 --breed=yum
cobbler repo add --name=cloudera --mirror=http://archive-primary.cloudera.com/cdh5/redhat/6/x86_64/cdh/5/ --arch=x86_64 --breed=yum
cobbler repo add --name=percona --mirror=http://repo.percona.com/release/centos/latest/RPMS/x86_64/ --arch=x86_64 --breed=yum
cobbler repo add --name=mesosphere --mirror=http://repos.mesosphere.io/el/6/x86_64 --arch=x86_64 --breed=yum

#导入iso
mkdir -p /data/iso
wget http://mirrors.163.com/centos/6.7/isos/x86_64/CentOS-6.7-x86_64-bin-DVD1.iso -P /data/iso/
mount -t auto -o loop /data/iso/CentOS-6.7-x86_64-bin-DVD1.iso /mnt
cobbler import --path=/mnt --name=CentOS6.7 --arch=x86_64
umount /mnt
wget http://mirrors.163.com/centos/6.7/isos/x86_64/CentOS-6.7-x86_64-bin-DVD2.iso -P /data/iso/
mount -t auto -o loop /data/iso/CentOS-6.7-x86_64-bin-DVD2.iso /mnt
cp -rf /mnt/Packages/ /data/cobbler/ks_mirror/CentOS6.7-x86_64/

#添加系统ks类型
cobbler profile add --name=base --kickstart=/var/lib/cobbler/kickstarts/base.ks --distro=images-x86_64 --repos="centos6-updates cloudera epel6-x86_64 epel6-x86_64-testing mesosphere percona" 
cobbler profile add --name=mysql --kickstart=/var/lib/cobbler/kickstarts/mysql.ks --distro=images-x86_64 --repos="centos6-updates cloudera epel6-x86_64 epel6-x86_64-testing mesosphere percona" 
cobbler profile add --name=lvs --kickstart=/var/lib/cobbler/kickstarts/lvs.ks --distro=images-x86_64 --repos="centos6-updates cloudera epel6-x86_64 epel6-x86_64-testing mesosphere percona"
#docker
cobbler profile add --name=docker --ksmeta='host_type=docker' --kickstart=/var/lib/cobbler/kickstarts/base.ks --distro=images-x86_64 --repos="centos6-updates cloudera epel6-x86_64 epel6-x86_64-testing mesosphere percona" 
#kvm
cobbler profile add --name=kvm --ksmeta='host_type=kvm' --kickstart=/var/lib/cobbler/kickstarts/base.ks --distro=images-x86_64 --repos="centos6-updates cloudera epel6-x86_64 epel6-x86_64-testing mesosphere percona" 
#同步配置
cobbler sync
#同步仓库
#cobbler reposync

/etc/init.d/httpd restart
/etc/init.d/cobblerd restart
/etc/init.d/dnsmasq restart

#添加需要安装系统的节点 和 配置eth0 eth1 . cobbler会把 dns-name和ip写入DNS记录中，用于DNS解析
#bound
#cobbler system add --name=192.168.98.136 --profile=centos6.6 --hostname=test136 --interface=bond0 --interface-type=bond --bonding-opts="mode=active-backup miimon=100" --ip-address=192.168.98.136 --subnet=255.255.255.0 --gateway=192.168.98.128 --static=1 --static-routes="192.168.1.0/16:192.168.1.1 172.16.0.0/16:172.16.0.1"
#cobbler system edit --name=192.168.98.136 --interface=eth0 --mac=00:50:56:33:77:19 --interface-type=bond_slave --interface-master=bond0
#cobbler system edit --name=192.168.98.136 --interface=eth1 --mac=00:50:56:33:FC:99 --interface-type=bond_slave --interface-master=bond0

#docker host
#cobbler system add --name=192.168.10.161 --mac=00:24:E8:64:24:59 --ip-address=192.168.10.161 --subnet=255.255.255.0 --gateway=192.168.10.5 --interface=eth0 --static=1 --profile=docker --ksmeta="host_type=docker" --hostname=test.meizu.com --name-servers=192.168.10.160

#kvm host
#cobbler system add --name=192.168.10.161 --mac=00:24:E8:64:24:59 --ip-address=192.168.10.161 --subnet=255.255.255.0 --gateway=192.168.10.5 --interface=eth0 --static=1 --profile=kvm --ksmeta="host_type=kvm" --hostname=test.meizu.com --name-servers=192.168.10.160

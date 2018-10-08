NFS端：
mkdir /home/share
cd /home/share/
vim index.html
nfs.test //内容随便写
修改配置文件，设置NFS共享：
vim /etc/exports 
  /home/share 192.168.0.0/24(rw,sync)
service nfs start

*****************************************************************

负载调度端：
iptables -F
vim /etc/selinux/config 
SELINUX=disabled
vim /etc/sysctl.conf 
net.ipv4.ip_forward = 1　　　　 //1为开启转发
net.ipv4.conf.all.send_redirects = 0　　　　 //在最底部添加下面3句
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.eth0.send_redirects = 0

sysctl -p　　　　 // 刷新内核使之立即生效
cd /etc/sysconfig/network-scripts/
cp ifcfg-eth0 ifcfg-eth0:0
vim ifcfg-eth0:0
DEVICE=eth0:0
IPADDR=192.168.0.200
NETMASK=255.255.255.0

ifup eth0:0

ip a

eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
link/ether 00:0c:29:d3:9f:8e brd ff:ff:ff:ff:ff:ff
inet 192.168.0.223/24 brd 192.168.0.255 scope global eth0
inet 192.168.0.200/24 brd 192.168.0.255 scope global secondary eth0:0

rpm -ivh /mnt/usb1/Packages/ipvsadm-1.26-4.el6.x86_64.rpm　//光盘自带
ipvsadm -A -t 192.168.0.200:80 -s rr　　　　 //-t 添加集群地址，-s:轮循
ipvsadm -a -t 192.168.0.200:80 -r 192.168.0.224:80 -g　//在集群中添加节点地址，-g:DR，权重默认是1（权重格式：-w 1）
ipvsadm -a -t 192.168.0.200:80 -r 192.168.0.225:80 -g 　　 //在集群中添加节点地址，-g:DR模式，权重默认是1（权重格式：-w 1）
ipvsadm -Ln     //查看
service ipvsadm save       //保存策略
ipvsadm -S > 1.ipvs 　　　 //保存到当前目录
ipvsadm -C　　　　         //清除所有记录
ipvsadm -D -t|u|f virtual-service-addres　　 //删除内核虚拟服务器表中的一条虚拟服务器记录
ipvsadm -E -t|u|f virutal-service-address:port [-s -p -M]  //编辑内核虚拟服务器表中的一条虚拟服务器记录

*****************************************************************

web1端：
cd /etc/sysconfig/network-scripts/
cp ifcfg-lo ifcfg-lo:0
vim ifcfg-lo:0
DEVICE=lo:0
IPADDR=192.168.0.200	　　　
NETMASK=255.255.255.255　　　　
ifup lo:0
ip a

lo:
inet 127.0.0.1/8 scope host lo
inet 192.168.0.200/32 brd 127.255.255.255 scope global lo:0

vim /etc/sysctl.conf   (追加进去)
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_ignore = 1
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_ignore = 1
net.ipv4.conf.lo.arp_announce = 2
注：
arp_announce=
	用来设置主动向外通告自己IP与MAC地址的对应关系的通告级别
	0 表示将本机任何接口上的任何地址都向外通告
	1 尽可能避免向目标网络通告与其不匹配的地址信息
	2 仅向目标网络通告与其网络匹配的地址信息
	设置此参数是为了防止vip地址记录错乱
响应级别
arp_ignore=
	接收到其他主机的ARP请求后的响应级别
	0 回应任何网络接口上对任何本地IP地址的arp查询请求
	1 只回答目标IP地址是来访网络接口本地地址的ARP查询请求

sysctl -p

yum -y install httpd
cd /var/www/html/
vim index.html
web server-1 　　　　 
service httpd start

########## route add -host 192.168.0.200 dev lo:0 #############
把共享目录挂载到本地：
showmount -e 192.168.0.227
mount -t nfs 192.168.0.227:/home/share /var/www/html/ 　　　　 
umount /var/www/html 　　　　 

**********************************************************************

web2端：
cd /etc/sysconfig/network-scripts/
cp ifcfg-lo ifcfg-lo:0
vim ifcfg-lo:0
DEVICE=lo:0
IPADDR=192.168.0.200
NETMASK=255.255.255.255 　　　　 //只改这3项，其他地方不动

ifup lo:0

########## route add -host 192.168.0.200 dev lo:0 #############
yum -y install httpd
vim /etc/sysctl.conf
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_ignore = 1
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_ignore = 1
net.ipv4.conf.lo.arp_announce = 2

sysctl -p

cd /var/www/html/
vim index.html
　　web server-2 　　
service httpd start

把共享目录挂载到本地：
showmount -e 192.168.0.227
mount -t nfs 192.168.0.227:/home/share /var/www/html/ 　　　　 // 挂载命令
umount /var/www/html 　　　　 // 卸载
service httpd start

****************************************************************

如果在web1和web2端都挂载上NFS后：
[root@INT_test ~]# curl 192.168.0.200
nfs.test
[root@INT_test ~]# curl 192.168.0.200
nfs.test
[root@INT_test ~]# curl 192.168.0.200
nfs.test

如果在web1和web2端都卸载掉NFS的挂载后：
[root@INT_test ~]# curl 192.168.0.200
web server-1
[root@INT_test ~]# curl 192.168.0.200
web server-2
[root@INT_test ~]# curl 192.168.0.200
web server-1
[root@INT_test ~]# curl 192.168.0.200
web server-2

// ok successfull ~!~!~

 
使用ansible来安装httpd：
先把web1和web2端安装的httpd都卸载掉并把从NFS上的挂载也umount掉：
service httpd stop 
 yum remove httpd

在测试端安装ansible： 
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm 
yum -y install ansible
ssh-keygen -t rsa　　　　　　 //一路回车，不要输入任何一个密码
cd /root/.ssh/ 
cat id_rsa.pub >> authorized_key

配置ansible：
vim /etc/ansible/ansible.cfg
[defaults]
host_key_checking = False 　　　　 //开启
log_path = /var/log/ansible.log 　 //开启
[accelerate]
accelerate_port = 5099 　　　　    //开启
accelerate_multi_key = yes　　     //开启

vim /etc/ansible/hosts
[opop]
192.168.0.224    ansible_user=root  ansible_ssh_pass="aaaaaa" 　　　　 //web1的地址，对端用户名和密码
192.168.0.225    ansible_user=root  ansible_ssh_pass="aaaaaa" 　　　　 //web2的地址，对端用户名和密码

vim kk.yml 　　　　 //任意地方写这个剧本
---
- hosts: opop
  remote_user: root
  tasks:
        - name: ssh-copy-key
          authorized_key: user=root key="{{lookup('file', '/root/.ssh/id_rsa.pub')}}"
        - name: install a Apache
          yum: name=httpd state=present
        - name: 挂载NFS
          shell: mount -t nfs 192.168.0.227:/home/share /var/www/html
        - name: start Apache
          service: name=httpd state=started



执行playbook：
ansible-playbook --check kk.yml 　　　　 //检查剧本有没错误
ansible-playbook kk.yml 　　　　　　　   //执行剧本

测试：
在浏览器上测试或者curl测试.......

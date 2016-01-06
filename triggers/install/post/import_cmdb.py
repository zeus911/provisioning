#!/bin/env python
import sys
import os
import time
import json
import MySQLdb

DBHOST=''
DBUSER=''
DBPASSWD=''
DBNAME=''

TIME_FORMAT='%Y-%m-%d %H:%M:%S'

factsdir = '/tmp/facts'
pcisdir  = '/tmp/pcidata'
logfile  = '/tmp/factlog'
name = sys.argv[2]
ip = sys.argv[3]

def fact_dump_file(ip):
    if not os.path.isdir('%s' % factsdir):
        os.mkdir('%s' % factsdir)

    result = os.popen('ansible all -i %s, -m setup --tree %s ' % (ip,factsdir)).read()

    now = time.strftime(TIME_FORMAT, time.localtime())

    log = dict(
        ip = ip,
        time = now
    )

    logfp = open(logfile, 'a+')
    json.dump(log,logfp)
    logfp.write('\r\n')


def pci_dump_file(ip):
    result = os.popen('ansible all -i %s, -m shell -a "lspci |grep Ethernet|awk \'{print $1}\'|xargs -n1 lspci -v -s" --tree %s' % (ip,pcisdir) ).read()

def fact_to_db(data):

    if type(data) == dict:
        pass

    try:
        con=MySQLdb.connect(DBHOST,DBUSER,DBPASSWD,DBNAME)
        cur=con.cursor()
        print "DB links established"
    except:
        print "DB not accessible"

    facts = data.get('ansible_facts', None)
    now = time.strftime(TIME_FORMAT, time.localtime())
    bios_date = facts.get('ansible_bios_date', None)
    bios_version = facts.get('ansible_bios_version', None)
    hostname = facts.get('ansible_hostname', None)
    architecture = facts.get('ansible_architecture', None)
    distribution = facts.get('ansible_distribution', None)
    distribution_version = facts.get('ansible_distribution_version', None)
    system = facts.get('ansible_system', None)
    kernel = facts.get('ansible_kernel', None)
    ipv4 = facts.get('ansible_default_ipv4', None)
    ipv6 = facts.get('ansible_default_ipv6', None)
    devices = facts.get('ansible_devices', None)
    domain = facts.get('ansible_domain', None)
    eth0 = facts.get('ansible_eth0', None)
    eth1 = facts.get('ansible_eth1', None)
    fqdn = facts.get('ansible_fqdn', None)
    machine = facts.get('ansible_machine', None)
    machine_id = facts.get('ansible_machine_id', None)
    mounts = facts.get('ansible_mounts', None)
    nodename = facts.get('ansible_nodename', None)
    processor = facts.get('ansible_processor', None)
    processor_cores = facts.get('ansible_processor_cores', None)
    processor_count = facts.get('ansible_processor_count', None)
    processor_threads_per_core = facts.get('ansible_processor_threads_per_core', None)
    processor_vcpus = facts.get('ansible_processor_vcpus', None)
    product_name = facts.get('ansible_product_name', None)
    product_serial = facts.get('ansible_product_serial', None)
    product_uuid = facts.get('ansible_product_uuid', None)
    product_version = facts.get('ansible_product_version', None)
    selinux = facts.get('ansible_selinux', None)
    system_vendor = facts.get('ansible_system_vendor', None)
    virtualization_role = facts.get('ansible_virtualization_role', None)
    virtualization_type = facts.get('ansible_virtualization_type', None)

    network_pci_data = data.get('network_pci_data',None)

    try:
        query="""INSERT IGNORE INTO facts (last_update,bios_date,bios_version,hostname,architecture,distribution,distribution_version,system,
        kernel,ipv4,ipv6,devices,domain,eth0,eth1,fqdn,machine,machine_id,mounts,nodename,processor,
        processor_cores,processor_count,processor_threads_per_core,processor_vcpus,product_name,product_serial,
        product_uuid,product_version,selinux,system_vendor,virtualization_role,virtualization_type,network_pci_data) VALUES('%s','%s',
        '%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s',
        '%s','%s','%s','%s','%s','%s','%s','%s','%s','%s');""" % \
        (now,bios_date,bios_version,hostname,architecture,distribution,distribution_version,system,kernel,json.dumps(ipv4),json.dumps(ipv6),json.dumps(devices),domain,json.dumps(eth0),json.dumps(eth1),
         fqdn,machine,machine_id,json.dumps(mounts),nodename,json.dumps(processor),processor_cores,processor_count,
         processor_threads_per_core,processor_vcpus,product_name,product_serial,product_uuid,product_version,
         json.dumps(selinux),system_vendor,virtualization_role,virtualization_type,network_pci_data)

        cur.execute(query)

        con.commit()
    except MySQLdb.Error as err:
        print("Something went wrong: {}".format(err))

def factdir_to_db():
    hostlist=os.listdir( factsdir )
    for file in hostlist:
        if os.path.isfile(factsdir+'/'+file):
            json_data = open(factsdir+'/'+file)
            data = json.load(json_data)
            
            pci_json_data = open(pcisdir+'/'+file)
            pcidata = json.load(pci_json_data)
            data['network_pci_data'] = pcidata.get('stdout')

            fact_to_db(data)
            os.rename(factsdir+'/'+file,factsdir+'/'+"done/"+file)

fact_dump_file(ip)
pci_dump_file(ip)

#factdir into db
'''CREATE TABLE `facts` (                                     
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,           
  `last_update` timestamp NULL DEFAULT NULL,               
  `hostname` varchar(300) DEFAULT NULL,                    
  `architecture` varchar(300) DEFAULT NULL,                
  `distribution` varchar(300) DEFAULT NULL,                
  `distribution_version` varchar(300) DEFAULT NULL,        
  `system` varchar(300) DEFAULT NULL,                      
  `kernel` varchar(300) DEFAULT NULL,                      
  `ipv4` varchar(300) DEFAULT NULL,                        
  `ipv6` varchar(300) DEFAULT NULL,                        
  `devices` text,                                          
  `domain` varchar(300) DEFAULT NULL,                      
  `eth0` text,                                             
  `eth1` text,                                             
  `fqdn` varchar(300) DEFAULT NULL,                        
  `machine` varchar(300) DEFAULT NULL,                     
  `machine_id` varchar(300) DEFAULT NULL,                  
  `mounts` text,                                           
  `nodename` varchar(300) DEFAULT NULL,                    
  `processor` text,                                        
  `processor_cores` int(3) DEFAULT NULL,                   
  `processor_count` int(3) DEFAULT NULL,                   
  `processor_threads_per_core` varchar(300) DEFAULT NULL,  
  `processor_vcpus` int(3) DEFAULT NULL,                   
  `product_name` varchar(300) DEFAULT NULL,                
  `product_serial` varchar(300) DEFAULT NULL,              
  `product_uuid` varchar(300) DEFAULT NULL,                
  `product_version` varchar(300) DEFAULT NULL,             
  `selinux` varchar(300) DEFAULT NULL,                     
  `system_vendor` varchar(300) DEFAULT NULL,               
  `virtualization_role` varchar(300) DEFAULT NULL,         
  `virtualization_type` varchar(300) DEFAULT NULL,         
  `bios_date` varchar(300) DEFAULT NULL,                   
  `bios_version` varchar(300) DEFAULT NULL,                
  `network_pci_data` text,                                 
  PRIMARY KEY (`id`),                                      
  UNIQUE KEY `machine_id` (`product_uuid`)                 
);

CREATE TABLE `inventory` (
  `hostname` varchar(25) NOT NULL,
  `asset_id` varchar(25) DEFAULT NULL,
  `price` varchar(25) DEFAULT NULL,
  `role` varchar(25) DEFAULT NULL,
  `product` varchar(25) DEFAULT NULL,
  `owner` varchar(25) DEFAULT NULL,
  `datacenter` varchar(25) DEFAULT NULL,
  `rack` varchar(25) DEFAULT NULL ,
  `environment` varchar(25) DEFAULT NULL ,
  `tier` varchar(25) DEFAULT NULL ,
  PRIMARY KEY (`Hostname`)
);
'''

#factdir_to_db()

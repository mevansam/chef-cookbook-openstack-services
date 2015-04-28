## OpenStack HA services attributes

## ELK Logging setup

# List of named syslog sinks
#  
# i.e. 
# { 
#   "haproxy" => { 
#     "protocol" => "tcp",
#     "bind_address" => "0.0.0.0"
#     "port" => 51400 }
# }
#
default["elk"]["logstash"]["syslog"]["ports"] = { }

default["elk"]["logstash"]["syslog"]["bind_address"] = "0.0.0.0"
default["elk"]["logstash"]["syslog"]["port"] = 514

default["elk"]["logio"]["http_port"] = 9081

default["elk"]["logio"]["server_address"] = "127.0.0.1"
default["elk"]["logio"]["server_port"] = 28777

default["nvm"]["nvm_version"] = "0.22.2"
default["nvm"]["nodejs_version"] = "0.10.35"

## Additional Percona / MySql options
default["percona"]["cluster_role"] = "os-ha-database"
default["percona"]["haproxy_cluster_role"] = "os-ha-proxy"

default["percona"]["mysql"]["ssl"] = false
default["percona"]["mysql"]["config_path"] = "/etc/mysql"
default["percona"]["mysql"]["certificate_databag_item"] = nil

default["percona"]["openstack"]["services"] = [ ]

## Additional Messaging RabbitMQ options
default["rabbitmq"]["cluster_role"] = "os-ha-messaging"

## Attributes that identify the databags containing SSL certificate data
default["rabbitmq"]["certificate_databag_item"] = nil
default["percona"]["mysql"]["certificate_databag_item"] = nil
default["openstack"]["dashboard"]["certificate_databag_item"] = nil

## OpenStack proxy (services loadbalancer)

# OpenStack app services
default["openstack"]["openstack_app_proxy"] = nil

# Openstack ops services
default["openstack"]["openstack_ops_proxy"] = nil

## OpenStack syslog host

# Array of ips.
#
# protocol defaults to udp if not specified
#
default["openstack"]["logging"]["syslog_endpoint"]["hosts"] = [ ]
default["openstack"]["logging"]["syslog_endpoint"]["protocol"] = "udp"

default["haproxy"]["log"] = [ {
    "address" => "127.0.0.1",
    "length" => 1024,
    "facility" => "local0",
    "level" => "info" } ]

## OpenStack cookbook overrides
override['openstack']['secret']['key_path'] = "/etc/chef/encrypted_data_bag_secret"
override['openstack']['db']['root_user_use_databag'] = true

override["openstack"]["secret"]["user_passwords_data_bag"] = "os_user_passwords-#{node.chef_environment}"
override["openstack"]["secret"]["db_passwords_data_bag"] = "os_db_passwords-#{node.chef_environment}"
override["openstack"]["secret"]["service_passwords_data_bag"] = "os_service_passwords-#{node.chef_environment}"
override["openstack"]["secret"]["secrets_data_bag"] = "os_secrets-#{node.chef_environment}"

## Memcached server cluster to use for caching
default["openstack"]["memcached"]["cluster_name"] = nil

## OpenStack service clustering
default["openstack"]["controller"]["cluster_role"] = "os-ha-controller"

default['openstack']['network']['l3']['is_clustered'] = false

## Xen Specific Attributes

# Location of nova source
default['openstack']['compute']['source_url'] = 'https://github.com/openstack/nova.git'

# Location of neutron source
default['openstack']['network']['source_url'] = 'https://github.com/mevansam/neutron.git'

# If true then multiple l3_agent.ini files will be created
# for each configured external network and started as 
# a clustered pacemaker service.
default['openstack']['network']['l3']['multiple_external'] = false

# Role identifying the Xen hypervisor cluster
default["openstack"]["xen"]["cluster_role"] = "os-xen-host"

# Xen storage NFS share to use for images. If uuid is provided then uuid 
# lookup by name will be ignored. If a new SR or and existing SR is 
# attached then it will be labeled using the given name.
default['openstack']['xen']['storage']["uuid"] = nil
default['openstack']['xen']['storage']["name"] = nil
default['openstack']['xen']['storage']["nfs_server"] = nil
default['openstack']['xen']['storage']["nfs_serverpath"] = nil

default['openstack']['xen']['storage']["shared_iso_name"] = "Shared ISOs/Templates"
default['openstack']['xen']['storage']["default_template"] = nil

# Public external network. Usually this is attached to a physical
# interface that is separate from that of the management network.
default['openstack']['xen']['network']['public_interface']['name'] = "eth1"
default['openstack']['xen']['network']['public_interface']['device'] = "eth1"
default['openstack']['xen']['network']['public_interface']['mode'] = nil

# Network names that map to above bridges which
# are populated by the xen-host.rb recipe
default['openstack']['xen']['network']['xen_trunk_network'] = nil
default['openstack']['xen']['network']['xen_int_network'] = nil

# See https://raw.githubusercontent.com/matelakat/shared/xs-q-v1/xenserver-quantum/deployment.png
# for xen neutron setup. 
#
# Example that maps to deployment.png:
#
# default['openstack']['xen']['network']['vm_network_bridge'] = 'xapiY'
# default['openstack']['xen']['network']['xen_int_network_bridge'] = 'xapiX'
#
default['openstack']['xen']['network']['vm_network_bridge'] = nil
default['openstack']['xen']['network']['xen_int_network_bridge'] = nil

# Xen VLAN networks not managed by OpenStack
default['openstack']['xen']['network']['vlans'] = [ ]

## Xen DomU OpenStack Compute VM Configuration
default['openstack']['xen']['vm']['template'] = nil
default['openstack']['xen']['vm']['name'] = "#{node["hostname"]}-OpenStack-DomU"
default['openstack']['xen']['vm']['cpus'] = nil
default['openstack']['xen']['vm']['memory'] = nil
default['openstack']['xen']['vm']['network'] = nil
default['openstack']['xen']['vm']['ip'] = nil
default['openstack']['xen']['vm']['gateway'] = nil
default['openstack']['xen']['vm']['netmask'] = nil
default['openstack']['xen']['vm']['domain'] = nil
default['openstack']['xen']['vm']['dns'] = nil

## Load attributes from openstack-common cookbook
include_attribute "openstack-common::default"
include_attribute "openstack-common::database"
include_attribute "openstack-common::messaging"

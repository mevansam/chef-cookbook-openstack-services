# Copyright 2013, Copyright (c) 2012-2012 Fidelity Investments.

## Additional Percona / MySql options
default["percona"]["cluster_role"] = "os-ha-database"

default["percona"]["mysql"]["ssl"] = false
default["percona"]["mysql"]["config_path"] = "/etc/mysql"
default["percona"]["mysql"]["certificate_databag_item"] = nil

default["percona"]["openstack"]["services"] = [ ]

## Attributes that identify the databags containing SSL certificate data
default["rabbitmq"]["certificate_databag_item"] = nil
default["percona"]["mysql"]["certificate_databag_item"] = nil
default["openstack"]["dashboard"]["certificate_databag_item"] = nil

## Xen Specific Attributes

# Location of nova source
default['openstack']['compute']['source_url'] = 'https://github.com/openstack/nova.git'

# Location of neutron source
default['openstack']['network']['source_url'] = 'https://github.com/openstack/neutron.git'

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

## Load attributes from openstack-common cookbook
include_attribute "openstack-common::default"
include_attribute "openstack-common::database"

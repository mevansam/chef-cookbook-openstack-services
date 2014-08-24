# Copyright 2013, Copyright (c) 2012-2012 Fidelity Investments.

## Additional Percona / MySql options
default["percona"]["cluster_role"] = nil

default["percona"]["mysql"]["ssl"] = false
default["percona"]["mysql"]["config_path"] = "/etc/mysql"
default["percona"]["mysql"]["certificate_databag_item"] = nil

default["percona"]["openstack"]["services"] = [ ]

## Attributes that identify the databags containing SSL certificate data
default["rabbitmq"]["certificate_databag_item"] = nil
default["percona"]["mysql"]["certificate_databag_item"] = nil
default["openstack"]["dashboard"]["certificate_databag_item"] = nil

# Location of nova source
default['openstack']['compute']['source_url'] = 'https://github.com/openstack/nova.git'

# Xen storage NFS share to use for images
default['openstack']['xen']['default_storage_repository'] = nil

## Post-install packages
default["openstack"]["post-install-packages"] = { }

## Load attributes from openstack-common cookbook
include_attribute "openstack-common::default"
include_attribute "openstack-common::database"

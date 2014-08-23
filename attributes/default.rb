# Copyright 2013, Copyright (c) 2012-2012 Fidelity Investments.

## Additional Percona / MySql options
default["percona"]["cluster_role"] = nil

default["percona"]["mysql"]["ssl"] = false
default["percona"]["mysql"]["config_path"] = "/etc/mysql"
default["percona"]["mysql"]["certificate_databag_item"] = nil

default["percona"]["openstack"]["services"] = [ ]

## Additional RabbitMQ options
default["rabbitmq"]["certificate_databag_item"] = nil

## Post-install packages
default["openstack"]["post-install-packages"] = { }

## Load attributes from openstack-common cookbook
include_attribute "openstack-common::default"
include_attribute "openstack-common::database"

# Copyright 2013, Copyright (c) 2012-2012 Fidelity Investments.

## Additional Percona / MySql options
default["mysql"]["ssl"] = false
default["mysql"]["config_path"] = "/etc/mysql"
default["mysql"]["certificate_databag_item"] = nil

## Additional RabbitMQ options
default["rabbitmq"]["certificate_databag_item"] = nil
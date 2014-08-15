name             'openstack-services'
maintainer       'Mevan Samaratunga'
maintainer_email 'mevan.samaratunga@fmr.com'
license          'Copyright (c) 2012-2012 Fidelity Investments all rights reserved'
description      'Installs/Configures openstack services'
long_description 'Installs/Configures recipes that use stackforge and related cookbooks to setup highly available openstack services'
version          '0.1.0'

depends          'sysutils', '= 1.0.0'
depends          'percona', "= 0.15.5"

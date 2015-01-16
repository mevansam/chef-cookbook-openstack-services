name             'openstack-services'
maintainer       'Mevan Samaratunga'
maintainer_email 'mevansam@gmail.com'

description      'Installs/Configures openstack services'
long_description 'Installs/Configures recipes that use stackforge and related cookbooks to setup highly available openstack services'
version          '0.1.0'

depends          'sysutils', '= 1.0.0'
depends          'cluster',  '= 1.0.0'
depends          'storage',  '= 0.1.0'
depends          'network',  '= 0.1.0'
depends          'compute',  '= 0.1.0'

depends          'rabbitmq',  '>= 3.2.3'
depends          'percona',   '~> 0.15.5'
depends          'haproxy',   '~> 1.6.6'
depends          'hostsfile', '~> 2.4.5'

depends          'openstack-common'
depends          'openstack-compute'

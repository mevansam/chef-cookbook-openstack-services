## All services monkey patched to use upstart provider

default["upstart"]["services"] = [
    "keystone",
    "glance-registry",
    "glance-api",
    "cinder-volume",
    "cinder-scheduler",
    "cinder-api",
    "ceilometer-agent-central",
    "ceilometer-api",
    "ceilometer-collector",
    "nova-api",
    "nova-api-ec2",
    "nova-api-os-compute",
    "nova-cert",
    "nova-scheduler",
    "nova-conductor",
    "nova-novncproxy",
    "nova-consoleauth",
    "nova-api-metadata",
    "nova-compute",
    "neutron-server",
    "neutron-plugin-openvswitch-agent",
    "openvswitch-switch",
    "tgt"
]

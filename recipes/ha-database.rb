#
# Cookbook Name:: openstack-services
# Recipe:: default
#
# Copyright (c) 2014 Fidelity Investments.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Check if extra storage was provided and if it was format and mount it
if node["percona"]["server"].has_key?("data_disk")

    data_disk = node["percona"]["server"]["data_disk"]
    data_path = node["percona"]["server"]["data_path"]

    script "prepare data disk" do
        interpreter "bash"
        user "root"
        cwd "/tmp"
        code <<-EOH

            if [ -n "$(lsblk | grep #{data_disk.split("/").last})" ] && \
                [ -z "$(blkid | grep #{data_disk})"]; then

                echo "**** Formating data disk #{data_disk} with ext4 file system..."
                mkfs.ext4 #{data_disk}
                if [ $? -eq 0 ]; then
                    mkdir -p #{data_path}
                fi
            fi
        EOH
    end

    mount data_path do
        device data_disk
        fstype "ext4"
        action [:mount, :enable]
    end

    node.override["percona"]["server"]["datadir"] = data_path
end

# Setup the Percona XtraDB Cluster
cluster_ips = []
unless Chef::Config[:solo]
    search(:node, 'role:os-ha-database').each do |other_node|
        next if other_node['private_ipaddress'] == node['private_ipaddress']
        Chef::Log.info "Found Percona XtraDB cluster peer: #{other_node['private_ipaddress']}"
        cluster_ips << other_node['private_ipaddress']
    end
end

cluster_ips.each do |ip|

    firewall_rule "allow Percona group communication to peer #{ip}" do
        source ip
        port 4567
        action :allow
    end

    firewall_rule "allow Percona state transfer to peer #{ip}" do
        source ip
        port 4444
        action :allow
    end

    firewall_rule "allow Percona incremental state transfer to peer #{ip}" do
        source ip
        port 4568
        action :allow
    end
end

cluster_address = "gcomm://#{cluster_ips.join(',')}"
Chef::Log.info "Using Percona XtraDB cluster address of: #{cluster_address}"
node.override["percona"]["cluster"]["wsrep_cluster_address"] = cluster_address
node.override["percona"]["cluster"]["wsrep_node_name"] = node['hostname']

include_recipe 'percona::cluster'
include_recipe 'percona::backup'
include_recipe 'percona::toolkit'
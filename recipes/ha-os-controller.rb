#
# Cookbook Name:: openstack-services
# Recipe:: ha-os-controller
#
# Copyright (c) 2014 Fidelity Investments.
#
# Author: Mevan Samaratunga
# Email: mevan.samaratunga@fmr.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# If more than one controller node in this cluster then retrieve 
# determine if one-time initializations have already been done
cluster_role = node["openstack"]["controller"]["cluster_role"]

nova_initialized = false
unless Chef::Config[:solo]
    search(:node, "role:#{cluster_role} AND chef_environment:#{node.chef_environment}").each do |controller_node|
        
        next if controller_node['ipaddress']==node['ipaddress']

        nova_initialized ||= (controller_node["openstack"].nil? ? false : controller_node["openstack"]["compute"]["initialized"])
    end
end

if !nova_initialized
	include_recipe "openstack-compute::nova-setup" 
	nova_initialized = true
end

node.set["openstack"]["compute"]["initialized"] = nova_initialized
node.save

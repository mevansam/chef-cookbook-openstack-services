#
# Cookbook Name:: openstack-services
# Recipe:: ha-os-common
#

#
# Author: Mevan Samaratunga
# Email: mevansam@gmail.com
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

class ::Chef::Recipe # rubocop:disable Documentation
    include ::SysUtils::Helper
end

############################################################################
# Work around for bug https://bugs.launchpad.net/openstack-chef/+bug/1313646
# This code should be removed when chef client 11.14 is available
skip_upstart_patch = node["env"]["skip_upstart_patch"]
if !skip_upstart_patch && node['platform'] == 'ubuntu' && node['platform_version'] == '14.04' && node[:chef_packages][:chef][:version] < "11.14"
	Chef::Platform.set :platform => :ubuntu, :resource => :service, :provider => Chef::Provider::Service::Upstart
end
############################################################################

node.override["openstack"]["secret"]["user_passwords_data_bag"] = "os_user_passwords-#{node.chef_environment}"
node.override["openstack"]["secret"]["db_passwords_data_bag"] = "os_db_passwords-#{node.chef_environment}"
node.override["openstack"]["secret"]["service_passwords_data_bag"] = "os_service_passwords-#{node.chef_environment}"
node.override["openstack"]["secret"]["secrets_data_bag"] = "os_secrets-#{node.chef_environment}"
node.override['openstack']['secret']['key_path'] = "/etc/chef/encrypted_data_bag_secret"
node.override['openstack']['db']['root_user_use_databag'] = true

if node.run_list.expand(node.chef_environment).recipes.include?("openstack-compute::compute") &&
	node["openstack"]["compute"]["driver"]=="xenapi.XenAPIDriver"

	xen_host_ip = IO.read("/proc/cmdline")[/hostip=(\d+\.\d+\.\d+\.\d+)/, 1]
	if !xen_host_ip.empty?
		node.override["openstack"]["compute"]["xenapi"]["connection_url"] = "https://#{xen_host_ip}" 
		node.override['openstack']['network']['xenapi']['connection_url'] = "https://#{xen_host_ip}"
		node.override['openstack']['xen']['host_ip'] = xen_host_ip

	else !node.override["openstack"]["compute"]["xenapi"]["connection_url"] || 
		!node.override['openstack']['network']['xenapi']['connection_url'] ||
		!node.override['openstack']['xen']['host_ip']
		Chef::Application.fatal("Unable to determine Xem Dom0 ip the OpenStack compute worker needs to be associated with.")
	end

	xen_host_name = IO.read("/proc/cmdline")[/hostname=(\w+)/, 1]
	if !xen_host_name.empty?
		node.override['openstack']['xen']['host_name'] = xen_host_name

	else !node.override['openstack']['xen']['host_name']
		Chef::Application.fatal("Unable to determine Xem Dom0 host name the OpenStack compute worker needs to be associated with.")
	end

	xen_trunk_network_bridge = IO.read("/proc/cmdline")[/xentrunkbridge=(\w+)/, 1]
	if !xen_trunk_network_bridge.empty?
		node.override['openstack']['xen']['network']['xen_trunk_network_bridge'] = xen_trunk_network_bridge

	else !node.override['openstack']['xen']['network']['xen_trunk_network_bridge']
		Chef::Application.fatal("Unable to determine VM bridge.")
	end

	xen_int_network_bridge = IO.read("/proc/cmdline")[/xenintbridge=(\w+)/, 1]
	if !xen_int_network_bridge.empty?
		node.override['openstack']['xen']['network']['xen_int_network_bridge'] = xen_int_network_bridge

	else !node.override['openstack']['xen']['network']['xen_int_network_bridge']
		Chef::Application.fatal("Unable to determine Xen integration bridge.")
	end
end

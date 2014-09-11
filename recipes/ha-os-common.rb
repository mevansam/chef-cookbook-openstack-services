#
# Cookbook Name:: openstack-services
# Recipe:: ha-os-common
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

skip_upstart_patch = node["env"]["skip_upstart_patch"]
if !skip_upstart_patch
	# Work around for bug https://bugs.launchpad.net/openstack-chef/+bug/1313646
	# This code should be removed when chef client 11.14 is available
	if node['platform'] == 'ubuntu' && node['platform_version'] == '14.04'
		Chef::Platform.set :platform => :ubuntu, :resource => :service, :provider => Chef::Provider::Service::Upstart
	end
end

node.override["openstack"]["secret"]["user_passwords_data_bag"] = "os_user_passwords-#{node.chef_environment}"
node.override["openstack"]["secret"]["db_passwords_data_bag"] = "os_db_passwords-#{node.chef_environment}"
node.override["openstack"]["secret"]["service_passwords_data_bag"] = "os_service_passwords-#{node.chef_environment}"
node.override["openstack"]["secret"]["secrets_data_bag"] = "os_secrets-#{node.chef_environment}"
node.override['openstack']['secret']['key_path'] = "/etc/chef/encrypted_data_bag_secret"
node.override['openstack']['db']['root_user_use_databag'] = true

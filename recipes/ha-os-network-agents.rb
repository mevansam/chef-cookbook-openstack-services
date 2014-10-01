#
# Cookbook Name:: openstack-services
# Recipe:: ha-os-network-agents
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

['quantum', 'neutron'].include?(node['openstack']['compute']['network']['service_type']) || return

# Disable agents services as they will be managed by the cluster manager
if platform_family?('debian')
	[ "neutron-l3-agent", "neutron-metadata-agent", "neutron-dhcp-agent" ].each do |service|
		cookbook_file "/etc/init/#{service}.override" do
			source "upstart-service.override"
			owner 'root'
  			group 'root'
  		end
	end
end

include_recipe 'openstack-network::common'

platform_options = node['openstack']['network']['platform']
core_plugin = node['openstack']['network']['core_plugin']
main_plugin = node['openstack']['network']['core_plugin_map'][core_plugin.split('.').last.downcase]

identity_endpoint = endpoint 'identity-api'
service_pass = get_password 'service', 'openstack-network'
metadata_secret = get_secret node['openstack']['network']['metadata']['secret_name']

platform_options['neutron_l3_packages'].each do |pkg|
	package pkg do
		options platform_options['package_overrides']
		action :upgrade
		# The providers below do not use the generic L3 agent...
		not_if { ['nicira', 'plumgrid', 'bigswitch'].include?(main_plugin) }
	end
end

platform_options['neutron_metadata_agent_packages'].each do |pkg|
	package pkg do
		action :upgrade
		options platform_options['package_overrides']
	end
end

platform_options['neutron_dhcp_packages'].each do |pkg|
	package pkg do
		options platform_options['package_overrides']
		action :upgrade
	end
end

template '/etc/neutron/l3_agent.ini' do
	source 'l3_agent.ini.erb'
	cookbook 'openstack-network'
	owner node['openstack']['network']['platform']['user']
	group node['openstack']['network']['platform']['group']
	mode 00644
end

template '/etc/neutron/metadata_agent.ini' do
	source 'metadata_agent.ini.erb'
	cookbook 'openstack-network'
	owner node['openstack']['network']['platform']['user']
	group node['openstack']['network']['platform']['group']
	mode 00644
	variables(
		identity_endpoint: identity_endpoint,
		metadata_secret: metadata_secret,
		service_pass: service_pass
	)
	action :create
end

template '/etc/neutron/dnsmasq.conf' do
	source 'dnsmasq.conf.erb'
	cookbook 'openstack-network'
	owner node['openstack']['network']['platform']['user']
	group node['openstack']['network']['platform']['group']
	mode 00644
end

template '/etc/neutron/dhcp_agent.ini' do
	source 'dhcp_agent.ini.erb'
	cookbook 'openstack-network'
	owner node['openstack']['network']['platform']['user']
	group node['openstack']['network']['platform']['group']
	mode 00644
end

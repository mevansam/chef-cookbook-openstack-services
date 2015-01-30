#
# Cookbook Name:: openstack-services
# Recipe:: ha-os-common
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

# Enable all services that will be managed by Runit and created
# by recipes in the current run-list. This fixes  a bug where
# the restart does not check if service is ready.
#
# see https://github.com/opscode/chef-init/blob/release/0.3.2/lib/chef/provider/container_service/runit.rb
#
is_container = !node['container_service'].nil?
is_container_build = is_container && node.name.end_with?('-build')

if is_container

	if is_container_build

		node["container_service"].each_key do |service|

			service "enabling runit #{service}" do
				provider Chef::Provider::ContainerService::Runit
				service_name service
				action :enable
			end
		end

		ruby_block "waiting for runit services to be enabled" do
			block do

				node["container_service"].each do |service, commands|

					service_path = "/opt/chef/service/#{service}"

					until ::FileTest.pipe?("#{service_path}/supervise/ok")
						sleep 1
					end
					until ::FileTest.pipe?("#{service_path}/log/supervise/ok")
						sleep 1
					end

					finish = commands["finish"]
					unless finish.nil?

						finish_script_file = "#{service_path}/finish"
						Chef::Log.info("Creating finish script #{finish_script_file}.")

						finish_script_script = "#!/bin/sh\n" +
							"exec 2>&1\n" +
							"exec #{finish} 2>&1\n"

						::File.open(finish_script_file, 'w+') { |f| f.write(finish_script_script) }
						::File.chmod(0744, finish_script_file)
					end
				end
			end
		end
	else
		node["container_service"].each_key do |service|

			service "starting runit #{service}" do
				provider Chef::Provider::ContainerService::Runit
				service_name service
				action :start
			end
		end
	end
end

if node["openstack"]["endpoints"]["rsyslog"]

	if is_container_build

		service "rsyslog" do
			action :start
		end

	else

		service "rsyslog" do
			action :enable
		end

		Chef::Application.fatal!("You must provider the syslog servers as an array of {host => 'x.x.x.x' [, protocol => 'udp' ]}") \
			unless node["openstack"]["logging"]["syslog_endpoints"].is_a?(Array)

		syslog_servers = Array.new(node["openstack"]["logging"]["syslog_endpoints"])

		# This ensures that syslog destination alternate based on current hosts ip's modulus
		c = node['ipaddress'].split('.').last.to_i%syslog_servers.size
		syslog_servers.rotate!(c)

		template "/etc/rsyslog.d/99-openstack.conf" do
			source "rsyslog.conf.erb"
			mode "0644"
			variables(
				:primary_syslog_server => syslog_servers.shift,
				:secondary_syslog_servers => syslog_servers.size>0 ? syslog_servers : nil
			)
			notifies :restart, 'service[rsyslog]', :immediately
		end
	end

	node.override['openstack']['identity']['syslog']['use'] = true
	node.override['openstack']['telemetry']['syslog']['use'] = true
	node.override['openstack']['image']['syslog']['use'] = true
	node.override['openstack']['block-storage']['syslog']['use'] = true
	node.override['openstack']['compute']['syslog']['use'] = true
	node.override['openstack']['network']['syslog']['use'] = true
	node.override['openstack']['heat']['syslog']['use'] = true
	node.override['openstack']['database']['syslog']['use'] = true
	node.override['openstack']['orchestration']['syslog']['use'] = true
end

# To fix issue where vncserver_proxyclient_address is dedaulting to 0.0.0.0 and not the host's ip
node.override['openstack']['endpoints']['compute-vnc-bind']['host'] = node['ipaddress']

# To fix issue where iscsi_ip_address picks the wrong IP of the ohai ipaddress has been overridden
node.override['openstack']['block-storage']['volume']['iscsi_ip_address'] = node['ipaddress'] \
	if node.recipes.include?('openstack-block-storage::volume') ||
		node.recipes.include?('openstack-block-storage::scheduler') ||
		node.recipes.include?('openstack-block-storage::api') ||

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

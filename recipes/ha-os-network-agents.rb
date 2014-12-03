#
# Cookbook Name:: openstack-services
# Recipe:: ha-os-network-agents
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

['quantum', 'neutron'].include?(node['openstack']['compute']['network']['service_type']) || return

is_clustered = node['openstack']['network']['l3']['is_clustered']
if is_clustered 

    # Disable agents services that will be managed by the cluster manager
    if platform_family?('debian')
        [ "neutron-dhcp-agent", "neutron-metadata-agent", "neutron-l3-agent" ].each do |service|
            cookbook_file "/etc/init/#{service}.override" do
                source "upstart-service.override"
                owner 'root'
                group 'root'
            end
        end
    end

    include_recipe 'sysutils::cluster'
    
    do_init_cluster = !node["cluster_initializing_node"].nil? && node["cluster_initializing_node"]
    Chef::Log.info("Cluster initializing node: #{node["hostname"]}/#{do_init_cluster}")

    directory "/usr/lib/ocf/resource.d/openstack" do
        recursive true
    end
    cookbook_file "neutron-dhcp-agent" do
        path "/usr/lib/ocf/resource.d/openstack/neutron-dhcp-agent"
        mode 00744
        notifies :run, "ruby_block[start cluster DHCP agent service]", :delayed if do_init_cluster
    end
    cookbook_file "neutron-l3-agent" do
        path "/usr/lib/ocf/resource.d/openstack/neutron-l3-agent"
        mode 00744
        notifies :run, "ruby_block[start cluster L3 agent service]", :delayed if do_init_cluster
    end

    if do_init_cluster
        ruby_block "configure common crm properties" do
            block do
                sleep 20
                shell!("crm configure property no-quorum-policy=\"ignore\"")
                shell!("crm configure property pe-warn-series-max=\"1000\"")
                shell!("crm configure property pe-input-series-max=\"1000\"")
                shell!("crm configure property pe-error-series-max=\"1000\"")
                shell!("crm configure property cluster-recheck-interval=\"5min\"")
                shell!("crm configure property stonith-enabled=\"false\"")
            end
            action :nothing
            subscribes :run, "script[restart cluster node services]", :immediately
        end
    end
end

include_recipe 'openstack-common::openrc'
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

## Create/Update service configuration ini files

template '/etc/neutron/dhcp_agent.ini' do
    source 'dhcp_agent.ini.erb'
    cookbook 'openstack-network'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644
    if is_clustered
        notifies :run, "ruby_block[start cluster DHCP agent service]", :delayed if do_init_cluster
    else
        notifies :restart, "service[neutron-dhcp-agent]"
    end
end

template '/etc/neutron/dnsmasq.conf' do
    source 'dnsmasq.conf.erb'
    cookbook 'openstack-network'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644
    if is_clustered
        notifies :run, "ruby_block[start cluster DHCP agent service]", :delayed if do_init_cluster
    else
        notifies :restart, "service[neutron-dhcp-agent]"
    end
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
    if is_clustered
        notifies :run, "ruby_block[start cluster L3 agent service]", :delayed if do_init_cluster
    else
        notifies :restart, "service[neutron-metadata-agent]"
    end
end

template '/etc/neutron/l3_agent.ini' do
    source 'l3_agent.ini.erb'
    cookbook 'openstack-network'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644
    if is_clustered
        notifies :run, "ruby_block[start cluster L3 agent service]", :delayed if do_init_cluster
    else
        notifies :restart, "service[neutron-l3-agent]"
    end
end

## Start services

if is_clustered

    dns_servers = shell("cat /etc/resolv.conf | awk '/nameserver/ { print $2 }'").split
    Chef::Application.fatal!("Unable to determine DNS host for l3 agent router external connectivity test.") if dns_servers.size==0

    template "/etc/corosync/crm_configure_dhcp_agent.sh" do
        source 'crm_configure_dhcp_agent.sh.erb'
        mode 00744
        notifies :run, "ruby_block[start cluster DHCP agent service]", :delayed if do_init_cluster
    end

    template "/etc/corosync/crm_configure_l3_agent.sh" do
        source 'crm_configure_l3_agent.sh.erb'
        mode 00744
        variables(
            dns_server: dns_servers[0]
        )
        notifies :run, "ruby_block[start cluster L3 agent service]", :delayed if do_init_cluster
    end

    ruby_block "start cluster DHCP agent service" do
        block do
            shell!("/etc/corosync/crm_configure_dhcp_agent.sh 1>/var/log/neutron/crm_configure_dhcp_agent.log 2>&1 3>&1")
        end
        action :nothing
    end
    ruby_block "start cluster L3 agent service" do
        block do
            shell!("/etc/corosync/crm_configure_l3_agent.sh 1>/var/log/neutron/crm_configure_l3_agent.log 2>&1 3>&1")
        end
        action :nothing
    end

else
    service 'neutron-dhcp-agent' do
        service_name platform_options['neutron_dhcp_agent_service']
        supports status: true, restart: true
        action :enable
        subscribes :restart, 'template[/etc/neutron/neutron.conf]'
    end

    service 'neutron-metadata-agent' do
        service_name platform_options['neutron_metadata_agent_service']
        supports status: true, restart: true
        action :enable
        subscribes :restart, 'template[/etc/neutron/neutron.conf]'
    end

    service 'neutron-l3-agent' do
        service_name platform_options['neutron_l3_agent_service']
        supports status: true, restart: true
        action :enable
        subscribes :restart, 'template[/etc/neutron/neutron.conf]'
    end
end

#
# Cookbook Name:: openstack-services
# Recipe:: ha-os-loadbalancer
#
# Author: Mevan Samaratunga
# Email: mevansam@gmail.com
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

haproxy_user = node['haproxy']['user']
haproxy_group = node['haproxy']['group']

group haproxy_group

user haproxy_user do
    supports :manage_home => true
    home '/home/' + haproxy_user
    gid haproxy_group
end

chroot = node['haproxy']['global_parameters']['chroot']
directory chroot do
    owner haproxy_user
    group haproxy_group
    recursive true
    mode '0400'
    not_if { chroot.nil? }
end

# Setup certs for ssl termination

cert_path = node['haproxy']['conf_dir'] + '/certs'
directory cert_path do
    recursive true
end

node['haproxy']['certificate_databag_items'].each do |name, data_bag_item|

    encryption_key = ::SysUtils::get_encryption_secret(node)
    certificates = Chef::EncryptedDataBagItem.load(
        "certificates-#{node.chef_environment}", data_bag_item, encryption_key )

    file "#{cert_path}/#{name}.pem" do
        owner "root"
        group "root"
        mode "0644"
        content "#{certificates["cert"]}#{certificates["key"]}#{certificates["cacert"]}"
    end
end

profiles = node['haproxy']['profiles']
server_pools = node['haproxy']['server_pools']

server_pools.each do |name, config|

    unless config['cluster_role'].nil?


        if config['port']
            port = config['port']
        else
            openstack_endpoint = node['openstack']['endpoints'][name]
            Chef::Application.fatal!("Unable to locate openstack endpoint configuration for '#{name}'.") \
                if openstack_endpoint.nil?

            port = openstack_endpoint['port']
        end

        profile = profiles[config['profile']]
        Chef::Application.fatal!("No profile found for '#{name}': #{config}") \
            if profile.nil?

        params = [ ]

        bind_options = profile['bind_options'] || [ ]
        bind_options += config['bind_options'].reject { |v| bind_options.include?(v) } \
            if config.has_key?('bind_options')

        bind_address = config['bind_address'] || '0.0.0.0'
        bind_port = config['bind_port'] || port
        bind_ssl = config['bind_ssl']

        params[0] = "bind #{bind_address}:#{bind_port} " + bind_options.join(' ') +
            (bind_ssl.nil? ? '' : "ssl crt #{cert_path}/#{bind_ssl}.pem")

        profile.each do |k, v|

            case k
                when 'bind_options'
                    # Do Nothing
                when 'member_options'
                    # Do Nothing
                when 'params'
                    params += v
                else
                    params << "#{k} #{v}"
            end
        end

        member_options = Hash.new
        member_options.merge!(profile['member_options']) if profile.has_key?('member_options')
        member_options.merge!(config['member_options']) if config.has_key?('member_options')

        pool_query = "role:#{config['cluster_role']} AND chef_environment:#{node.chef_environment}"
        Chef::Log.info("Pool search for '#{name}': #{pool_query}")

        pool_members = search(:node, pool_query)

        if pool_members.nil? || pool_members.size==0
            pool_members = [ { :ipaddress => node['haproxy']['backend_default_ip'], :hostname => 'default' } ]
        else
            pool_members.map! do |member|

                server_ip = begin
                    if member.attribute?('cloud')
                        if node.attribute?('cloud') && (member['cloud']['provider'] == node['cloud']['provider'])
                            member['cloud']['local_ipv4']
                        else
                            member['cloud']['public_ipv4']
                        end
                    else
                        member['ipaddress']
                    end
                end

                { :ipaddress => server_ip, :hostname => member['hostname'] }
            end
        end

        pool_members.sort! do |a,b|
            a[:hostname].downcase <=> b[:hostname].downcase
        end

        i = 0
        pool_members.uniq.each do |s|

            j = i.to_s
            i += 1

            member_option = member_options.has_key?(j) ? member_options[j]
                : member_options.has_key?('*') ? member_options['*'] : ''

            params << "server #{s[:hostname]} #{s[:ipaddress]}:#{port} #{member_option}"
        end

        Chef::Log.info("Adding server pool '#{name}': #{params}")

        haproxy_lb name do
            type 'listen'
            params params
        end

    else
        Chef::Log.warn("Skipping pool '#{name}' as a cluster role to use to search for nodes was not given.")
    end
end

include_recipe 'haproxy::default'

# Override default template in haproxy cookbook
template = resources(template: "#{node['haproxy']['conf_dir']}/haproxy.cfg")
template.cookbook('openstack-services')
template.source('haproxy.cfg.erb')

# Set-up virtual IP DNS name mapping
dns_entry node['openstack']['openstack_ha_proxy'] do
    address node['haproxy']['virtual_ip']
end

if node['haproxy']['is_clustered']

    include_recipe 'sysutils::cluster'

    do_init_cluster = !node["cluster_initializing_node"].nil? && node["cluster_initializing_node"]
    Chef::Log.info("Cluster initializing node: #{node["hostname"]}/#{do_init_cluster}")

    if do_init_cluster

        ruby_block "configure common crm properties" do
            block do
                shell!("crm configure property stonith-enabled=\"false\"")
                shell!("crm configure property expected-quorum-votes=\"2\"")
                shell!("crm configure property no-quorum-policy=\"ignore\"")
                shell!("crm configure rsc_defaults resource-stickiness=\"100\"")
                shell!("crm configure property pe-warn-series-max=\"1000\"")
                shell!("crm configure property pe-input-series-max=\"1000\"")
                shell!("crm configure property pe-error-series-max=\"1000\"")
                shell!("crm configure property cluster-recheck-interval=\"5min\"")
            end
            action :nothing
            subscribes :run, "script[restart cluster node services]", :immediately
        end

        template "/etc/corosync/crm_configure_ipaddr2.sh" do
            source 'crm_configure_ipaddr2.sh.erb'
            mode 00744
            notifies :run, "ruby_block[start cluster IPaddr2 service]", :delayed
            not_if { node["haproxy"]["virtual_ip_address"].nil? }
        end

        ruby_block "start cluster IPaddr2 service" do
            block do
                shell!("/etc/corosync/crm_configure_ipaddr2.sh 1>/etc/corosync/crm_configure_ipaddr2.log 2>&1 3>&1")
            end
            action :nothing
        end
    end
end
#
# Cookbook Name:: openstack-services
# Recipe:: ha-messaging
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

encryption_key = ::SysUtils::get_encryption_secret(node)
rabbit_passwords = Chef::EncryptedDataBagItem.load("passwords-#{node.chef_environment}", "rabbit", encryption_key)

node.override['rabbitmq']['erlang_cookie'] = rabbit_passwords["erlang_cookie"]

default_user = rabbit_passwords["default_user"]
default_password = rabbit_passwords["default_password"]

node.override['rabbitmq']['default_user'] = default_user
node.override['rabbitmq']['default_pass'] = default_password

if node['rabbitmq']['ssl']
    !node["rabbitmq"]["certificate_databag_item"].nil? &&
    !node["rabbitmq"]["certificate_databag_item"].empty?

	certificates = Chef::EncryptedDataBagItem.load("certificates-#{node.chef_environment}", node["rabbitmq"]["certificate_databag_item"], encryption_key)

	rabbit_config_path = node["rabbitmq"]['config_root']
	directory rabbit_config_path

	cacert_path = "#{rabbit_config_path}/cacert.pem"
	cert_path = "#{rabbit_config_path}/cert.pem"
	key_path = "#{rabbit_config_path}/key.pem"

    file cacert_path do
        owner "root"
        group "root"
        mode "0644"
        content certificates["cacert"]
    end
    
    file cert_path do
        owner "root"
        group "root"
        mode "0644"
        content certificates["cert"]
    end
    
    file key_path do
        owner "root"
        group "root"
        mode "0644"
        content certificates["key"]
    end

	node.override['rabbitmq']['ssl_cacert'] = cacert_path
	node.override['rabbitmq']['ssl_cert'] = cert_path
	node.override['rabbitmq']['ssl_key'] = key_path
end

# Determine which nodes are in rabbitmq cluster
cluster_role = node["rabbitmq"]["cluster_role"]
cluster_disk_nodes = []

unless Chef::Config[:solo]
    search(:node, "role:#{cluster_role} AND chef_environment:#{node.chef_environment}").each do |rabbitmq_node|
        
        Chef::Log.info("Found cluster node '#{rabbitmq_node.name}' for role '#{cluster_role}': rabbit@$#{rabbitmq_node['hostname']}")
        cluster_disk_nodes << "rabbit@$#{rabbitmq_node['hostname']}" 
    end
end

node.override['rabbitmq']['cluster_disk_nodes'] = cluster_disk_nodes

include_recipe 'rabbitmq::default'
include_recipe 'rabbitmq::mgmt_console'
include_recipe 'rabbitmq::virtualhost_management'
include_recipe 'rabbitmq::policy_management'

node['rabbitmq']['virtualhosts'].each do |virtualhost|
    rabbitmq_user default_user do
        vhost virtualhost
        permissions ".* .* .*"
        action :set_permissions
    end
end

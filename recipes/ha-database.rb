#
# Cookbook Name:: openstack-services
# Recipe:: ha-database
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

class ::Chef::Recipe # rubocop:disable Documentation
    include ::Openstack
end

# Setup certs for MySql ssl configuration
if node["percona"]["mysql"]["ssl"] &&
    !node["percona"]["mysql"]["certificate_databag_item"].nil? &&
    !node["percona"]["mysql"]["certificate_databag_item"].empty?

    encryption_key = get_encryption_secret
    certificates = Chef::EncryptedDataBagItem.load( "certificates-#{node.chef_environment}", 
        node["percona"]["mysql"]["certificate_databag_item"], encryption_key )

    mysql_config_path = node["percona"]["mysql"]["config_path"]
    directory mysql_config_path

    cacert_path = "#{mysql_config_path}/cacert.pem"
    cert_path = "#{mysql_config_path}/cert.pem"
    key_path = "#{mysql_config_path}/key.pem"

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

    include_dir = node["percona"]["server"]["includedir"]
    directory include_dir

    template "#{include_dir}/mysql_ssl.cnf" do
        source "mysql_ssl.cnf.erb"
        mode "0644"
        variables(
            :cacert => cacert_path,
            :cert => cert_path,
            :key => key_path
        )
    end
end

# If extra storage was provided use that as the data path
node.override["percona"]["server"]["datadir"] = node["env"]["data_path"] \
    if node["env"].has_key?("data_path") && !node["env"]["data_path"].empty?

# Set encrypted password databag by environment
node.override["percona"]["encrypted_data_bag"] = "passwords-#{node.chef_environment}"

# Setup the Percona XtraDB Cluster
cluster_role = node["percona"]["cluster_role"]
cluster_ips = []
unless Chef::Config[:solo]
    search(:node, "role:#{cluster_role}").each do |other_node|
        
        Chef::Log.info("Found cluster node '#{other_node.name}' for role '#{cluster_role}'.")

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
Chef::Log.info("Using Percona XtraDB cluster address of: #{cluster_address}")
node.override["percona"]["cluster"]["wsrep_cluster_address"] = cluster_address
node.override["percona"]["cluster"]["wsrep_node_name"] = node['hostname']

include_recipe 'percona::cluster'
include_recipe 'percona::backup'
include_recipe 'percona::toolkit'

# Grant root access to servers in whitelist
server_white_list = node["percona"]["mysql"]["server_white_list"]

if !server_white_list.nil? && server_white_list.size > 0

    Chef::Log.info("White listing the following servers for root access: #{server_white_list}")
    passwords = EncryptedPasswords.new(node, node["percona"]["encrypted_data_bag"])

    template "/etc/mysql/server_white_list.sql" do
        source "server_white_list.sql.erb"
        variables(
            server_while_list: server_white_list,
            root_password: passwords.root_password
        )
        owner "root"
        group "root"
        mode "0600"
    end

    execute "mysql-set-server-white-list" do
        command "/usr/bin/mysql -p'#{passwords.root_password}' -e '' &> /dev/null > /dev/null &> /dev/null ; if [ $? -eq 0 ] ; then /usr/bin/mysql -p'#{passwords.root_password}' < /etc/mysql/server_white_list.sql ; else /usr/bin/mysql < /etc/mysql/server_white_list.sql ; fi ;" # rubocop:disable LineLength
        action :nothing
        subscribes :run, resources("template[/etc/mysql/server_white_list.sql]"), :immediately
    end

end

# Create openstack databases
openstack_proxy = node["env"]["openstack_proxy"]
openstack_proxy_name = openstack_proxy.split('.').first

node.set["env"]["skip_upstart_patch"] = true
include_recipe "openstack-services::ha-os-common"

node["percona"]["openstack"]["services"].each do |service|

    db_user = node['openstack']['db'][service]['username']
    db_name = node['openstack']['db'][service]['db_name']
    db_password = get_password('db', db_name)

    script "Creating database '#{db_name} for service #{service} with user/passwd '#{db_user}." do
        interpreter "bash"
        user "root"
        cwd "/tmp"
        code <<-EOH

            db_exists=$(mysql -e "SHOW DATABASES" | grep #{db_name})
            if [ -z "$db_exists" ]; then

                mysql -e " \
                    GRANT USAGE ON *.* TO '#{db_user}'@'localhost'; \
                    DROP USER '#{db_user}'@'localhost'; \
                    DROP DATABASE IF EXISTS #{db_name};"

                mysql -e " \
                    CREATE DATABASE #{db_name}; \
                    GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@'#{openstack_proxy}' IDENTIFIED BY '#{db_password}'; \
                    GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@'#{openstack_proxy_name}' IDENTIFIED BY '#{db_password}'; \
                    GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@'localhost' IDENTIFIED BY '#{db_password}'; \
                    GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@'%' IDENTIFIED BY '#{db_password}';"
            fi
        EOH
    end
end

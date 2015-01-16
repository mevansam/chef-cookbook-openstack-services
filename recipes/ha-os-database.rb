#
# Cookbook Name:: openstack-services
# Recipe:: ha-database
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
    include ::Openstack
end

# Include the Percona cluster recipe
include_recipe "cluster::percona"

# Attribute 'cluster_initializing_node' is set by 'cluster::percona' recipe.
cluster_initializing_node = node["cluster_initializing_node"]

if cluster_initializing_node.nil? || cluster_initializing_node

    ## Create openstack databases

    openstack_proxy = node["openstack"]["openstack_ops_proxy"]
    openstack_proxy_name = (openstack_proxy=~/\d+\.\d+\.\d+\.\d+/ ? openstack_proxy : openstack_proxy.split('.').first)

    node['openstack']['db'].each do |service, config|

        next unless config.is_a?(Hash)

        unless config['created']

            db_user = config['username']
            db_name = config['db_name']

            next if db_user.nil? || db_name.nil?

            begin
                db_password = get_password('db', db_name)
            rescue
                # If data bag is not found we simply continue
                next
            end

            ruby_block "flag database for service '#{service}' was installed successfully" do
                block do
                    node.set['openstack']['db'][service]['created'] = true
                    node.save
                end
                action :nothing
            end

            script "Creating database '#{db_name}' for service '#{service}' with user/passwd '#{db_user}'." do
                interpreter "bash"
                user "root"
                cwd "/tmp"
                code <<-EOH

                    mysql -e " \
                        GRANT USAGE ON *.* TO '#{db_user}'@'localhost'; \
                        DROP USER '#{db_user}'@'localhost'; \
                        DROP DATABASE IF EXISTS #{db_name};"

                    [ $? -eq 0 ] || exit $?

                    mysql -e " \
                        CREATE DATABASE #{db_name}; \
                        GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@'#{openstack_proxy}' IDENTIFIED BY '#{db_password}'; \
                        GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@'#{openstack_proxy_name}' IDENTIFIED BY '#{db_password}'; \
                        GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@'localhost' IDENTIFIED BY '#{db_password}'; \
                        GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@'%' IDENTIFIED BY '#{db_password}';"

                    [ $? -eq 0 ] || exit $?
                EOH
                notifies :create, resources(:ruby_block => "flag database for service '#{service}' was installed successfully"), :immediately
            end
        end
    end
end
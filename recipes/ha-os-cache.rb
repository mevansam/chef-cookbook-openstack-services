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

# Determine which nodes are in the cache cluster
cluster_name = node["openstack"]["memcached"]["cluster_name"]
unless cluster_name.nil?

    memcached_servers = []

    search_query = "cluster_name:#{cluster_name} AND chef_environment:#{node.chef_environment}"
    Chef::Log.info("Searching for memcached cluster nodes matching: #{search_query}")

    search(:node, search_query).each do |memcached_node|

        Chef::Log.info("Adding node '#{memcached_node.name}' as memcached node.")

        memcached_port = memcached_node["memcached"] ? memcached_node["memcached"]["port"] || "11211" : "11211"
        memcached_servers << "#{memcached_node["ipaddress"]}:#{memcached_port}"
    end
    memcached_servers.sort!
    
    node.override['openstack']["memcached_servers"] = memcached_servers
end

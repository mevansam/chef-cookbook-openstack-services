#
# Cookbook Name:: openstack-services
# Recipe:: ha-proxy
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

# Iterate over the haproxy server pools and add openstack 
# service ports retrieved from openstack configuration

server_pools = node['haproxy']['server_pools']

server_pools.each do |name, config|

	if config['port'].nil?

        openstack_endpoint = node['openstack']['endpoints'][name]
        Chef::Application.fatal!("Unable to locate openstack endpoint configuration for '#{name}'.") \
            if openstack_endpoint.nil?

        node.set['haproxy']['server_pools'][name]['port'] = openstack_endpoint['port']
	end
end
node.save

# Include the HAproxy cluster recipe
include_recipe "cluster::haproxy"

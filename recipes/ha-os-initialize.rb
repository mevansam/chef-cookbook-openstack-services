#
# Cookbook Name:: openstack-services
# Recipe:: initialize
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

# Determine the iniitializing node from a collection of cluster nodes
cluster_name = node["cluster_name"]

if cluster_name.nil?
	initializing_node = true
else
	search_query = "cluster_name:#{cluster_name} AND chef_environment:#{node.chef_environment}"
	Chef::Log.info("Searching for cluster nodes matching: #{search_query}")

	initializing_node_name = nil

	search(:node, search_query).each do |openstack_node|

	    # Pick the initializing node to be the lowest order node name
	    initializing_node_name = openstack_node.name \
	        if initializing_node_name.nil? || openstack_node.name<initializing_node_name
	end

	initializing_node = (initializing_node_name==node.name)
end

if initializing_node && !node["openstack"]["initialized"]

	# Run all the openstack initializing recipes if not already in the nodes runlist

	include_recipe "openstack-identity::registration" \
		if node.recipe?("openstack-identity::server") && !node.recipe?("openstack-identity::registration")
	include_recipe "openstack-image::identity_registration" \
		if node.recipe?("openstack-image::api") && !node.recipe?("openstack-image::identity_registration")
	include_recipe "openstack-block-storage::identity_registration" \
		if node.recipe?("openstack-block-storage::api") && !node.recipe?("openstack-block-storage::identity_registration")
	include_recipe "openstack-compute::identity_registration" \
		if node.recipe?("openstack-compute::api-os-compute") && !node.recipe?("openstack-compute::identity_registration")
	include_recipe "openstack-network::identity_registration" \
		if node.recipe?("openstack-network::server") && !node.recipe?("openstack-network::identity_registration")

	include_recipe "openstack-compute::nova-setup" \
		if node.recipe?("openstack-compute::api-os-compute") && !node.recipe?("openstack-compute::nova-setup")

	node.set["openstack"]["initialized"] = true
end

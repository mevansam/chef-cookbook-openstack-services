#
# Cookbook Name:: openstack-services
# Recipe:: xenserver
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

class ::Chef::Recipe # rubocop:disable Documentation
    include ::SysUtils::Helper
    include ::Openstack::Xen
end

copy_plugins("nova", node["openstack"]["compute"]["source_url"])
copy_plugins("neutron", node["openstack"]["network"]["source_url"])

# If more than one Xen node in this cluster then retrieve 
# shared settings from the one of the other nodes
cluster_role = node["openstack"]["xen"]["cluster_role"]

sr_uuid = nil
unless Chef::Config[:solo]
    search(:node, "role:#{cluster_role} AND chef_environment:#{node.chef_environment}").each do |xen_node|
        
        next if xen_node['ipaddress']==node['ipaddress']

        sr_uuid = (xen_node["xenserver"].nil? ? nil : xen_node["xenserver"]["storage"]["nfs"]["uuid"])
        if !sr_uuid.nil?
            Chef::Log.info("Found shared SR with uuid '#{sr_uuid}'.")
            break
        end
    end
end

sr_name = node['openstack']['xen']['storage']["name"]
Chef::Application.fatal!("The default storage name must be provided.", 999) if sr_name.nil? || sr_name.empty?

nfs_server = node["openstack"]["xen"]["storage"]["nfs_server"]
nfs_path = node["openstack"]["xen"]["storage"]["nfs_serverpath"]

# Create shared directores used by OpenStack
ruby_block "creating shared support directories used by openstack" do
    block do
        sr_uuid = node["xenserver"]["storage"]["nfs"]["uuid"]
        if !sr_uuid.nil?
            guest_kernel_dir="/var/run/sr-mount/#{sr_uuid}/os-guest-kernels"
            shell_out!("mkdir -p \"#{guest_kernel_dir}\"");
            image_dir="/var/run/sr-mount/#{sr_uuid}/images"
            shell_out!("mkdir -p \"#{image_dir}\"");
        else
            Chef::Application.fatal!("No valid shared NFS storage uuid found for the node.", 999)
        end
    end
    action :nothing
end

# Link shared directores used by OpenStack
ruby_block "linking support directories used by openstack" do
    block do
        sr_uuid = node["xenserver"]["storage"]["nfs"]["uuid"]
        if !sr_uuid.nil?
            guest_kernel_dir="/var/run/sr-mount/#{sr_uuid}/os-guest-kernels"
            image_dir="/var/run/sr-mount/#{sr_uuid}/images"
            shell_out!("rm -f \"/boot/guest\" && ln -s \"#{guest_kernel_dir}\" \"/boot/guest\"");
            shell_out!("rm -f \"/images\" && ln -s \"#{image_dir}\" \"/images\"");
        else
            Chef::Application.fatal!("No valid shared NFS storage uuid found for the node.", 999)
        end
    end
    action :nothing
end

# Create new shared storage repository
storage sr_name do
    type         "nfs"
    default      true
    nfs_server   nfs_server
    nfs_path     nfs_path
    other_config(
        "i18n-key" => "local-storage"
    )
    action       :create
    notifies     :create, "ruby_block[creating shared support directories used by openstack]"
    notifies     :create, "ruby_block[linking support directories used by openstack]"
    only_if      { sr_uuid.nil? }
end

# Attach to the storage repository already created for the OpenStack Xen cluster
storage sr_name do
    uuid         sr_uuid
    type         "nfs"
    default      true
    nfs_server   nfs_server
    nfs_path     nfs_path
    other_config(
        "i18n-key" => "local-storage"
    )
    action       :attach
    notifies     :create, "ruby_block[linking support directories used by openstack]"
    only_if      { !sr_uuid.nil? }
end

# Attach to shared ISO storage
shared_iso_name = node['openstack']['xen']['storage']["shared_iso_name"]

storage shared_iso_name do
    type       "iso"
    nfs_server nfs_server
    nfs_path   nfs_path
    only_if    { !shared_iso_name.nil? }
end

# Upload default image template to Xen Server
default_template = node['openstack']['xen']["default_template"]
if !default_template.nil? && !default_template.empty?

    ruby_block "uploading template #{default_template}" do
        block do
            sr_uuid = node["xenserver"]["storage"]["nfs"]["uuid"]        
            iso_sr_uuid = node["xenserver"]["storage"]["iso"]["uuid"]
            template_file = "/var/run/sr-mount/#{iso_sr_uuid}/#{default_template}.ova"        
            shell_out!("xe vm-import filename=#{template_file} sr-uuid=#{sr_uuid}") if File.exists?(template_file)
        end
        only_if { shell("xe template-list name-label=\"#{default_template}\" --minimal").empty? }
    end
end

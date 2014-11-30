#
# Cookbook Name:: openstack-services
# Recipe:: xenserver
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
    include ::OpenStack::Xen
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

## Configure Xen Networking

script "set up ip forwarding" do
    interpreter "bash"
    user "root"
    cwd "/tmp"
    code <<-EOH
        if [ -a /etc/sysconfig/network ]; then
            if ! grep -q "FORWARD_IPV4=YES" /etc/sysconfig/network; then
                # FIXME: This doesn't work on reboot!
                echo "FORWARD_IPV4=YES" >> /etc/sysconfig/network
            fi
        fi
        echo 1 > /proc/sys/net/ipv4/ip_forward
    EOH
end

public_interface_name = node['openstack']['xen']['network']['public_interface']['name']
public_interface_device = node['openstack']['xen']['network']['public_interface']['device']
public_interface_mode = node['openstack']['xen']['network']['public_interface']['mode']

if public_interface_device.kind_of?(Array)
    if public_interface_device.size > 0
        network_interface public_interface_name do
            type               "bond"
            mac_address_prefix "00:00:02:"
            bond_devices       (public_interface_device.first.start_with?("eth") ? public_interface_device : public_interface_device.first)
            bond_mode          public_interface_mode
        end
    else
        Chef::Application.fatal!("Bond device list or search string was not provided.", 999)
    end
else
    network_interface public_interface_name do
        type "device"
        device public_interface_device
    end
end

data_network = node["openstack"]["xen"]["data_network"]["name"]

node["openstack"]["xen"]["network"]["vlans"].each do |vlan|

    if vlan["name"] == data_network

        dns_servers = node["openstack"]["xen"]["data_network"]["dns"].split.join(",")
        
        network_interface "#{vlan["name"]}" do
            type            "vlan"
            device_network  public_interface_name
            vlan            "#{vlan["vlan"]}"

            ip_address      node["openstack"]["xen"]["data_network"]["ip"]
            gateway_address node["openstack"]["xen"]["data_network"]["gateway"]
            network_mask    node["openstack"]["xen"]["data_network"]["netmask"]
            dns_servers     dns_servers
        end
    else
        network_interface "#{vlan["name"]}" do
            type           "vlan"
            device_network public_interface_name
            vlan           "#{vlan["vlan"]}"
        end
    end
end

xen_trunk_network = node['openstack']['xen']['network']['xen_trunk_network']
network xen_trunk_network do
    notifies :create, "ruby_block[set up trunk bridge]"
end

ruby_block "set up trunk bridge" do
    block do
        trunk_bridge = shell("xe network-list name-label=#{xen_trunk_network} params=bridge --minimal")
        Chef::Application.fatal!("Xen trunk network #{xen_trunk_network} does not exist.") if trunk_bridge.empty?

        public_bridge = shell("xe network-list name-label=#{public_interface_name} params=bridge --minimal")
        Chef::Application.fatal!("Xen public network #{public_interface_name} does not exist.") if public_bridge.empty?

        patch_trunk_public = "patch-#{trunk_bridge}-#{public_bridge}"
        shell!("ovs-vsctl --timeout=10 -- --if-exists del-port #{trunk_bridge} #{patch_trunk_public}")

        patch_public_trunk = "patch-#{public_bridge}-#{trunk_bridge}"
        shell!("ovs-vsctl --timeout=10 -- --if-exists del-port #{public_bridge} #{patch_public_trunk}")

        shell!( "ovs-vsctl --timeout=10 " + 
            "-- --may-exist add-port #{trunk_bridge} #{patch_trunk_public} " + 
            "-- set Interface #{patch_trunk_public} type=patch options:peer=#{patch_public_trunk}" )

        shell!( "ovs-vsctl --timeout=10 " + 
            "-- --may-exist add-port #{public_bridge} #{patch_public_trunk} " + 
            "-- set Interface #{patch_public_trunk} type=patch options:peer=#{patch_trunk_public}" )
    end
end

xen_int_network = node['openstack']['xen']['network']['xen_int_network']
network xen_int_network

mgt_net_uuid = get_management_network
mgt_net_name = get_network_name(mgt_net_uuid)
mgt_net_bridge = get_network_bridge(mgt_net_uuid)
Chef::Log.debug("The management network name is '#{mgt_net_name}' and bridge is '#{mgt_net_bridge}'.")

host_ip = xenapi_ip_on(mgt_net_bridge)
Chef::Application.fatal!( "XenAPI does not have an assigned IP address on the management network. " + 
    "please review your XenServer network configuration", 999) if host_ip.empty?

Chef::Log.debug("The management host IP is '#{host_ip}'.")

## Create DomU OpenStack compute VM

vm_name = node['openstack']['xen']['vm']["name"]

ruby_block "create domu openstack compute guest" do
    block do
        xen_trunk_net_uuid = shell("xe network-list name-label=#{xen_trunk_network} params=uuid minimal=true")
        xen_trunk_network_bridge = shell("xe network-list uuid=#{xen_trunk_net_uuid} params=bridge --minimal")

        Chef::Application.fatal!("Unable to determine the Xen physical bridge name to use for external connectivity") if xen_trunk_network_bridge.empty?
        node.set['openstack']['xen']['network']['xen_trunk_network_bridge'] = xen_trunk_network_bridge

        xen_int_net_uuid = shell("xe network-list name-label=#{xen_int_network} params=uuid minimal=true")
        xen_int_network_bridge = shell("xe network-list uuid=#{xen_int_net_uuid} params=bridge --minimal")

        Chef::Application.fatal!("Unable to determine the Xen integration bridge name to use for external connectivity") if xen_int_network_bridge.empty?
        node.set['openstack']['xen']['network']['xen_int_network_bridge'] = xen_int_network_bridge

        vm = resources("vm[#{vm_name}]")
        vm.kernel_args "hostip=#{node["openstack"]["xen"]["data_network"]["ip"]} hostname=#{node["hostname"]} " + 
            "xentrunkbridge=#{xen_trunk_network_bridge} xenintbridge=#{xen_int_network_bridge}"
    end
end

vm vm_name do

    description "OpenStack DomU Compute (Nova+Neutron) VM"

    template node['openstack']['xen']['vm']['template']
    cpus     node['openstack']['xen']['vm']['cpus']
    memory   node['openstack']['xen']['vm']['memory']
    network  [ node['openstack']['xen']['vm']['network'], public_interface_name ]

    address node['openstack']['xen']['vm']['ip']
    gateway node['openstack']['xen']['vm']['gateway']
    netmask node['openstack']['xen']['vm']['netmask']
    domain node['openstack']['xen']['vm']['domain']
    dns_servers node['openstack']['xen']['vm']['dns']
end

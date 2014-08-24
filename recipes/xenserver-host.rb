#
# Cookbook Name:: openstack-services
# Recipe:: post-install
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

cache_dir=Chef::Config[:file_cache_path]

release=node['openstack']['release']

nova_source_url = node['openstack']['compute']['source_url']
if nova_source_url.end_with?(".git")
	# Construct location to download nova from git repository stable branch
	nova_source_url = nova_source_url.sub(/\.git$/, '') + "/archive/stable/" + release + ".zip"

elsif !nova_source_url.end_with(".zip")
	Chef::Application.fatal!( "The 'source_url' attribute must either point to a github repository " + 
		"where a stable release can be downloaded from or a downloadable zip archive." )
end

Chef::Log.info("Downloading xen plugins from: #{nova_source_url}")

source_zip = "#{cache_dir}/nova-#{release}.zip"
remote_file "#{source_zip}" do
	source nova_source_url
end

script "copying xen nova plugins to xen host plugin location" do
    interpreter "bash"
    user "root"
    cwd "/tmp"
    code <<-EOH

    	NOVA_SOURCES=$(mktemp -d)
    	unzip "#{source_zip}" -d "$NOVA_SOURCES"
    	PLUGINPATH=$(find $NOVA_SOURCES -path '*/xapi.d/plugins' -type d -print)

    	[ -e /etc/xapi.d/plugins.bak ] || (cp -r /etc/xapi.d/plugins /etc/xapi.d/plugins.bak)
    	[ -z "$PLUGINPATH" ] || (cp -f $PLUGINPATH/* /etc/xapi.d/plugins/)
    	rm -fr $NOVA_SOURCES
    EOH
    only_if { !File.exists?("/etc/xapi.d/plugins/xenhost") ||
    	File.ctime(source_zip) > File.ctime("/etc/xapi.d/plugins/xenhost") }
end

if node['openstack']['xen']['default_storage_repository']

	script "creating support directories" do
	    interpreter "bash"
	    user "root"
	    cwd "/tmp"
	    code <<-EOH
	    	SR_UUID=$(xe sr-list name-label="#{node['openstack']['xen']['default_storage_repository']}" --minimal)

	    	GUEST_KERNEL_DIR="/var/run/sr-mount/$SR_UUID/os-guest-kernels"
	    	mkdir -p "$GUEST_KERNEL_DIR"
	    	[ -h "/boot/guest" ] || (ln -s "$GUEST_KERNEL_DIR" /boot/guest)

	    	IMAGE_DIR="/var/run/sr-mount/$SR_UUID/images"
	    	mkdir -p "$IMAGE_DIR"
	    	[ -h "/images" ] || (ln -s "$IMAGE_DIR" /images)
    	EOH
	end
end

#
# Cookbook Name:: openstack-services
# Library:: xen
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

module ::OpenStack # rubocop:disable Documentation

    module Xen # rubocop:disable Documentation

        # Copy xapi plugins to correct location.
        #
        # @param [String] name of openstack component
        # @param [String] plugin source location
        def copy_plugins(name, plugin_source_url)

            return if plugin_source_url.nil?

            release = node['openstack']['release']

            source_url = nil
            if plugin_source_url.index("https://github.com/") && plugin_source_url.end_with?(".git")
                # Construct location to download nova from git repository stable branch
                source_url = plugin_source_url.sub(/\.git$/, '') + "/archive/stable/" + release + ".zip"

            elsif !plugin_source_url.end_with(".zip")
                Chef::Application.fatal!( "The given url '#{plugin_source_url}' attribute must either point to a github " + 
                    "repository where a stable release can be downloaded from or a downloadable zip archive." )
            end

            xapi_plugin_dir = Dir.exists?( "/etc/xapi.d/plugins") ? "/etc/xapi.d/plugins" :
                Dir.exists?("/usr/lib/xcp/plugins") ? "/usr/lib/xcp/plugins" :
                Dir.exists?("/usr/lib/xapi/plugins") ? "/usr/lib/xapi/plugins" : nil

            Chef::Application.fatal!("Unable to determine xapi plugin directoruy.") if xapi_plugin_dir.nil?
            Chef::Log.debug("XAPI plugin directory is '#{xapi_plugin_dir}'.")

            source_zip = "#{Chef::Config[:file_cache_path]}/#{name}-#{release}.zip"
            remote_file "#{source_zip}" do
                source source_url
                notifies :run, "script[copy '#{name}' plugins to '#{xapi_plugin_dir}']"
            end

            script "copy '#{name}' plugins to '#{xapi_plugin_dir}'" do
                interpreter "bash"
                user "root"
                cwd "/tmp"
                code <<-EOH

                    SOURCES=$(mktemp -d)
                    unzip "#{source_zip}" -d "$SOURCES"
                    PLUGINPATH=$(find $SOURCES -path '*/xapi.d/plugins' -type d -print)
                    if [ -n $PLUGINPATH ]; then
                        
                        [ -e #{xapi_plugin_dir}.bak ] || (cp -r #{xapi_plugin_dir} #{xapi_plugin_dir}.bak)
                        rsync -avr $PLUGINPATH/* #{xapi_plugin_dir}
                    fi
                    rm -fr $SOURCES
                EOH
                action :nothing
            end
        end

        def get_management_network
            return shell("xe pif-list management=true params=network-uuid minimal=true")
        end

        def get_network_name(uuid)
            return shell("xe network-list uuid=#{uuid} params=name-label minimal=true")
        end

        def get_network_bridge(uuid)
            return shell("xe network-list uuid=#{uuid} params=bridge --minimal")
        end

        def xenapi_ip_on(bridge)
            mgt_ip = shell("ifconfig \"#{bridge}\" | awk '/inet addr/ { print substr($2,6) }'")
            return mgt_ip
        end
    end
end

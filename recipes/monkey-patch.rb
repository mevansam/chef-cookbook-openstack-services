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

############################################################################
# Work around for bug https://bugs.launchpad.net/openstack-chef/+bug/1313646
# This code should be removed when chef client 11.14 is available
if node["platform"]=='ubuntu' && node["platform_version"].to_f>=14.04

    node["upstart"]["services"].each do |monkey_patch|

        begin
            svc = resources(service: monkey_patch)
            svc.provider(::Chef::Provider::Service::Upstart)

            Chef::Log.info( "Monkey patching openstack service resource '#{monkey_patch}'" +
                "to use '::Chef::Provider::Service::Upstart' provider")

        rescue Exception => msg

            Chef::Log.info( "Skipping monkey patching openstack service resource '#{monkey_patch}' " +
                "as it has not been defined by recipes in this nodes run-list.")
        end
    end
end
############################################################################

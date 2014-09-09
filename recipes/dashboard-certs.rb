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

# Setup certs for Horizon ssl configuration
if node['openstack']['dashboard']['use_ssl'] &&
    !node["openstack"]["dashboard"]["certificate_databag_item"].nil? &&
    !node["openstack"]["dashboard"]["certificate_databag_item"].empty?

    encryption_key = ::SysUtils::get_encryption_secret
    certificates = Chef::EncryptedDataBagItem.load( "certificates-#{node.chef_environment}", 
        node['openstack']['dashboard']["certificate_databag_item"], encryption_key )

    node.override['openstack']['dashboard']['ssl']['cert_data'] = "#{certificates["cert"]}#{certificates["cacert"]}"
    node.override['openstack']['dashboard']['ssl']['key_data'] = "#{certificates["key"]}"
end

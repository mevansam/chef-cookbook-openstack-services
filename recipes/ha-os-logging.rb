#
# Cookbook Name:: openstack-services
# Recipe:: ha-os-logging
#
# Author: Mevan Samaratunga
# Email: mevansam@gmail.com
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'runit::default'
include_recipe 'java::default'


## Install elastic search

include_recipe 'cluster::elasticsearch'
plugin_installer = "#{node["elasticsearch"]["bindir"]}/plugin"

script "install elasticsearch plugins" do
    interpreter "bash"
    user "root"
    cwd "/tmp"
    code <<-EOH

    	#{plugin_installer} --list | grep "\\- head" 2>&1 > /dev/null
    	if [ $? -ne 0 ]; then
    		echo "**** Instaling elasticsearch-head plugin..."
    		#{plugin_installer} --install mobz/elasticsearch-head
		fi
    EOH
end


# Configure Kibana

install_type = node['kibana']['install_type']

if node['kibana']['user'].empty?
	if !node['kibana']['webserver'].empty?
		webserver = node['kibana']['webserver']
		kibana_user = node[webserver]['user']
	else
		kibana_user = 'nobody'
	end
else
	kibana_user = node['kibana']['user']
	kibana_user kibana_user do
		name kibana_user
		group kibana_user
		home node['kibana']['install_dir']
		action :create
	end
end

kibana_install 'kibana' do
	user kibana_user
	group kibana_user
	install_dir node['kibana']['install_dir']
	install_type install_type
	action :create
end

docroot = "#{node['kibana']['install_dir']}/current/kibana"
kibana_config = "#{node['kibana']['install_dir']}/current/#{node['kibana'][install_type]['config']}"
es_server = "#{node['kibana']['es_scheme']}#{node['kibana']['es_server']}:#{node['kibana']['es_port']}"

template kibana_config do
	source node['kibana'][install_type]['config_template']
	cookbook node['kibana'][install_type]['config_template_cookbook']
	mode '0644'
	user kibana_user
	group kibana_user
	variables(
		index: node['kibana']['config']['kibana_index'],
		port: node['kibana']['java_webserver_port'],
		elasticsearch: es_server,
		default_route: node['kibana']['config']['default_route'],
		panel_names:  node['kibana']['config']['panel_names']
	)
end

if install_type == 'file'

  include_recipe 'runit::default'

  runit_service 'kibana' do
    options(
      user: kibana_user,
      home: "#{node['kibana']['install_dir']}/current"
    )
    cookbook 'kibana_lwrp'
    subscribes :restart, "template[#{kibana_config}]", :delayed
  end
end


## Create logstash instance

logstash_config = node['logstash']['instance_default']
logstash_home_dir = logstash_config['basedir']
logstash_user = logstash_config['user']

logstash_instance 'logstash' do
	action 'create'
	create_account false
end

shell = "sudo -i -u #{logstash_user} bash -lc"


## Install nodejs

nvm_version = node['nvm']['nvm_version']
nodejs_version= node['nvm']['nodejs_version']

ruby_block "install nodejs" do
	block do

		shell!("#{shell} \"curl https://raw.githubusercontent.com/creationix/nvm/v#{nvm_version}/install.sh | bash\"") \
			unless ::File.exist?("#{logstash_home_dir}/.nvm/nvm.sh")

		shell!("#{shell} \". .nvm/nvm.sh && nvm install #{nodejs_version}\"")  \
			unless ::Dir.exist?("#{logstash_home_dir}/.nvm/v${nodejs_version}")
	end
end


## Install logio

ruby_block "install logio" do
	block do

		shell!("#{shell} \". .nvm/nvm.sh && nvm use #{nodejs_version} && npm install -g log.io --user #{logstash_config['user']}\"") \
			unless ::File.exist?("#{logstash_home_dir}/.nvm/v${nodejs_version}/bin/log.io-server")
	end
end

template "#{logstash_home_dir}/.log.io/log_server.conf" do
	source 'logging/logio-log_server.conf.erb'
	notifies :restart, 'runit_service[logio-server]', :delayed
end

template "#{logstash_home_dir}/.log.io/web_server.conf" do
	source 'logging/logio-web_server.conf.erb'
	notifies :restart, 'runit_service[logio-server]', :delayed
end

runit_service 'logio-server' do

	options(
        home: logstash_home_dir,
        nodejs_version: nodejs_version,
        user: logstash_user,
        supervisor_gid: logstash_config['supervisor_gid']
    )
    finish true
	action :enable
end


## Configure logstash

node.override['logstash']['instance_default']['ipv4_only'] = true

execute 'allowing java to use privileged ports' do
	command "setcap cap_net_bind_service=+epi #{node['logstash']['instance_default']['java_home']}/bin/java"
end

directory '/etc/sv/logstash_logstash' do
	recursive true
end
cookbook_file "sv-logstash-finish" do
	source 'logging/sv-logstash-finish'
	path '/etc/sv/logstash_logstash/finish'
	mode 00744
end

templates = {
	'input_syslog' => 'logging/input_syslog.conf.erb',
	'output_error' => 'logging/output_errors.conf.erb',
	'output_logio' => 'logging/output_logio.conf.erb',
	'output_elasticsearch' => 'logging/output_elasticsearch.conf.erb'
}
template_variables = {

	input_syslog_host: node['elk']['logstash']['syslog']['bind_address'],
	input_syslog_port: node['elk']['logstash']['syslog']['port'],
	input_syslog_ports: node['elk']['logstash']['syslog']['ports'],
	input_logstash_log_path: "#{logstash_home_dir}/logstash/log",

	output_logio_host: node['elk']['logio']['server_address'],
	output_logio_port: node['elk']['logio']['server_port'],

	output_elasticsearch_port: node['elasticsearch']['http']['port']
}
logstash_config 'logstash' do

	action 'create'
	templates_cookbook 'openstack-services'
	templates templates
	variables(template_variables)
	# notifies :restart, 'logstash_service[logstash]', :delayed
end

pattern_templates = {
	'extra-grok-patterns' => 'logging/extra-grok-patterns'
}
pattern_templates_variables = {	
}
logstash_pattern 'logstash' do

	action 'create'
	templates_cookbook 'openstack-services'
	templates pattern_templates
	variables(pattern_templates_variables)
	notifies :restart, 'logstash_service[logstash]', :delayed
end

cookbook_file 'logio.rb' do
	source 'logging/logio.rb'
    path "#{logstash_home_dir}/logstash/lib/logstash/codecs/logio.rb"
    user logstash_config['user']
    group logstash_config['group']
    mode 00644
	notifies :restart, 'logstash_service[logstash]', :delayed
end

logstash_service 'logstash' do
	templates_cookbook 'openstack-services'
	action :enable
	notifies :create, "cookbook_file[sv-logstash-finish]", :immediately
end


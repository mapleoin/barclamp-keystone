#
# Cookbook Name:: keystone
# Recipe:: default
#
# Copyright 2013, SUSE Linux GmbH
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

class ::Chef::Recipe
  include ::Openstack
end

# TODO developer mode is set so we don't have to handle data bags yet
node.set[:openstack][:developer_mode] = true

node[:openstack][:db][:identity][:username] = node[:keystone][:db][:user]
# TODO this used to be:
# node.set_unless['keystone']['db']['password'] = secure_password
# Figure out if we want to keep generating passwords manually here, or
# if we want to use data bags
node.set[:openstack][:db][:identity][:password] = db_password 'keystone'

env_filter = " AND database_config_environment:database-config-#{node[:keystone][:database_instance]}"
sqls = search(:node, "roles:database-server#{env_filter}") || []
if sqls.length > 0
    sql = sqls[0]
    sql = node if sql.name == node.name
else
    sql = node
end

sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
Chef::Log.info("Database server found at #{sql_address}")

# TODO this will normally be set by the (opscode) database::server
# recipe, but we haven't gotten to using that yet
node[:postgresql][:password][:postgres] = 'secret'

node.set[:openstack][:db][:service_type] = sql[:database][:sql_engine]
node.set[:openstack][:db][:identity][:host] = sql_address

node.set[:openstack][:db][:identity][:db_type] = sql[:database][:sql_engine]
node.set[:openstack][:db][:identity][:db_name] = node[:keystone][:db][:database]

node.set[:openstack][:identity][:users] = {
  node[:keystone][:admin][:username] => {
    :password => node[:keystone][:admin][:password],
    :default_tenant => node[:keystone][:admin][:tenant],
    :roles => {
      :admin => [ node[:keystone][:admin][:tenant], node[:keystone][:default][:tenant] ]
    }
  },
  node[:keystone][:default][:username] => {
    :password => node[:keystone][:default][:password],
    :default_tenant => node[:keystone][:default][:tenant],
    :roles => {
      "Member" => [ node[:keystone][:default][:tenant] ]
    }
  }
}

node.set[:openstack][:endpoints]["identity-api"][:scheme] = node[:keystone][:api][:protocol]

include_recipe "openstack-identity::server"
include_recipe "openstack-identity::registration"

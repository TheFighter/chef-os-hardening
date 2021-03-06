#
# Cookbook Name: os-hardening
# Recipe: sysctl
#
# Copyright 2012, Dominik Richter
# Copyright 2014, Deutsche Telekom AG
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

# include sysctl recipe and set /etc/sysctl.d/99-chef-attributes.conf
include_recipe "sysctl"

cpuVendor = node[:cpu][:'0'][:vendor_id].
    sub(/^.*GenuineIntel.*$/,"intel").
    sub(/^.*AuthenticAMD.*$/,"amd")

# protect sysctl.conf
File "/etc/sysctl.conf" do
  mode 0440
  owner "root"
  group "root"
end

# NSA 2.2.4.1 Set Daemon umask
# do config for rhel-family
case node[:platform_family]
when "rhel", "fedora"
  template "/etc/sysconfig/init" do
      source "rhel_sysconfig_init.erb"
      mode 0544
      owner "root"
      group "root"
      variables()
    end
end

# do initramfs config for ubuntu and debian
case node[:platform_family]
when "debian"

  # rebuild initramfs with starting pack of modules,
  # if module loading at runtime is disabled
  if not node[:security][:kernel][:enable_module_loading]
    template "/etc/initramfs-tools/modules" do
      source "modules.erb"
      mode 0440
      owner "root"
      group "root"
      variables(
        :x86_64 => (not (node[:kernel][:machine] =~ /x86_64/).nil?),
        :cpuVendor => cpuVendor
      )
    end

    execute "update-initramfs" do
      command "update-initramfs -u"
      action :run
    end
  end
end

case node[:platform_family]
when "debian"
    service_provider = node[:platform] == 'ubuntu' ? Chef::Provider::Service::Upstart : nil
    service "procps" do
        provider service_provider
        supports :restart => false, :reload => false
        action :start
    end
end


gem_package 'chef-zero'

execute 'start chef-zero' do
  command "#{File.join(node[:ruby][:gem][:bin_dir]} chef-zero start -h #{node[:ipaddress]} -p 80 &"
  not_if 'netstat -lpt | grep "tcp[[:space:]]" | grep ruby'
end

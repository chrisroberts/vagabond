execute 'apt-get update'
package 'build-essential'
gem_package 'chef-zero'

execute 'start chef-zero' do
  command "start-stop-daemon --background --start --quiet --exec #{File.join(node[:languages][:ruby][:bin_dir],'chef-zero')} -- -H #{node[:ipaddress]} -p 80 start"
  not_if 'netstat -lpt | grep "tcp[[:space:]]" | grep ruby'
end


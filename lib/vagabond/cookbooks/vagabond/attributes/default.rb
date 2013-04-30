default[:vagabond][:bases][:ubuntu_1004][:template] = 'ubuntu'
default[:vagabond][:bases][:ubuntu_1004][:template_options] = {'--release' => 'lucid'}
default[:vagabond][:bases][:ubuntu_1204][:template] = 'ubuntu'
default[:vagabond][:bases][:ubuntu_1204][:template_options] = {'--release' => 'precise'}
default[:vagabond][:bases][:ubuntu_1210][:template] = 'ubuntu'
default[:vagabond][:bases][:ubuntu_1210][:template_options] = {'--release' => 'quantal'}
default[:vagabond][:bases][:centos_58][:template] = 'centos'
default[:vagabond][:bases][:centos_58][:template_options] = {'--release' => '5', '--releaseminor' => '8'}
default[:vagabond][:bases][:centos_63][:template] = 'centos'
default[:vagabond][:bases][:centos_63][:template_options] = {'--release' => '6', '--releaseminor' => '3'}
default[:vagabond][:bases][:centos_64][:template] = 'centos'
default[:vagabond][:bases][:centos_64][:template_options] = {'--release' => '6', '--releaseminor' => '4'}
default[:vagabond][:bases][:debian_6][:template] = 'debian'
default[:vagabond][:bases][:debian_6][:create_environment] = {'SUITE' => 'squeeze'}
default[:vagabond][:bases][:debian_7][:template] = 'debian'
default[:vagabond][:bases][:debian_7][:create_environment] = {'SUITE' => 'wheezy'}
default[:vagabond][:customs] = {}
default[:vagabond][:server_base] = true

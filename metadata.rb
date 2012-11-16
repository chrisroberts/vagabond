maintainer       "Chris Roberts"
maintainer_email "chrisroberts.code@gmail.com"
license          "Apache 2.0"
description      "Chef driven Linux Containers"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

supports 'ubuntu', '12.04'

depends 'omnibus_updater'
suggests 'bridger'

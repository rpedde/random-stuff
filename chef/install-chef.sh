#!/bin/bash

CLIENT_VERSION=${CLIENT_VERSION:-"11.2.0-1"}
ENVIRONMENT=${ENVIRONMENT:-_default}
HOSTNAME=${HOSTNAME:-(hostname -s).local}

cat > /tmp/install_$1.sh <<EOF
sudo apt-get install -y curl
curl -skS -L http://www.opscode.com/chef/install.sh | bash -s - -v ${CLIENT_VERSION}
mkdir -p /etc/chef

cp /tmp/validation.pem /etc/chef/validation.pem

cat <<EOF2 > /etc/chef/client.rb
Ohai::Config[:disabled_plugins] = ["passwd"]

chef_server_url "https://${HOSTNAME}:443"
chef_environment "${ENVIRONMENT}"
EOF2

cat <<EOF2 > /etc/chef/knife.rb
chef_server_url "https://${HOSTNAME}:443"
chef_environment "${ENVIRONMENT}"
node_name "${1}"
EOF2

EOF

if [ ! -e validation.pem ]; then
    sudo cp /etc/chef-server/chef-validator.pem ./validation.pem
    sudo chown rpedde: validation.pem
fi

scp validation.pem $1:/tmp/validation.pem
scp /tmp/install_$1.sh $1:/tmp/install.sh

ssh $1 sudo /bin/bash /tmp/install.sh
ssh $1 sudo chef-client

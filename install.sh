#!/bin/bash

# Installs pip git devtools
# Installs uwsgi via pip
# Installs nginx if not installed -- keep default index
# Creates www-icis user


set -o xtrace

main() {
    install_dependencies
    stop_web_services
    setup_systemd_service_per_app
    populate_icis_content
    generate_web_configuration
    start_web_services
}

install_dependencies() {
    if [ $UID != 0 ]; then
        echo 'Must run as root'
        exit 1
    fi

    yum clean expire-cache
    yum check-update
    yum -y update
    yum -y install vim git python python-devel
    yum -y groupinstall "Development Tools"
    pip --version
    if [[ $? -ne 0 ]]; then
        curl -Lo- https://bootstrap.pypa.io/get-pip.py | python
    fi
    pip install virtualenv
    pip install uwsgi

    if [ -z $(systemctl status nginx) ]; then
        # Installing Nginx
        yum install -y epel-release && yum update
        yum install -y nginx
        systemctl start nginx
    fi
}

setup_systemd_service_per_app() {
    if [ ! -f /etc/systemd/system/uwsgi-app@.service ]; then
        cat > /etc/systemd/system/uwsgi-app@.service << EOF
[Unit]
Description=%i uWSGI app
After=syslog.target

[Service]
ExecStart=/usr/bin/uwsgi \
  --ini /usr/share/uwsgi/%i.ini \
  --socket /run/uwsgi/%i.socket
User=www-%i
Group=nginx
Restart=on-failure
KillSignal=SIGQUIT
Type=notify
StandardError=syslog
NotifyAccess=all
EOF
        cat > /etc/systemd/system/uwsgi-app@.socket << EOF
[Unit]
Description=Socket for uWSGI app %i

[Socket]
ListenStream=/run/uwsgi/%i.socket
SocketUser=www-%i
SocketGroup=nginx
SocketMode=0660

[Install]
WantedBy=sockets.target
EOF
    fi

}

stop_web_services() {
    systemctl stop nginx
    systemctl stop uwsgi-app@$icis_app_name.socket
    systemctl disable uwsgi-app@$icis_app_name.service
}

populate_icis_content() {
    # Reference: http://uwsgi-docs.readthedocs.io/en/latest/Systemd.html#one-service-per-app-in-systemd
    # Reference: https://www.dabapps.com/blog/introduction-to-pip-and-virtualenv-python/
    git clone https://github.com/clearlinux/ister-cloud-init-svc.git
    source ister-cloud-init-svc/parameters.conf
    rm -rf $icis_root
    mkdir -p $icis_root
    cp -rf ister-cloud-init-svc/app/* $icis_root
    local icis_venv_dir=$icis_root/env
    virtualenv $icis_venv_dir
    $icis_venv_dir/bin/pip install -r ister-cloud-init-svc/requirements.txt

    useradd www-icis -d $icis_root --shell /bin/false
    usermod -L -aG nginx www-icis
    chown www-icis:nginx -icis -R $icis_root

    mkdir -p /usr/share/uwsgi
    cat > /usr/share/uwsgi/$icis_app_name.ini << EOF
[uwsgi]
# App configurations
module = app
callable = app
chdir = $icis_root
home = $icis_venv_dir

# Init system configurations
master = true
cheap = true
idle = 600
die-on-idle = true
manage-script-name = true
EOF
    mkdir -p /run/uwsgi
    chown www-icis:nginx -R /usr/share/uwsgi
    chown www-icis:nginx -R /run/uwsgi
}

generate_web_configuration() {
    local nginx_dir=/etc/nginx
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.BAK
    cat > /etc/nginx/nginx.conf << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }

        location /icis/static/ {
           root /var/www/icis/static;
           rewrite ^/icis/static(/.*)$ \$1 break;
        }

        location /icis/ {
           uwsgi_pass unix:///run/uwsgi/icis.socket;
           include uwsgi_params;
        }
    }
}
EOF
}

start_web_services() {
    systemctl enable uwsgi-app@$icis_app_name.service
    systemctl enable uwsgi-app@$icis_app_name.socket
    systemctl restart uwsgi-app@$icis_app_name.socket
    systemctl enable nginx
    systemctl restart nginx
}

main

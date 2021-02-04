#!/bin/bash

branch=$1
project=$2
app_name=$3
app_env=$4

if [ $branch = "master" ] 
then
    exit 1
fi

service_name="${project}.${branch}"
service_path="/usr/src/services/${service_name}.service"
build_path="/var/www/${project}/${branch}"
nginx_conf_path="/etc/nginx/conf.d/${project}.conf"



if [ -f $service_path ]; then

    echo "Service $service_name exists."
    systemctl restart $service_name
    service nginx restart

else

    echo "Service $service_name does not exist."
    
    mkdir -p /usr/src/services
    
    FREE_PORT=$(comm -23 <(seq 49152 65535) <(ss -tan | awk '{print $4}' | cut -d':' -f2 | grep "[0-9]\{1,5\}" | sort | uniq) | shuf | head -n 1)
    LOCAL_APP_HOST="http://localhost:${FREE_PORT}"

    export WorkingDirectory=$build_path
    export Description="Servise for ${project}.${branch}"
    export ExeStart="/usr/bin/dotnet ${build_path}/${app_name}.dll --urls http://localhost:${FREE_PORT}" 
    export Identifier="${project}.${branch}"
    export AppEnv="ASPNETCORE_ENVIRONMENT=${app_env}" 

    mkdir -p ${build_path}

    envsubst < service.tmpl > $service_path

    systemctl enable $service_path
    

    NGINX_LOCATION="location /${project}/${branch}/ {\n\t\t\tproxy_pass ${LOCAL_APP_HOST};\n\t}\n\n"

    NGINX_CONF_PATH="/etc/nginx/conf.d/dev.nginx.conf"
    
    sed  "/\[insert_line\]/a ${NGINX_LOCATION}" ${NGINX_CONF_PATH} -i
    service nginx restart
    systemctl start $service_name

fi

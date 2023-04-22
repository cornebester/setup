#!/usr/bin/env bash
# This script setups dockerized Redash on Ubuntu 18.04.
set -eu

REDASH_BASE_PATH=/Users/cornebester/Documents/redash

# install_docker(){
#     # Install Docker
#     export DEBIAN_FRONTEND=noninteractive
#     sudo apt-get -qqy update
#     DEBIAN_FRONTEND=noninteractive sudo -E apt-get -qqy -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade 
#     sudo apt-get -yy install apt-transport-https ca-certificates curl software-properties-common wget pwgen
#     curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#     sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
#     sudo apt-get update && sudo apt-get -y install docker-ce

#     # Install Docker Compose
#     sudo curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
#     sudo chmod +x /usr/local/bin/docker-compose

#     # Allow current user to run Docker commands
#     sudo usermod -aG docker $USER
# }

create_directories() {
    if [[ ! -e $REDASH_BASE_PATH ]]; then
        sudo mkdir -p $REDASH_BASE_PATH
        sudo chown $USER:$USER $REDASH_BASE_PATH
    fi

    if [[ ! -e $REDASH_BASE_PATH/postgres-data ]]; then
        mkdir $REDASH_BASE_PATH/postgres-data
    fi
}

create_config() {
    if [[ -e $REDASH_BASE_PATH/env ]]; then
        rm $REDASH_BASE_PATH/env
        touch $REDASH_BASE_PATH/env
    fi

    COOKIE_SECRET=$(python -c 'import secrets; print(secrets.token_hex())')
    SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex())')
    POSTGRES_PASSWORD=$(python -c 'import secrets; print(secrets.token_hex())')
    REDASH_DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@postgres/postgres"

    echo "PYTHONUNBUFFERED=0" >> $REDASH_BASE_PATH/env
    echo "REDASH_LOG_LEVEL=INFO" >> $REDASH_BASE_PATH/env
    echo "REDASH_REDIS_URL=redis://redis:6379/0" >> $REDASH_BASE_PATH/env
    echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> $REDASH_BASE_PATH/env
    echo "REDASH_COOKIE_SECRET=$COOKIE_SECRET" >> $REDASH_BASE_PATH/env
    echo "REDASH_SECRET_KEY=$SECRET_KEY" >> $REDASH_BASE_PATH/env
    echo "REDASH_DATABASE_URL=$REDASH_DATABASE_URL" >> $REDASH_BASE_PATH/env
}

setup_compose() {
    REQUESTED_CHANNEL=stable
    LATEST_VERSION=`curl -s "https://version.redash.io/api/releases?channel=$REQUESTED_CHANNEL"  | json_pp  | grep "docker_image" | head -n 1 | awk 'BEGIN{FS=":"}{print $3}' | awk 'BEGIN{FS="\""}{print $1}'`

    cd $REDASH_BASE_PATH
    GIT_BRANCH="${REDASH_BRANCH:-master}" # Default branch/version to master if not specified in REDASH_BRANCH env var
    # wget https://raw.githubusercontent.com/getredash/setup/${GIT_BRANCH}/data/docker-compose.yml
    curl --output $REDASH_BASE_PATH/docker-compose.yml https://raw.githubusercontent.com/getredash/setup/$GIT_BRANCH/data/docker-compose.yml
    # https://stackoverflow.com/questions/4247068/sed-command-with-i-option-failing-on-mac-but-works-on-linux
    sed -i'.original' "s/image: redash\/redash:([A-Za-z0-9.-]*)/image: redash\/redash:$LATEST_VERSION/" $REDASH_BASE_PATH/docker-compose.yml
    # https://unix.stackexchange.com/questions/129059/how-to-ensure-that-string-interpolated-into-sed-substitution-escapes-all-metac
    lhs=/opt/redash
    rhs=$REDASH_BASE_PATH
    escaped_lhs=$(printf '%s\n' "$lhs" | sed 's:[][\\/.^$*]:\\&:g')
    escaped_rhs=$(printf '%s\n' "$rhs" | sed 's:[\\/&]:\\&:g;$!s/$/\\/')
    echo $escaped_lhs
    echo $escaped_rhs
    sed -i'.original' "s/$escaped_lhs/$escaped_rhs/" $REDASH_BASE_PATH/docker-compose.yml
   
    # sed -ri "s/image: redash\/redash:([A-Za-z0-9.-]*)/image: redash\/redash:$LATEST_VERSION/" $REDASH_BASE_PATH/docker-compose.yml
    # echo "export COMPOSE_PROJECT_NAME=redash" >> ~/.profile
    # echo "export COMPOSE_FILE=/$REDASH_BASE_PATH/redash/docker-compose.yml" >> ~/.profile
    export COMPOSE_PROJECT_NAME=redash
    export COMPOSE_FILE=$REDASH_BASE_PATH/docker-compose.yml
    # cd $REDASH_BASE_PATH
    sudo docker-compose run --rm server create_db
    # sudo docker-compose up -d
}

# install_docker
create_directories
create_config
setup_compose


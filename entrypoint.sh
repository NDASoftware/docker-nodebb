#!/bin/bash
set -e

if ! [ -e /data/config.json ]; then

    if [ -n "$DATABASE" ]; then

        if [ "$DATABASE" == "redis" ]; then
            url=$URL database=$DATABASE redis__database=$DB_NAME redis__password=$DB_PASSWORD redis__host=$DB_HOST redis__port=$DB_PORT node app --setup --series
        elif [ "$DATABASE" == "mongo" ]; then
            url=$URL database=$DATABASE mongo__username=$DB_USER mongo__password=$DB_PASSWORD mongo__host=$DB_HOST mongo__port=$DB_PORT node app --setup --series
        fi

    else
        echo "Database setting is invalid"
    fi

    mv config.json /data/config.json \
    && ln -s /data/config.json /usr/src/app/config.json
else
    # Link config file (in cases when you recreated container)
    if [ ! -e /usr/src/app/config.json ]; then
        ln -s /data/config.json /usr/src/app/config.json
    fi

fi

if [ ! -e /data/uploads ]; then
    mv /usr/src/app/public/uploads /data/uploads \
    && ln -s /data/uploads /usr/src/app/public/uploads
else
    rm -rf /usr/src/app/public/uploads \
    && ln -s /data/uploads /usr/src/app/public/uploads
fi

if [ ! -e /data/package.json ]; then
    mv /usr/src/app/package.json /data/package.json \
    && ln -s /data/package.json /usr/src/app/package.json
else
    rm /usr/src/app/package.json \
    && ln -s /data/package.json /usr/src/app/package.json
fi

if [ -e /data/plugins ]; then
    # iterate through the /data/plugins folder and ln them to /usr/src/app/node_modules
    for dir in /data/plugins/*/
    do
        dir=${dir%*/}
        echo Linking /data/plugins/${dir##*/} to /usr/src/app/node_modules/${dir##*/}
        ln -s /data/plugins/${dir##*/} /usr/src/app/node_modules/${dir##*/}
    done
fi

if [ -e /data/scripts ]; then
    # iterate through the /data/scripts folder and execute any extra scripts
    for file in /data/scripts/*.sh
    do
        echo 'Running script $file ..'
        sh $file
    done
fi

if [ -f config.json ]; then
    /usr/src/app/nodebb build --series
    if [ "$SKIP_UPGRADE" == "true" ]; then
        echo "Skipping automatic upgrades.."
    else
        /usr/src/app/nodebb upgrade -mips
    fi
fi

exec "$@"

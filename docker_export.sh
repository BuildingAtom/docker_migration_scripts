#!/bin/bash

# Version 0.1

echo "WARNING: NO INTERMEDIATE IMAGES WILL BE SAVED"
echo "WARNING: VOLUMES ARE NOT SAVED AND MUST BE MANUALLY MIGRATED"

# https://stackoverflow.com/questions/3231804/in-bash-how-to-add-are-you-sure-y-n-to-any-command-or-alias
read -r -p "Did you make sure no containers will explode (check /var/lastlog?) [y/N] " response
response=${response,,}    # tolower
if [[ ! "$response" =~ ^(yes|y)$ ]];then
    echo "Run the following to verify!"
    echo "docker ps -a --format {{.Names}} | xargs -I{} docker exec {} ls -lh /var/log/lastlog"
    exit
fi

############################
## First, save all images ##
############################

mkdir -p images

echo "Beginning save of all tagged image repos"
echo "Repos to save"
echo "------------------------------"
docker image ls --format {{.Repository}} | sort | uniq | grep -wv '<none>'
echo "------------------------------"

# save tagged repos
docker image ls --format {{.Repository}} | sort | uniq | grep -wv '<none>' | xargs -l bash -c 'echo "Saving $0"; docker save $0 | zstd > images/${0//[^a-zA-Z0-9]/}.tar.zst'
#docker image ls --format {{.Repository}} | sort | uniq | grep -wv '<none>' | xargs -l bash -c 'echo "Saving $0"; docker save $0 | gzip > images/${0//[^a-zA-Z0-9]/}.tar.gz'

echo "=============================="

echo "Beginning save of untagged images (no intermediates)"
echo "Images to save"
echo "------------------------------"
docker image ls -f dangling=true -q
echo "------------------------------"

# save untagged images
docker image ls -f dangling=true -q | xargs -l bash -c 'echo "Saving $0"; docker save $0 | zstd > images/$0.tar.zst'
#docker image ls -f dangling=true -q | xargs -l bash -c 'echo "Saving $0"; docker save $0 | gzip > images/$0.tar.gz'

echo "=============================="

###########################
## Then save all volumes ##
###########################
## NOT IMPLEMENTED

#############################
## Now save the containers ##
#############################

mkdir -p containers

echo "Beginning export of all containers"

# List all containers
list_containers=`docker ps -a --format "{{.ID}} {{.Names}}"`

echo "------------------------------"
echo $list_containers
echo "------------------------------"

# Iterate over the list
while IFS= read -r line; do
    args_container=($line)
    dir_save=containers/${args_container[0]}

    echo "Saving container ${args_container[1]}"

    # Make the directory by ID
    mkdir -p $dir_save

    # Generate the changefile
    exclude_string=`docker inspect ${args_container[0]} | grep Destination | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -c 16- | sed 's/^\"*/(/;s/\"/)/;s/,//' | tr '\n' '|' | sed 's/|$/(\/|$)/'`
    if [ "$s" = "" ];then
        docker diff ${args_container[0]} > $dir_save/changefile.txt
    else
        docker diff ${args_container[0]} | grep -v -E "$exclude_string" > $dir_save/changefile.txt
    fi

    # Generate the run script
    docker run --rm -a STDOUT \
        -v /var/run/docker.sock:/var/run/docker.sock \
        bcicen/docker-replay \
        -p ${args_container[0]} > $dir_save/run_script.sh

    # Finally save the container's flattened image
    #docker export ${args_container[0]} | zstd > $dir_save/export.tar.zst
    docker export ${args_container[0]} > $dir_save/export.tar

done <<< "$list_containers"

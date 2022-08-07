#!/bin/bash

# Version 0.1, make sure to use this with the matching export version!

########################
## Restore all images ##
########################
echo "Loading all images in images/"
ls -1 images/ | xargs -l bash -c 'echo "Loading images/$0";unzstd < images/$0 | docker load'
#ls -1 images/ | xargs -l bash -c 'echo "Loading images/$0";docker load -i images/$0'

############################
## Restore all containers ##
############################
echo "Creating all containers"

list_containers=`ls -1 containers/`

while IFS= read -r container; do
    dir_save=containers/$container

    # Create container
    container_new=`bash $dir_save/run_script.sh`
    echo "Created container $container as $container_new, now adding files"

    #docker cp $dir_save/export.tar.zst $container_new:/export.tar.zst
    docker cp $dir_save/export.tar $container_new:/export.tar

    # Transfer added and deleted over
    grep '^[AC].\+' $dir_save/changefile.txt | cut -c 4- > aksfjlksafjwaeiflkds.txt
    if [ -s aksfjlksafjwaeiflkds.txt ]; then
        # transfer the added_changed file, the tar, and extract it
        docker cp aksfjlksafjwaeiflkds.txt $container_new:/added_changed.txt

        # Extract and overwrite as needed
        #docker exec -u 0 $container_new tar xpvf /export.tar.zst --zstd --overwrite --same-owner --selinux --xattrs --no-recursion --files-from /added_changed.txt -C /
        docker exec -u 0 $container_new tar xpvf /export.tar --overwrite --same-owner --selinux --xattrs --no-recursion --files-from /added_changed.txt -C /

        # Clean up
        #docker exec -u 0 $container_new rm -rf /export.tar.zst /added_changed.txt
        docker exec -u 0 $container_new rm -rf /export.tar /added_changed.txt
    fi

    # Transfer & delete as needed
    grep '^D.\+' $dir_save/changefile.txt | cut -c 3- > aksfjlksafjwaeiflkds.txt
    docker cp aksfjlksafjwaeiflkds.txt $container_new:/delete.txt

    # Delete as needed
    docker exec -u 0 $container_new bash -c 'cat /delete.txt | xargs -I{} rm -rf "{}"'

    # Delete extras
    docker exec -u 0 $container_new rm -rf /delete.txt
    rm aksfjlksafjwaeiflkds.txt

done <<< "$list_containers"

#!/bin/bash


rsync=/usr/bin/rsync

$rsync -ruptolg --checksum --delete --delay-updates \
    --exclude 'wp-content/uploads' \
    --exclude 'wp-config.php' \
    --exclude '.git' \
    /home/dpla/wordpress/ /srv/www/wordpress

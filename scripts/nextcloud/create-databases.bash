#!/bin/bash

set -x

# nextcloud
docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "CREATE DATABASE nextcloud;"
docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "CREATE USER 'nextcloud'@'%' IDENTIFIED BY 'H5DJz0HMXF9HI83IO4nGn3d9';"
docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'%';"

# onlyoffice
#docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "CREATE DATABASE onlyoffice;"
#docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "CREATE USER 'onlyoffice'@'%' IDENTIFIED BY 'R0l1ejKey7ot6lubjbIfhT4C';"
#docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "GRANT ALL PRIVILEGES ON onlyoffice.* TO 'onlyoffice'@'%';"

docker exec -it database mariadb -u root -p5P6geD2tDWcorU4t2gk8 -e "FLUSH PRIVILEGES;"

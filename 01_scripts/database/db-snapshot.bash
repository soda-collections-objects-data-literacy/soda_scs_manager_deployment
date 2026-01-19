#!/bin/bash

set -x

# Dump the database.
mariadb-dump -uroot -p${MARIADB_ROOT_PASSWORD} $1 > $2
# Tar the dump.
tar -czvf $2.tar.gz $2
# Remove the dump.
rm $2
# Return the path to the tar.gz file.
echo $2.tar.gz

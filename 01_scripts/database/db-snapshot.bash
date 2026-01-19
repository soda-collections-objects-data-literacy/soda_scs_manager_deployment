#!/bin/bash

set -x

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Dump the database.
mariadb-dump -uroot -p${SCS_DB_ROOT_PASSWORD} $1 > $2
# Tar the dump.
tar -czvf $2.tar.gz $2
# Remove the dump.
rm $2
# Return the path to the tar.gz file.
echo $2.tar.gz

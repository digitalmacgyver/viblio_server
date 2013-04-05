#!/bin/sh
#
# cp sql/vadb.sql sql/vadb.sql.new
# - edit .new
if [ -f "sql/vadb.sql.new" ]; then
    sqlt-diff --output-db=MySQL sql/vadb.sql=MySQL sql/vadb.sql.new=MySQL > db.alter
    mysql -u vaadmin --password=viblio vadb < db.alter
    ./script/db2dbix.sh
    echo "If no errors, then execute:"
    echo "mv sql/vadb.sql.new sql/vadb.sql"
else
    echo "You must first:"
    echo "cp sql/vadb.sql sql/vadb.sql.new"
    echo "and modify it."
fi


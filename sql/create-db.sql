drop database if exists vadb;
create database vadb;
grant all privileges on vadb.* to 'vaadmin'@'%' identified by 'viblio';
grant all privileges on vadb.* to 'vaadmin'@'localhost' identified by 'viblio';

drop database if exists vadb_staging;
create database vadb_staging;
grant all privileges on vadb_staging.* to 'vaadmin'@'%' identified by 'viblio';
grant all privileges on vadb_staging.* to 'vaadmin'@'localhost' identified by 'viblio';


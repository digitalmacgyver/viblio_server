drop database if exists vadb;
create database vadb;
grant all privileges on vadb.* to 'vaadmin'@'%' identified by 'viblio';
grant all privileges on vadb.* to 'vaadmin'@'localhost' identified by 'viblio';

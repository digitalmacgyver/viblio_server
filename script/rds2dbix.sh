./script/va_create.pl model RDS DBIC::Schema VA::RDSSchema create=static \
    components=ColumnDefault,TimeStamp,PassphraseColumn,UUIDColumns,FilterColumn \
    'dbi:mysql:database=video_dev_1;host=testpub.c9azfz8yt9lz.us-west-2.rds.amazonaws.com' 'video_dev_1' 'video_dev_1' \
    '{AutoCommit=>1, mysql_enable_utf8 => 1}'

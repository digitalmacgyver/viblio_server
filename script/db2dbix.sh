./script/va_create.pl model DB DBIC::Schema VA::Schema create=static \
    components=TimeStamp,PassphraseColumn,UUIDColumns \
    dbi:mysql:vadb 'vaadmin' 'viblio' \
    '{AutoCommit=>1, mysql_enable_utf8 => 1}'

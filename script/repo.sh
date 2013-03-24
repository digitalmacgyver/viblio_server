#!/bin/sh
#
# Rerun the gettext programs to re-generate the i18n files.
#
if [ -e "/opt/local-lib/bin/xgettext.pl" ]; then
    x="/opt/local-lib/bin/xgettext.pl"
elif [ -e "/usr/local/bin/xgettext.pl" ]; then
    x="/usr/local/bin/xgettext.pl"
else
    x="xgettext.pl"
fi
$x --output=lib/VA/I18N/en.pot \
			   --directory=lib/ \
			   --directory=root/templates/
locales="en sv"
for locale in $locales; do
    msginit --input=lib/VA/I18N/en.pot \
	--output=lib/VA/I18N/$locale.po --locale=$locale --no-translator
done

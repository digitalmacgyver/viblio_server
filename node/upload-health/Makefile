ROOT ?= /deploy
LVL  ?= staging
APPNAME = uh
BRANCH ?= master

bump: package
	upgrade.pl -db $(LVL) -app $(APPNAME) -bump -f package.tar.gz

package:
	tar --exclude node_modules -zcf package.tar.gz \
		Makefile package.json uh.init.d uh.js

install:
	mkdir -p $(ROOT)/$(LVL)/$(APPNAME).next
	tar zxf package.tar.gz -C $(ROOT)/$(LVL)/$(APPNAME).next
	( cd $(ROOT)/$(LVL)/$(APPNAME).next && \
		/usr/local/bin/npm install || \
		cp -rf $(ROOT)/$(LVL)/$(APPNAME)/node_modules . )
	-rm -rf $(ROOT)/$(LVL)/$(APPNAME).pre
	-mv $(ROOT)/$(LVL)/$(APPNAME) $(ROOT)/$(LVL)/$(APPNAME).pre
	-mv $(ROOT)/$(LVL)/$(APPNAME).next $(ROOT)/$(LVL)/$(APPNAME)

versions:
	upgrade.pl -db $(LVL) -app $(APPNAME) -check

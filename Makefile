
# PREFIX should be set manually or will be selected during make install
DATADIR = $(PREFIX)/share/rsget.pl
BINDIR = $(PREFIX)/bin
VER =
PKGDIR = rsget.pl-$(VER)

PERL =
ifneq ($(PERL),)
SETINTERPRETER = 1s|^\(..\).*|\1$(PERL)|;
endif

PLUGIN_DIRS = Get Video Audio Image Link Direct
DIRS = RSGet $(PLUGIN_DIRS) data

Q = @

export LC_ALL=C

all: rsget.pl

ifeq ($(VER),)
pkg:
	$(MAKE) VER="$$(svn up | sed '/At revision /!d; s/At revision //; s/\.//')" pkg
else
pkg: clean
	rm -rf $(PKGDIR)
	for DIR in $(DIRS); do \
		install -d $(PKGDIR)/$$DIRS; \
	done
	install rsget.pl $(PKGDIR)
	cp Makefile README README.config README.requirements $(PKGDIR)
	cp RSGet/*.pm $(PKGDIR)/RSGet
	for DIR in $(PLUGIN_DIRS); do \
		cp $$DIR/* $(PKGDIR)/$$DIR || exit 1; \
		cp $$DIR/.template $(PKGDIR)/$$DIR || exit 1; \
	done
	cp data/* $(PKGDIR)/data
	tar -cjf $(PKGDIR).tar.bz2 $(PKGDIR)
endif

ifeq ($(PREFIX),)
install:
	$(Q)if [ -r /usr/bin/rsget.pl ]; then \
		echo "*** Current rsget.pl instalation found in /usr/bin, using /usr as PREFIX"; \
		$(MAKE) PREFIX="/usr" install; \
	else \
		$(MAKE) PREFIX="/usr/local" install; \
	fi

else
install: clean
	$(Q)echo "*** Installing in $(PREFIX)"
	for DIR in $(DIRS); do \
		install -d $(DESTDIR)$(DATADIR)/$$DIR; \
	done
	install -d $(DESTDIR)$(BINDIR)
	sed '$(SETINTERPRETER) s#\($$install_path\) =.*;#\1 = "$(DATADIR)";#' \
		< rsget.pl > rsget.pl.datadir
	install rsget.pl.datadir $(DESTDIR)$(BINDIR)/rsget.pl
	cp RSGet/*.pm $(DESTDIR)$(DATADIR)/RSGet
	cp data/* $(DESTDIR)$(DATADIR)/data
	for DIR in $(PLUGIN_DIRS); do \
		cp $$DIR/* $(DESTDIR)$(DATADIR)/$$DIR || exit 1; \
		grep -l "status:\s*BROKEN" $(DESTDIR)$(DATADIR)/$$DIR/* | xargs -r rm -v; \
	done
endif

.PHONY: clean
clean:
	$(Q)for DIR in $(DIRS) .; do \
		rm -fv $$DIR/*~; \
		rm -fv $$DIR/.*~; \
		rm -fv $$DIR/svn-commit.tmp*; \
	done
	rm -fv rsget.pl.datadir

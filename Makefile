
DATADIR = /usr/share/rsget.pl
BINDIR = /usr/bin
VER =
PKGDIR = rsget.pl-$(VER)

PERL =
ifneq ($(PERL),)
SETINTERPRETER = 1s|^\(..\).*|\1$(PERL)|;
endif

PLUGIN_DIRS = Get Video Audio Image Link Direct
DIRS = RSGet Get Video Audio Image Link Direct data

export LC_ALL=C

all: rsget.pl

ifeq ($(VER),)
pkg:
	make VER="$$(svn up | sed '/At revision /!d; s/At revision //; s/\.//')" pkg
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

install: clean
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

.PHONY: clean
clean:
	for DIR in $(DIRS); do \
		rm -fv $$DIR/*~; \
		rm -fv $$DIR/.*~; \
		rm -fv $$DIR/svn-commit.tmp*; \
	done
	rm -fv ./*~ \
	rm -fv ./.*~ \
	rm -fv ./svn-commit.tmp* \
	rm -fv rsget.pl.datadir

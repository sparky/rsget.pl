
DATADIR = /usr/share/rsget.pl
BINDIR = /usr/bin
VER =
PKGDIR = rsget.pl-$(VER)

all: rsget.pl

ifeq ($(VER),)
pkg:
	make VER="$$(svn up | sed '/At revision /!d; s/At revision //; s/\.//')" pkg
else
pkg:
	rm -f {RSGet,Get,Link,data}/*~
	install -d $(PKGDIR)/{RSGet,Get,Link,data}
	install rsget.pl $(PKGDIR)
	cp Makefile README $(PKGDIR)
	cp RSGet/*.pm $(PKGDIR)/RSGet
	cp Get/* $(PKGDIR)/Get
	cp Link/* $(PKGDIR)/Link
	grep "status:\s*BROKEN" $(PKGDIR)/{Get,Link}/* | sed 's/:.*//' | xargs -r rm -v
	cp data/* $(PKGDIR)/data
	tar -cjf $(PKGDIR).tar.bz2 $(PKGDIR)
endif

install:
	rm -f {RSGet,Get,Link,data}/*~
	install -d $(DESTDIR)$(DATADIR)/{RSGet,Get,Link,data} $(DESTDIR)$(BINDIR)
	sed 's#\($$data_path\) =.*;#\1 = "$(DATADIR)";#' < rsget.pl > rsget.pl.datadir
	install rsget.pl.datadir $(DESTDIR)$(BINDIR)/rsget.pl
	cp RSGet/*.pm $(DESTDIR)$(DATADIR)/RSGet
	cp Get/* $(DESTDIR)$(DATADIR)/Get
	cp Link/* $(DESTDIR)$(DATADIR)/Link
	cp data/* $(DESTDIR)$(DATADIR)/data


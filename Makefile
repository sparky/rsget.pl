
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
	cp Makefile $(PKGDIR)
	cp RSGet/*.pm $(PKGDIR)/RSGet
	cp Get/* $(PKGDIR)/Get
	cp Link/* $(PKGDIR)/Link
	cp data/* $(PKGDIR)/data
	tar -cjf $(PKGDIR).tar.bz2 $(PKGDIR)
endif

install:
	rm -f {RSGet,Get,Link,data}/*~
	install -d $(DESTDIR)$(DATADIR)/{RSGet,Get,Link,data} $(DESTDIR)$(BINDIR)
	install rsget.pl $(DESTDIR)$(BINDIR)
	cp RSGet/*.pm $(DESTDIR)$(DATADIR)/RSGet
	cp Get/* $(DESTDIR)$(DATADIR)/Get
	cp Link/* $(DESTDIR)$(DATADIR)/Link
	cp data/* $(DESTDIR)$(DATADIR)/data


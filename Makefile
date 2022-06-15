# makefile to setup environment for travis and development

# distributors probably want to set this to 'yes' for both make and make install
USE_SYSTEM_LUA ?= no
USE_SYSTEM_MPACK ?= no
ifneq ($(USE_SYSTEM_MPACK),no)
# Can't use luarocks to build if linking against system libmpack because
# apparently luarocks doesn't let you specify extra linker flags from the
# command line
USE_SYSTEM_LUA := 1
endif

# Lua-related configuration
MPACK_LUA_VERSION ?= 5.1.5
MPACK_LUA_VERSION_NOPATCH = $(basename $(MPACK_LUA_VERSION))
LUA_URL ?= https://lua.org/ftp/lua-$(MPACK_LUA_VERSION).tar.gz
LUAROCKS_URL ?= https://github.com/keplerproject/luarocks/archive/v2.2.0.tar.gz
LUA_TARGET ?= linux
MPACK_VERSION ?= 1.0.5
MPACK_URL ?= https://github.com/libmpack/libmpack/archive/$(MPACK_VERSION).tar.gz
LMPACK_VERSION != sed "/^local git_tag =/!d;s/[^']*'//;s/'\$$//;q" mpack-*.rockspec

# deps location
DEPS_DIR ?= $(CURDIR)/.deps/$(MPACK_LUA_VERSION)
DEPS_PREFIX ?= $(DEPS_DIR)/usr
DEPS_BIN ?= $(DEPS_PREFIX)/bin
DEPS_CMOD ?= $(DEPS_PREFIX)/lib/lua/$(MPACK_LUA_VERSION_NOPATCH)

# targets
LUA ?= $(DEPS_BIN)/lua
LUAROCKS ?= $(DEPS_BIN)/luarocks
BUSTED ?= $(DEPS_BIN)/busted
ifeq ($(USE_SYSTEM_LUA),no)
MPACK ?= $(DEPS_CMOD)/mpack.so
else
MPACK ?= mpack.so
endif

# Compilation
CC ?= gcc
PKG_CONFIG ?= pkg-config
CFLAGS ?= -ansi -O0 -g3 -Wall -Wextra -Werror -Wconversion \
	-Wstrict-prototypes -Wno-unused-parameter -pedantic
CFLAGS += -fPIC -std=c99 -DMPACK_DEBUG_REGISTRY_LEAK
ifeq ($(MPACK_LUA_VERSION_NOPATCH),5.3)
# Lua 5.3 has integer type, which is not 64 bits for -ansi since c89 doesn't
# have `long long` type.
CFLAGS += -DLUA_C89_NUMBERS
endif

LUA_IMPL ?= lua-$(MPACK_LUA_VERSION_NOPATCH)
LUA_INCLUDE ?= $(shell $(PKG_CONFIG) --cflags $(LUA_IMPL) 2>/dev/null || echo "-I/usr/include/lua$(MPACK_LUA_VERSION_NOPATCH)")
INCLUDES = $(LUA_INCLUDE)
LIBS =

ifeq ($(USE_SYSTEM_MPACK),no)
MPACK_SRC = mpack-src
else
MPACK_SRC =
LIBS += $(shell $(PKG_CONFIG) --libs mpack 2>/dev/null || echo "-lmpack")
CFLAGS += -DMPACK_USE_SYSTEM $(shell $(PKG_CONFIG) --cflags mpack 2> /dev/null)
endif

LUA_CMOD_INSTALLDIR ?= $(shell $(PKG_CONFIG) --variable=INSTALL_CMOD $(LUA_IMPL) 2>/dev/null || echo "/usr/lib/lua/$(MPACK_LUA_VERSION_NOPATCH)")

# Misc
# Options used by the 'valgrind' target, which runs the tests under valgrind
VALGRIND_OPTS ?= --error-exitcode=1 --log-file=valgrind.log --leak-check=yes \
	--track-origins=yes
# Command that will download a file and pipe it's contents to stdout
FETCH ?= curl -L -o -
# Command that will gunzip/untar a file from stdin to the current directory,
# stripping one directory component
UNTGZ ?= tar xfz - --strip-components=1


all: $(MPACK)

mpack-src:
	dir="mpack-src"; \
	mkdir -p $$dir && cd $$dir && \
	$(FETCH) $(MPACK_URL) | $(UNTGZ)

release: mpack-src
	rm -f libmpack-lua-$(LMPACK_VERSION).tar.gz
	tar cvfz libmpack-lua-$(LMPACK_VERSION).tar.gz \
		--transform 's,^,libmpack-lua-$(LMPACK_VERSION)/,' \
		mpack-*.rockspec lmpack.c mpack-src/src

clean:
	rm -rf mpack-src *.tar.gz *.src.rock *.so *.o

depsclean:
	rm -rf $(DEPS_DIR)

test: $(BUSTED) $(MPACK)
	$(BUSTED) -o gtest test.lua

valgrind: $(BUSTED) $(MPACK)
	eval $$($(LUAROCKS) path); \
	valgrind $(VALGRIND_OPTS) $(LUA) \
		$(DEPS_PREFIX)/lib/luarocks/rocks/busted/2.0.rc12-1/bin/busted test.lua

ci-test: valgrind
	$(LUA) leak_test.lua

gdb: $(BUSTED) $(MPACK)
	eval $$($(LUAROCKS) path); \
	gdb -x .gdb --args $(LUA) \
		$(DEPS_PREFIX)/lib/luarocks/rocks/busted/2.0.rc12-1/bin/busted test.lua

$(DEPS_CMOD)/mpack.so: $(LUAROCKS) $(MPACK_SRC) lmpack.c
	$(LUAROCKS) make CFLAGS='$(CFLAGS)' $(LUAROCKS_LDFLAGS)

mpack.so: lmpack.c $(MPACK_SRC)
	$(CC) -shared $(CFLAGS) $(INCLUDES) $(LDFLAGS) $< -o $@ $(LIBS)

$(BUSTED): $(LUAROCKS)
	$(LUAROCKS) install penlight 1.3.2-2
	$(LUAROCKS) install lua-term 0.7-1
	$(LUAROCKS) install dkjson 2.5-2
	$(LUAROCKS) install lua_cliargs 3.0-1
	$(LUAROCKS) install say 1.3-1
	$(LUAROCKS) install luafilesystem 1.6.3-2
	$(LUAROCKS) install luassert 1.7.10-0
	$(LUAROCKS) install mediator_lua 1.1.2-0
	$(LUAROCKS) install luasystem 0.2.0-0
	$(LUAROCKS) install busted 2.0.rc12-1
	$(LUAROCKS) install inspect  # helpful for debugging

$(LUAROCKS): $(LUA)
	dir="$(DEPS_DIR)/src/luarocks"; \
	mkdir -p $$dir && cd $$dir && \
	$(FETCH) $(LUAROCKS_URL) | $(UNTGZ) && \
	./configure --prefix=$(DEPS_PREFIX) --force-config \
		--with-lua=$(DEPS_PREFIX) && make bootstrap

$(LUA):
	dir="$(DEPS_DIR)/src/lua"; \
	mkdir -p $$dir && cd $$dir && \
	$(FETCH) $(LUA_URL) | $(UNTGZ) && \
	sed -i -e '/^CFLAGS/s/-O2/-g3/' src/Makefile && \
	make $(LUA_TARGET) install INSTALL_TOP=$(DEPS_PREFIX)

install: $(MPACK)
ifeq ($(USE_SYSTEM_LUA),no)
	@:
else
	mkdir -p "$(DESTDIR)$(LUA_CMOD_INSTALLDIR)"
	install -Dm755 $< "$(DESTDIR)$(LUA_CMOD_INSTALLDIR)/$<"
endif

.PHONY: all clean depsclean install test gdb valgrind ci-test release

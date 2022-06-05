## libmpack lua binding

[![Travis Build Status](https://travis-ci.org/libmpack/libmpack-lua.svg?branch=master)](https://travis-ci.org/libmpack/libmpack-lua)

## Building

```bash
LUA_TARGET=$(PLATFORM) make
```

Where `PLATFORM` is a supported platform for lua 5.1 (freebsd, linux, macosx etc.)

```bash
# e.g. for osx
LUA_TARGET=macosx make
```

For a complete list of targets run:
```bash
make; cd .deps/5.1.5/src/lua && make
```

`LUA_TARGET` will default to `linux` if not specified.

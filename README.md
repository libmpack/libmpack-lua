## libmpack lua binding

[![Travis Build Status](https://travis-ci.org/libmpack/libmpack-lua.svg?branch=master)](https://travis-ci.org/libmpack/libmpack-lua)

## Building

```bash
LUA_TARGET=$(PLATFORM) make
```

Where `PLATFORM` is a supported Lua 5.1 platform: linux (default), freebsd, macosx, ...
For a complete list of targets run:
```bash
make; cd .deps/5.1.5/src/lua && make
```

local git_tag = '1.0.10'

package = 'mpack'
version = git_tag .. '-0'
source = {
  url = 'https://github.com/libmpack/libmpack-lua/releases/download/' ..
    git_tag .. '/libmpack-lua-' .. git_tag .. '.tar.gz'
}

description = {
  summary = 'Lua binding to libmpack',
  license = 'MIT',
  homepage = 'https://github.com/libmpack/libmpack-lua'
}

build = {
  type = 'builtin',
  modules = {
    ['mpack'] = {
      sources = {'lmpack.c'}
    }
  }
}

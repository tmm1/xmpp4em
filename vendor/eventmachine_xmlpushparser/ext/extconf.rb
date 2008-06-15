# $Id: extconf.rb 63 2006-05-17 06:03:18Z blackhedd $
#
#----------------------------------------------------------------------------
#
# Copyright (C) 2006 by Francis Cianfrocca. All Rights Reserved.
#
# Gmail: garbagecat20
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#---------------------------------------------------------------------------
#
# We have to munge LDSHARED because this code needs a C++ link.
#

require 'mkmf'

flags = []

case RUBY_PLATFORM.split('-',2)[1]
when 'mswin32', 'mingw32', 'bccwin32'
  unless have_header('windows.h') and
      have_header('winsock.h') and
      have_library('kernel32') and
      have_library('rpcrt4') and
      have_library('gdi32')
    exit
  end

  flags << "-D OS_WIN32"
  flags << '-D BUILD_FOR_RUBY'
  flags << "-EHs"
  flags << "-GR"

  dir_config('xml2')
  unless have_library('xml2') and
	  have_header('libxml/parser.h') and
	  have_header('libxml/tree.h')
    exit
  end

when /solaris/
  unless have_library('pthread') and
	have_library('nsl') and
	have_library('socket')
	  exit
  end

  flags << '-D OS_UNIX'
  flags << '-D OS_SOLARIS8'
  flags << '-D BUILD_FOR_RUBY'

  dir_config('xml2')
  unless have_library('xml2') and
	  find_header('libxml/parser.h', '/usr/include/libxml2') and
	  find_header('libxml/tree.h', '/usr/include/libxml2')
    exit
  end

  # on Unix we need a g++ link, not gcc.
  CONFIG['LDSHARED'] = "$(CXX) -shared"

when /darwin/
  flags << '-DOS_UNIX'
  flags << '-DBUILD_FOR_RUBY'

  dir_config('xml2')
  unless have_library('xml2') and
	  find_header('libxml/parser.h', '/usr/include/libxml2') and
	  find_header('libxml/tree.h', '/usr/include/libxml2')
    exit
  end
  # on Unix we need a g++ link, not gcc.
  CONFIG['LDSHARED'] = "$(CXX) " + CONFIG['LDSHARED'].split[1..-1].join(' ')

else
  unless have_library('pthread')
	  exit
  end

  flags << '-DOS_UNIX'
  flags << '-DBUILD_FOR_RUBY'

  dir_config('xml2')
  unless have_library('xml2') and
	  find_header('libxml/parser.h', '/usr/include/libxml2') and
	  find_header('libxml/tree.h', '/usr/include/libxml2')
      exit
  end
  # on Unix we need a g++ link, not gcc.
  CONFIG['LDSHARED'] = "$(CXX) -shared"
end

if $CPPFLAGS
  $CPPFLAGS += ' ' + flags.join(' ')
else
  $CFLAGS += ' ' + flags.join(' ')
end


create_makefile "rubyxmlpushparser"

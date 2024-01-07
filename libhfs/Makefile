# libhfs - library for reading and writing Macintosh HFS volumes
# Copyright (C) 1996-1998 Robert Leslie
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# $Id: Makefile.in,v 1.11 1998/11/02 22:08:51 rob Exp $
#


src =		.

### USER CUSTOMIZATIONS FOLLOW ################################################

prefix =	/usr/local
exec_prefix =	${prefix}

SOFTLINK =	ln -s

OS =		unix

CC =		gcc
INCLUDES =	
DEFINES =	
LIBOBJS =	 memcmp.o
LIBS =		

COPTS =		-g -O2
LDOPTS =	

AR =		ar rc
RANLIB =	ranlib

### END OF USER CUSTOMIZATION #################################################

CFLAGS =	$(COPTS) $(INCLUDES) $(DEFINES)
LDFLAGS =	$(LDOPTS)

###############################################################################

TARGETS =	$(HFSTARGET)

HFSTARGET =	libhfs.a
HFSOBJS =	os.o data.o block.o low.o medium.o file.o btree.o node.o  \
			record.o volume.o hfs.o version.o $(LIBOBJS)

###############################################################################

all :: $(TARGETS)

check :: all
	@echo "No self-tests available."

again :: clean all

depend ::
	$(CC) -MM $(INCLUDES) $(DEFINES) *.c > deps.mk

clean ::
	rm -f $(TARGETS) *.o gmon.* core

###############################################################################

$(HFSTARGET): $(HFSOBJS)
	$(AR) $@ $(HFSOBJS)
	$(RANLIB) $@

os.c: os/$(OS).c
	rm -f $@
	$(SOFTLINK) os/$(OS).c $@

### DEPENDENCIES FOLLOW #######################################################

include deps.mk

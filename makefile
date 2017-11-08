CFLAGS ?= -O2 -Wall -Wextra -Wdeclaration-after-statement
CXXFLAGS ?= -O2 -Wall -Wextra

# default programs
CC ?= gcc
AR ?= ar
CXX ?= g++
SONAME_FLAG ?= -soname
CPP_STD ?= c++11

#----------------------------------------------------------------------
#-- Uncomment according to platform and/or GCC version.
#
# - CentOS	7.4/64		- gcc version 4.8.5
# - Debian 	7.11/64		- gcc version 4.7.2
# - openSUSE 	42.3/64  	- gcc version 4.8.5
# - Ubuntu	16.04/64	- gcc version 5.4.0
#
# (defaults work)

#-- CentOS	6.9/64 		- gcc version 4.4.7
#CPP_STD=gnu++0x

#-- Solaris	10/64  		- gcc version 4.8.1
#                                 not working with gcc 3.4.* due to non-availability of C++11
#SHELL=/bin/bash
#SONAME_FLAG=-h
#CC=gcc
#CXX=g++

#----------------------------------------------------------------------


#-- increment on incompatible API changes
LIB_VERSION_MAJOR=0
#-- increment on compatible API changes
LIB_VERSION_MINOR=1
#-- increment on bugfixes
LIB_VERSION_REV=0


LIB_VERSION_TRIPLE=$(LIB_VERSION_MAJOR).$(LIB_VERSION_MINOR).$(LIB_VERSION_REV)
LIB_INFO=-DZXCVBN_VERSION="\"$(LIB_VERSION_TRIPLE)\""  -DZXCVBN_GITREV="\"$(shell git rev-parse --short HEAD)\""

CFLAGS+=$(LIB_INFO)
CXXFLAGS+=$(LIB_INFO)


# need zxcvbn.h prior to package installation
CPPFLAGS += -I.

# library metadata
TARGET_LIB = libzxcvbn.so.$(LIB_VERSION_TRIPLE)
SONAME = libzxcvbn.so.$(LIB_VERSION_MAJOR)

WORDS = words-eng_wiki.txt words-female.txt words-male.txt words-passwd.txt words-surname.txt words-tv_film.txt

all: test-file test-inline test-c++inline test-c++file test-shlib test-statlib

test-shlib: test.c $(TARGET_LIB)
	if [ ! -e libzxcvbn.so ]; then ln -s $(TARGET_LIB) libzxcvbn.so; fi
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $< -L. $(LDFLAGS) -lzxcvbn -lm

$(TARGET_LIB): zxcvbn-inline-pic.o
	$(CC) $(CPPFLAGS) $(CFLAGS) \
		-o $@ $^ -fPIC -shared -Wl,$(SONAME_FLAG),$(SONAME) $(LDFLAGS) -lm
	if [ ! -e $(SONAME) ]; then ln -s $(TARGET_LIB) $(SONAME); fi

test-statlib: test.c libzxcvbn.a
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $^ $(LDFLAGS) -lm

libzxcvbn.a: zxcvbn-inline.o
	$(AR) cvq $@ $^

test-file: test.c zxcvbn-file.o
	$(CC) $(CPPFLAGS) $(CFLAGS) \
		-DUSE_DICT_FILE -o test-file test.c zxcvbn-file.o $(LDFLAGS) -lm

zxcvbn-file.o: zxcvbn.c dict-crc.h zxcvbn.h
	$(CC) $(CPPFLAGS) $(CFLAGS) \
		-DUSE_DICT_FILE -c -o zxcvbn-file.o zxcvbn.c

test-inline: test.c zxcvbn-inline.o
	$(CC) $(CPPFLAGS) $(CFLAGS) \
		-o test-inline test.c zxcvbn-inline.o $(LDFLAGS) -lm

zxcvbn-inline-pic.o: zxcvbn.c dict-src.h zxcvbn.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -fPIC -c -o $@ $<

zxcvbn-inline.o: zxcvbn.c dict-src.h zxcvbn.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o zxcvbn-inline.o zxcvbn.c

dict-src.h: dictgen $(WORDS)
	./dictgen -o dict-src.h $(WORDS)

dict-crc.h: dictgen $(WORDS)
	./dictgen -b -o zxcvbn.dict -h dict-crc.h $(WORDS)

dictgen: dict-generate.cpp makefile
	$(CXX) $(CPPFLAGS) -std=$(CPP_STD) $(CXXFLAGS) \
		-o dictgen dict-generate.cpp $(LDFLAGS)

test-c++inline: test.c zxcvbn-c++inline.o
	if [ ! -e test.cpp ]; then ln -s test.c test.cpp; fi
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) \
		-o test-c++inline test.cpp zxcvbn-c++inline.o $(LDFLAGS) -lm

zxcvbn-c++inline.o: zxcvbn.c dict-src.h zxcvbn.h
	if [ ! -e zxcvbn.cpp ]; then ln -s zxcvbn.c zxcvbn.cpp; fi
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) \
		-c -o zxcvbn-c++inline.o zxcvbn.cpp

test-c++file: test.c zxcvbn-c++file.o
	if [ ! -e test.cpp ]; then ln -s test.c test.cpp; fi
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) \
		-DUSE_DICT_FILE -o test-c++file test.cpp zxcvbn-c++file.o $(LDFLAGS) -lm

zxcvbn-c++file.o: zxcvbn.c dict-crc.h zxcvbn.h 
	if [ ! -e zxcvbn.cpp ]; then ln -s zxcvbn.c zxcvbn.cpp; fi
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) \
		-DUSE_DICT_FILE -c -o zxcvbn-c++file.o zxcvbn.cpp

test: test-file test-inline test-c++inline test-c++file test-shlib test-statlib testcases.txt
	@echo Testing C build, dictionary from file
	./test-file -t testcases.txt
	@echo Testing C build, dictionary in executable
	./test-inline -t testcases.txt
	@echo Testing C shlib, dictionary in shlib
	LD_LIBRARY_PATH=. ./test-shlib -t testcases.txt
	@echo Testing C static lib, dictionary in lib
	./test-statlib -t testcases.txt
	@echo Testing C++ build, dictionary from file
	./test-c++file -t testcases.txt
	@echo Testing C++ build, dictionary in executable
	./test-c++inline -t testcases.txt
	@echo Finished

clean:
	rm -f test-file zxcvbn-file.o test-c++file zxcvbn-c++file.o 
	rm -f test-inline zxcvbn-inline.o zxcvbn-inline-pic.o test-c++inline zxcvbn-c++inline.o
	rm -f dict-*.h zxcvbn.dict zxcvbn.cpp test.cpp zxcvbn.o
	rm -f dictgen
	rm -f ${TARGET_LIB} ${SONAME} libzxcvbn.so test-shlib libzxcvbn.a test-statlib
	rm -f *~

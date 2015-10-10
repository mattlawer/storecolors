CC=gcc
FRAMEWORKS= -framework Foundation -framework AppKit 
LIBRARIES= -lobjc

PRODUCT=storecolors
SRC=storecolors.m

CFLAGS=-Wall -g
LDFLAGS=$(LIBRARIES) $(FRAMEWORKS)

.PHONY: all clean install

all : storecolors clean

storecolors : $(SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRC) -o $(PRODUCT)

clean :
	rm -rf ./*.o ./*.dSYM

install :
	sudo cp storecolors /usr/local/bin/

	blog.mathieubolard.com
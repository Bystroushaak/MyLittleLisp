# Generic D project makefile by Bystroushaak (bystrousak@kitakitsune.org)
# Version: 1.1.0
# Date:    27.11.2011

BIND    = bin
SRCD    = src
RESD    = resources

# !!!DONT FORGET CHANGE THIS!!!
PROG    = $(BIND)/mll

DC      = dmd
DFLAGS  = -I$(SRCD)/ -J$(RESD)/ -c -O -debug -unittest
LDFLAGS =

# get source & object filenames
SRCS    = $(wildcard $(SRCD)/*.d)
OBJS    = $(SRCS:.d=.o)

.PHONY: all
.PHONY: toolkit
.PHONY: run
.PHONY: clean
.PHONY: distclean
.PHONY: help

all: $(OBJS)
	-mkdir $(BIND)
	@echo
	
	@echo "Linking together:"
	$(DC) $(LDFLAGS) $(SRCD)/*.o -of$(PROG)
	@echo
	
	@echo "Striping binaries:"
	-strip $(BIND)/*
	
	@echo "Successfully compiled"

run: all
	@clear
	@$(PROG)

%.o: %.d
	$(DC) $(DFLAGS) $? -of$@

clean:
	-rm *.o 
	-rm $(SRCD)/*.o
	
	-rm -fr $(BIND)
	
distclean: clean

help:
	@echo "all (default)"
	@echo "    Build project (needs 'git' and 'dmd' > v2.55)."
	@echo
	@echo run
	@echo "    Make and run binary."
	@echo
	@echo clean
	@echo "    Remove *.o and binary."
	@echo
	@echo distclean
	@echo "    Remove *.o, binaries and modules."
	@echo
	@echo help
	@echo "    Show this help."

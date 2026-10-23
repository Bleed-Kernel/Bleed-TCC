TCC_REPO    = https://github.com/TinyCC/tinycc.git
TCC_COMMIT  = e23dabed154a8495f3ac1ff3cc9d04fa1c207893
TCC_SRC     = external/tinycc

BLIBC_DIR  ?= $(if $(wildcard ../blibc/include/bleed),../blibc,external/blibc)
BLIBC_REPO  = https://github.com/Bleed-Kernel/blibc.git
KERNEL_DIR ?= ../Bleed-Kernel

CC_HOST    ?= cc
CC          = x86_64-elf-gcc

BUILD       = build
STAGE       = stage
SYSROOT     = $(BLIBC_DIR)/sysroot

HOST_TCC    = $(BUILD)/host-tcc
TCC_DEFS    = -DONE_SOURCE=1 -Ibleed -I$(BUILD)

LIBTCC1_O   = libtcc1.o stdatomic.o atomic.o builtin.o alloca.o va_list.o dsohandle.o

CFLAGS = \
	-ffreestanding \
	-fno-stack-protector \
	-fno-stack-check \
	-nostdlib \
	-no-pie \
	-m64 \
	-O2 \
	-w \
	-nostdinc \
	-I$(SYSROOT)/include \
	-I$(SYSROOT)/include/bleed

LDFLAGS = \
	-static \
	-nostdlib \
	-no-pie \
	-m64

.PHONY: all source blibc stage initrd install host-test clean distclean

all: bin/tcc stage

source: $(TCC_SRC)/.patched

$(TCC_SRC)/.patched: bleed/bleed.patch
	@if [ ! -d $(TCC_SRC) ]; then git clone $(TCC_REPO) $(TCC_SRC); fi
	cd $(TCC_SRC) && git checkout -q -f $(TCC_COMMIT) && git apply ../../bleed/bleed.patch
	@touch $@

blibc:
	@if [ ! -d "$(BLIBC_DIR)" ]; then git clone $(BLIBC_REPO) $(BLIBC_DIR); fi
	@$(MAKE) -C $(BLIBC_DIR) --no-print-directory

$(BUILD)/tccdefs_.h: $(TCC_SRC)/.patched bleed/tccdefs-bleed.h
	@mkdir -p $(BUILD)
	cat $(TCC_SRC)/include/tccdefs.h bleed/tccdefs-bleed.h > $(BUILD)/tccdefs.h
	$(CC_HOST) -DC2STR $(TCC_SRC)/conftest.c -o $(BUILD)/c2str
	$(BUILD)/c2str $(BUILD)/tccdefs.h $@

$(HOST_TCC): $(BUILD)/tccdefs_.h bleed/config.h
	$(CC_HOST) -O1 -w -o $@ $(TCC_SRC)/tcc.c $(TCC_DEFS) -DCONFIG_BLEED_ROOT='"$(abspath $(STAGE))"' -lm

bin/tcc: $(BUILD)/tccdefs_.h bleed/config.h $(SYSROOT)/lib/blibc.a | blibc
	@mkdir -p bin
	$(CC) $(CFLAGS) $(TCC_DEFS) -c $(TCC_SRC)/tcc.c -o $(BUILD)/tcc.o
	$(CC) $(LDFLAGS) -o $@ $(SYSROOT)/lib/start.o $(BUILD)/tcc.o $(SYSROOT)/lib/blibc.a -lgcc

stage: $(HOST_TCC) | blibc
	@mkdir -p $(STAGE)/lib/tcc/include $(STAGE)/include $(BUILD)/lib
	cp -R $(SYSROOT)/include/* $(STAGE)/include/
	cp $(SYSROOT)/lib/blibc.a $(STAGE)/lib/libc.a
	cp $(SYSROOT)/lib/start.o $(STAGE)/lib/crt1.o
	printf '' > $(BUILD)/empty.c
	$(HOST_TCC) -c $(BUILD)/empty.c -o $(STAGE)/lib/crti.o
	$(HOST_TCC) -c $(BUILD)/empty.c -o $(STAGE)/lib/crtn.o
	cp $(TCC_SRC)/include/*.h $(STAGE)/lib/tcc/include/
	cd $(BUILD)/lib && for o in $(LIBTCC1_O); do \
		src=$$(ls ../../$(TCC_SRC)/lib/$${o%.o}.[cS]); \
		../../$(HOST_TCC) -c $$src -I../../$(TCC_SRC) -o $$o || exit 1; \
	done
	$(HOST_TCC) -ar rcs $(STAGE)/lib/tcc/libtcc1.a $(addprefix $(BUILD)/lib/,$(LIBTCC1_O))
	@mkdir -p $(STAGE)/src
	cp examples/*.c $(STAGE)/src/

host-test: stage
	@mkdir -p $(BUILD)/tests
	for t in examples/*.c; do \
		$(HOST_TCC) $$t -o $(BUILD)/tests/$$(basename $$t .c) || exit 1; \
	done
	@ls -l $(BUILD)/tests

initrd: stage
	@test -n "$(INITRD)" || { echo "make initrd INITRD=<the kernels initrd folder>"; exit 1; }
	mkdir -p $(INITRD)
	COPYFILE_DISABLE=1 cp -R $(STAGE)/* $(INITRD)/

install: bin/tcc
	COPYFILE_DISABLE=1 cp bin/tcc $(KERNEL_DIR)/initrd/bin/tcc
	$(MAKE) initrd INITRD=$(abspath $(KERNEL_DIR)/initrd)

clean:
	rm -rf $(BUILD) $(STAGE) bin

distclean: clean
	rm -rf external

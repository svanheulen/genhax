CC=$(DEVKITARM)/bin/arm-none-eabi-gcc
CFLAGS=-x assembler-with-cpp
OBJCPY=$(DEVKITARM)/bin/arm-none-eabi-objcopy

CRR_HASH_COUNT=96

.PHONY: all jpn eur usa clean

all: jpn eur usa
jpn: build/JPN_event.arc build/JPN_challenge.arc
eur: build/EUR_event.arc build/EUR_challenge.arc
usa: build/USA_event.arc build/USA_challenge.arc
clean:
	rm -rf build

build/%_nopsled.o: nopsled.s
	mkdir -p build
	$(CC) $(CFLAGS) -c -o $@ -D$* $<

build/%_nopsled.cro: build/%_nopsled.o
	$(OBJCPY) -O binary $< $@
	python patch_cro.py $@ $(CRR_HASH_COUNT)

build/%_payload.o: build/%_nopsled.cro payload.s
	$(CC) $(CFLAGS) -c -o $@ -D$* -DCRR_HASH_COUNT=$(CRR_HASH_COUNT) -DCRO_FILE_PATH=\"$<\" payload.s

build/%_payload.cro: build/%_payload.o
	$(OBJCPY) -O binary $< $@
	python patch_cro.py $@ $(CRR_HASH_COUNT)

build/%_exploit.o: build/%_payload.cro exploit.s
	$(CC) $(CFLAGS) -c -o $@ -D$* -DCRR_HASH_COUNT=$(CRR_HASH_COUNT) -DCRO_FILE_PATH=\"$<\" exploit.s

build/%_exploit.tex: build/%_exploit.o
	$(OBJCPY) -O binary $< $@

build/%_event.arc: build/%_exploit.tex
	python make_quest.py -q 1010001 $* $< $@

build/%_challenge.arc: build/%_exploit.tex
	python make_quest.py -q 1020001 $* $< $@


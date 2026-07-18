ARCH = arm64
SDK  = $(shell xcrun -sdk macosx --show-sdk-path)
SDK_VERSION = $(shell xcrun -sdk macosx --show-sdk-version)
MACOS_MIN = 12.0

calc: calc.o
	ld -arch $(ARCH) -o $@ $< \
	   -lSystem -lobjc \
	   -framework Cocoa -framework QuartzCore \
	   -syslibroot $(SDK) \
	   -platform_version macos $(MACOS_MIN) $(SDK_VERSION) \
	   -e _main

calc.o: calc.s
	as -arch $(ARCH) -mmacos-version-min=$(MACOS_MIN) -o $@ $<

run: calc
	./calc

clean:
	rm -f calc calc.o

.PHONY: run clean

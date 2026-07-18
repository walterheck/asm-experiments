ARCH = arm64
SDK = $(shell xcrun -sdk macosx --show-sdk-path)
SDK_VERSION = $(shell xcrun -sdk macosx --show-sdk-version)
MACOS_MIN = 12.0
APP = ASMVERSE.app

all: $(APP)

$(APP): asmverse Info.plist
	mkdir -p $(APP)/Contents/MacOS
	cp asmverse $(APP)/Contents/MacOS/ASMVERSE
	cp Info.plist $(APP)/Contents/Info.plist

asmverse: asmverse.o
	ld -arch $(ARCH) -o $@ $< \
	   -lSystem -lobjc \
	   -framework Cocoa -framework QuartzCore \
	   -syslibroot $(SDK) \
	   -platform_version macos $(MACOS_MIN) $(SDK_VERSION) \
	   -e _main

asmverse.o: asmverse.s
	as -arch $(ARCH) -mmacos-version-min=$(MACOS_MIN) -o $@ $<

run: $(APP)
	open $(APP)

clean:
	rm -f asmverse asmverse.o
	rm -rf $(APP)

.PHONY: all run clean

# Calculator — a macOS GUI app in pure arm64 assembly

A working Cocoa calculator written entirely in AArch64 assembly (`calc.s`).
No C, Objective-C, or Swift sources — the app drives AppKit and Core
Animation directly through libSystem and the Objective-C runtime
(`objc_msgSend`, `objc_allocateClassPair`, `class_addMethod`, …).

## Features

- Native `NSWindow` with a 4×5 `NSButton` grid and a big right-aligned display
- `+  −  ×  ÷  %  ±  C  .` and chained operations (`2 + 3 + 4 =`)
- **Fireworks while calculating**: five sparkle layers burst over the display
  every time a result is computed, while every pressed button still flickers
  subtly — all done with `CABasicAnimation` built via `objc_msgSend`
- Menu bar with a working **⌘Q Quit**; the app also quits when the window is
  closed (the `applicationShouldTerminateAfterLastWindowClosed:` delegate
  method is an assembly routine registered at runtime)

## Requirements

- Apple Silicon Mac (the code is arm64-only)
- Xcode Command Line Tools (`xcode-select --install`)
- macOS 12+ (uses `labelWithString:` / `buttonWithTitle:target:action:`,
  available since 10.12)

## Build & run

```sh
make
./calc
```

If you prefer a single command, the clang *driver* (still assembling the same
pure-asm source) also works:

```sh
clang -o calc calc.s -framework Cocoa -framework QuartzCore
```

## How it works

1. **Startup** (`_init_tables`): every selector name is passed through
   `sel_registerName` and every class through `objc_getClass` once, and the
   results are cached in arrays. The `SEL`/`CLS` assembler macros then load
   them by index.
2. **A real Objective-C class from assembly**: `CalcController` is created at
   runtime with `objc_allocateClassPair`; `buttonClicked:` and
   `applicationShouldTerminateAfterLastWindowClosed:` are plain assembly
   functions registered as method IMPs via `class_addMethod`.
3. **UI construction**: window, label, buttons, and the menu bar are all
   built with chains of `objc_msgSend` calls. `NSRect` arguments are passed
   in `d0–d3` (a homogeneous floating-point aggregate under the arm64 ABI).
4. **Calculator logic**: the current entry lives in a byte buffer; values are
   converted with `strtod` and formatted back with `snprintf("%.10g")`
   (note: Darwin arm64 passes *variadic* arguments on the stack, which is why
   the double is stored at `[sp]` before the call).
5. **Animation** (`_fireworks`): bursts five sparkle labels with simultaneous
   opacity and scale animations over the result display. `_pulse` remains as
   subtle button feedback. Views are made layer-backed with `setWantsLayer:`
   at build time.

## Notes

- Raw `svc` syscalls are deliberately avoided — Apple's supported ABI is
  through libSystem, and syscall numbers are private and unstable.
- Objects are never released; everything the app creates lives for its whole
  lifetime, so no reference-counting code is needed.

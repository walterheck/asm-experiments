// =============================================================================
// calc.s — a GUI calculator for macOS written in pure arm64 assembly.
//
// No C, no Objective-C, no Swift sources. The app talks to AppKit and
// QuartzCore directly through libSystem + the Objective-C runtime
// (objc_msgSend and friends), which is the Apple-supported way to make
// system calls from assembly.
//
// Features:
//   * NSWindow with a 4x5 button grid and a right-aligned display label
//   * +, -, x, /, %, +/-, C, decimal point, chained operations
//   * Core Animation fireworks over the display whenever a result is
//     calculated, plus a subtle flicker on every pressed button
//   * Menu bar with a working Cmd+Q "Quit"
//   * Quits when the window is closed (app delegate method implemented in asm)
//
// Build (Apple Silicon Mac with Xcode Command Line Tools):  make
// =============================================================================

// ---------------------------------------------------------------- macros ----

.macro GADDR reg, sym                 // reg = &sym
    adrp    \reg, \sym@PAGE
    add     \reg, \reg, \sym@PAGEOFF
.endm

.macro GLOAD reg, sym                 // reg = *(u64 *)&sym
    adrp    \reg, \sym@PAGE
    ldr     \reg, [\reg, \sym@PAGEOFF]
.endm

.macro GSTORE valreg, sym, scratch    // *(u64 *)&sym = valreg
    adrp    \scratch, \sym@PAGE
    str     \valreg, [\scratch, \sym@PAGEOFF]
.endm

.macro SEL reg, idx                   // reg = cached selector [idx]
    GADDR   \reg, _sels
    ldr     \reg, [\reg, #(\idx * 8)]
.endm

.macro CLS reg, idx                   // reg = cached class [idx]
    GADDR   \reg, _classes
    ldr     \reg, [\reg, #(\idx * 8)]
.endm

// ------------------------------------------------------- selector indices ---

.equ S_sharedApplication,          0
.equ S_setActivationPolicy,        1
.equ S_alloc,                      2
.equ S_init,                       3
.equ S_initWithContentRect,        4
.equ S_center,                     5
.equ S_setTitle,                   6
.equ S_contentView,                7
.equ S_addSubview,                 8
.equ S_makeKeyAndOrderFront,       9
.equ S_activateIgnoringOtherApps, 10
.equ S_run,                       11
.equ S_stringWithUTF8String,      12
.equ S_labelWithString,           13
.equ S_setFrame,                  14
.equ S_setFont,                   15
.equ S_monoFont,                  16
.equ S_setAlignment,              17
.equ S_buttonWithTitle,           18
.equ S_setTag,                    19
.equ S_tag,                       20
.equ S_setStringValue,            21
.equ S_setWantsLayer,             22
.equ S_layer,                     23
.equ S_animationWithKeyPath,      24
.equ S_setFromValue,              25
.equ S_setToValue,                26
.equ S_setDuration,               27
.equ S_setAutoreverses,           28
.equ S_setRepeatCount,            29
.equ S_addAnimationForKey,        30
.equ S_numberWithDouble,          31
.equ S_addItem,                   32
.equ S_setMainMenu,               33
.equ S_initWithTitleActionKey,    34
.equ S_setSubmenu,                35
.equ S_terminate,                 36
.equ S_buttonClicked,             37
.equ S_setDelegate,               38
.equ S_shouldTerminate,           39
.equ S_systemFontOfSize,          40
.equ S_setOpacity,                41

// ----------------------------------------------------------- class indices --

.equ C_NSApplication,     0
.equ C_NSWindow,          1
.equ C_NSString,          2
.equ C_NSTextField,       3
.equ C_NSButton,          4
.equ C_NSFont,            5
.equ C_CABasicAnimation,  6
.equ C_NSNumber,          7
.equ C_NSMenu,            8
.equ C_NSMenuItem,        9
.equ C_NSObject,         10

// Button tags: 0-9 digits, 10 '.', 11 '=', 12 '+', 13 '-', 14 'x', 15 '/',
//              16 'C', 17 '+/-', 18 '%'

// ====================================================================== code

.text
.p2align 2
.globl _main
_main:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]

    bl      _init_tables
    bl      _objc_autoreleasePoolPush

    // NSApp = [NSApplication sharedApplication]
    CLS     x0, C_NSApplication
    SEL     x1, S_sharedApplication
    bl      _objc_msgSend
    mov     x19, x0

    // [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular]
    mov     x0, x19
    SEL     x1, S_setActivationPolicy
    mov     x2, #0
    bl      _objc_msgSend

    // ---- build the CalcController class at runtime -------------------------
    CLS     x0, C_NSObject
    GADDR   x1, L_s_ctrlname
    mov     x2, #0
    bl      _objc_allocateClassPair
    mov     x20, x0

    SEL     x1, S_buttonClicked
    GADDR   x2, _buttonClicked
    GADDR   x3, L_s_type_action
    bl      _class_addMethod

    mov     x0, x20
    SEL     x1, S_shouldTerminate
    GADDR   x2, _shouldTerminate
    GADDR   x3, L_s_type_bool
    bl      _class_addMethod

    mov     x0, x20
    bl      _objc_registerClassPair

    mov     x0, x20                       // controller = [[CalcController alloc] init]
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_init
    bl      _objc_msgSend
    mov     x22, x0
    GSTORE  x22, _controller, x9

    mov     x0, x19                       // [NSApp setDelegate:controller]
    SEL     x1, S_setDelegate
    mov     x2, x22
    bl      _objc_msgSend

    // ---- menu bar with a working Cmd+Q ------------------------------------
    CLS     x0, C_NSMenu                  // menubar = [[NSMenu alloc] init]
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_init
    bl      _objc_msgSend
    mov     x25, x0

    CLS     x0, C_NSMenuItem              // appItem = [[NSMenuItem alloc] init]
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_init
    bl      _objc_msgSend
    mov     x26, x0

    mov     x0, x25                       // [menubar addItem:appItem]
    SEL     x1, S_addItem
    mov     x2, x26
    bl      _objc_msgSend

    mov     x0, x19                       // [NSApp setMainMenu:menubar]
    SEL     x1, S_setMainMenu
    mov     x2, x25
    bl      _objc_msgSend

    CLS     x0, C_NSMenu                  // appMenu = [[NSMenu alloc] init]
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_init
    bl      _objc_msgSend
    mov     x27, x0

    GADDR   x0, L_s_quit
    bl      _mkstr
    mov     x20, x0                       // "Quit Calculator"
    GADDR   x0, L_s_q
    bl      _mkstr
    mov     x21, x0                       // "q"

    CLS     x0, C_NSMenuItem              // quit = [[NSMenuItem alloc]
    SEL     x1, S_alloc                   //   initWithTitle:action:keyEquivalent:]
    bl      _objc_msgSend
    SEL     x1, S_initWithTitleActionKey
    mov     x2, x20
    SEL     x3, S_terminate
    mov     x4, x21
    bl      _objc_msgSend
    mov     x28, x0

    mov     x0, x27                       // [appMenu addItem:quit]
    SEL     x1, S_addItem
    mov     x2, x28
    bl      _objc_msgSend

    mov     x0, x26                       // [appItem setSubmenu:appMenu]
    SEL     x1, S_setSubmenu
    mov     x2, x27
    bl      _objc_msgSend

    // ---- window ------------------------------------------------------------
    CLS     x0, C_NSWindow
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initWithContentRect     // NSRect passed in d0..d3 (HFA)
    fmov    d0, xzr                       // x = 0
    fmov    d1, xzr                       // y = 0
    GADDR   x9, L_c_winsize
    ldp     d2, d3, [x9]                  // w = 260, h = 342
    mov     x2, #7                        // titled|closable|miniaturizable
    mov     x3, #2                        // NSBackingStoreBuffered
    mov     x4, #0                        // defer:NO
    bl      _objc_msgSend
    mov     x23, x0

    mov     x0, x23                       // [window center]
    SEL     x1, S_center
    bl      _objc_msgSend

    GADDR   x0, L_s_title                 // [window setTitle:@"Calculator (pure asm)"]
    bl      _mkstr
    mov     x2, x0
    mov     x0, x23
    SEL     x1, S_setTitle
    bl      _objc_msgSend

    mov     x0, x23                       // content = [window contentView]
    SEL     x1, S_contentView
    bl      _objc_msgSend
    mov     x24, x0

    // ---- display label -------------------------------------------------------
    GADDR   x0, L_s_zero                  // display = [NSTextField labelWithString:@"0"]
    bl      _mkstr
    mov     x2, x0
    CLS     x0, C_NSTextField
    SEL     x1, S_labelWithString
    bl      _objc_msgSend
    mov     x20, x0
    GSTORE  x20, _display, x9

    mov     x0, x20                       // [display setFrame:(10, 272, 240, 60)]
    SEL     x1, S_setFrame
    GADDR   x9, L_c_disprect
    ldp     d0, d1, [x9]
    ldp     d2, d3, [x9, #16]
    bl      _objc_msgSend

    CLS     x0, C_NSFont                  // big monospaced-digit system font
    SEL     x1, S_monoFont
    GADDR   x9, L_c_fontsize
    ldr     d0, [x9]
    fmov    d1, xzr                       // NSFontWeightRegular
    bl      _objc_msgSend
    mov     x2, x0
    mov     x0, x20
    SEL     x1, S_setFont
    bl      _objc_msgSend

    mov     x0, x20                       // right-aligned (macOS: right == 1)
    SEL     x1, S_setAlignment
    mov     x2, #1
    bl      _objc_msgSend

    mov     x0, x20                       // layer-backed so we can animate it
    SEL     x1, S_setWantsLayer
    mov     x2, #1
    bl      _objc_msgSend

    mov     x0, x24                       // [content addSubview:display]
    SEL     x1, S_addSubview
    mov     x2, x20
    bl      _objc_msgSend

    // ---- fireworks overlay -------------------------------------------------
    // Five transparent sparkle labels sit over the display. They remain
    // invisible until _fireworks applies scale + opacity animations.
    CLS     x0, C_NSFont
    SEL     x1, S_systemFontOfSize
    GADDR   x9, L_c_sparkfontsize
    ldr     d0, [x9]
    bl      _objc_msgSend
    mov     x28, x0                       // shared sparkle font

    GADDR   x25, _spark_defs
    GADDR   x27, _sparkles
Lspark_init:
    ldr     x0, [x25]                     // glyph C string (NULL terminates)
    cbz     x0, Lspark_done
    bl      _mkstr
    mov     x2, x0
    CLS     x0, C_NSTextField
    SEL     x1, S_labelWithString
    bl      _objc_msgSend
    mov     x26, x0
    str     x26, [x27], #8

    mov     x0, x26
    SEL     x1, S_setFrame
    ldp     d0, d1, [x25, #8]
    ldp     d2, d3, [x25, #24]
    bl      _objc_msgSend

    mov     x0, x26
    SEL     x1, S_setFont
    mov     x2, x28
    bl      _objc_msgSend

    mov     x0, x26
    SEL     x1, S_setAlignment
    mov     x2, #2                        // NSTextAlignmentCenter
    bl      _objc_msgSend

    mov     x0, x26
    SEL     x1, S_setWantsLayer
    mov     x2, #1
    bl      _objc_msgSend

    mov     x0, x26                       // sparkle.layer.opacity = 0
    SEL     x1, S_layer
    bl      _objc_msgSend
    SEL     x1, S_setOpacity
    fmov    s0, wzr
    bl      _objc_msgSend

    mov     x0, x24
    SEL     x1, S_addSubview
    mov     x2, x26
    bl      _objc_msgSend

    add     x25, x25, #40
    b       Lspark_init
Lspark_done:

    // ---- buttons -------------------------------------------------------------
    GADDR   x25, _buttons
Lbtn_loop:
    ldr     x0, [x25]                     // title C string (NULL terminates list)
    cbz     x0, Lbtn_done
    bl      _mkstr
    mov     x2, x0
    CLS     x0, C_NSButton                // [NSButton buttonWithTitle:target:action:]
    SEL     x1, S_buttonWithTitle
    GLOAD   x3, _controller
    SEL     x4, S_buttonClicked
    bl      _objc_msgSend
    mov     x26, x0

    // frame: x = 10 + 62*col   y = 10 + 52*row   w = 62*cells - 8   h = 44
    ldrb    w9, [x25, #9]                 // col
    mov     w12, #62
    mul     w9, w9, w12
    add     w9, w9, #10
    scvtf   d0, w9
    ldrb    w10, [x25, #10]               // row
    mov     w12, #52
    mul     w10, w10, w12
    add     w10, w10, #10
    scvtf   d1, w10
    ldrb    w11, [x25, #11]               // width in cells
    mov     w12, #62
    mul     w11, w11, w12
    sub     w11, w11, #8
    scvtf   d2, w11
    mov     w12, #44
    scvtf   d3, w12
    mov     x0, x26
    SEL     x1, S_setFrame
    bl      _objc_msgSend

    ldrb    w2, [x25, #8]                 // [button setTag:...]
    mov     x0, x26
    SEL     x1, S_setTag
    bl      _objc_msgSend

    mov     x0, x26                       // layer-backed for press animation
    SEL     x1, S_setWantsLayer
    mov     x2, #1
    bl      _objc_msgSend

    mov     x0, x24                       // [content addSubview:button]
    SEL     x1, S_addSubview
    mov     x2, x26
    bl      _objc_msgSend

    add     x25, x25, #16
    b       Lbtn_loop
Lbtn_done:

    // ---- show it and run ------------------------------------------------------
    mov     x0, x23                       // [window makeKeyAndOrderFront:nil]
    SEL     x1, S_makeKeyAndOrderFront
    mov     x2, #0
    bl      _objc_msgSend

    mov     x0, x19                       // [NSApp activateIgnoringOtherApps:YES]
    SEL     x1, S_activateIgnoringOtherApps
    mov     x2, #1
    bl      _objc_msgSend

    mov     x0, x19                       // [NSApp run]  (never returns)
    SEL     x1, S_run
    bl      _objc_msgSend

    mov     w0, #0
    ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// ------------------------------------------------------------ init_tables ---
// Registers every selector and looks up every class once, caching them in
// the _sels / _classes arrays used by the SEL / CLS macros.

.p2align 2
_init_tables:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    GADDR   x19, _sel_names
    GADDR   x20, _sels
1:
    ldr     x0, [x19], #8
    cbz     x0, 2f
    bl      _sel_registerName
    str     x0, [x20], #8
    b       1b
2:
    GADDR   x19, _class_names
    GADDR   x20, _classes
3:
    ldr     x0, [x19], #8
    cbz     x0, 4f
    bl      _objc_getClass
    str     x0, [x20], #8
    b       3b
4:
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ------------------------------------------------------------------- mkstr --
// x0 = C string  ->  x0 = NSString (autoreleased)

.p2align 2
_mkstr:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x2, x0
    CLS     x0, C_NSString
    SEL     x1, S_stringWithUTF8String
    bl      _objc_msgSend
    ldp     x29, x30, [sp], #16
    ret

// ---------------------------------------------------------- updateDisplay ---
// Pushes _entryBuf into the display label.

.p2align 2
_updateDisplay:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    GADDR   x0, _entryBuf
    bl      _mkstr
    mov     x2, x0
    GLOAD   x0, _display
    SEL     x1, S_setStringValue
    bl      _objc_msgSend
    ldp     x29, x30, [sp], #16
    ret

// ---------------------------------------------------------- format_to_buf ---
// d0 = value. snprintf(_entryBuf, 32, "%.10g", d0); _entryLen = strlen(buf).
// Darwin arm64 passes variadic args on the stack, so d0 goes at [sp].

.p2align 2
_format_to_buf:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    sub     sp, sp, #16
    str     d0, [sp]
    GADDR   x0, _entryBuf
    mov     x1, #32
    GADDR   x2, L_fmt_g
    bl      _snprintf
    add     sp, sp, #16
    GADDR   x0, _entryBuf
    bl      _strlen
    GSTORE  x0, _entryLen, x9
    ldp     x29, x30, [sp], #16
    ret

// -------------------------------------------------------------------- pulse --
// x0 = view. Adds a CABasicAnimation to the view's layer: opacity 1 -> 0.25,
// autoreversed, repeated twice — a quick "calculating" flicker.

.p2align 2
_pulse:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    str     x21, [sp, #32]
    mov     x19, x0

    GADDR   x0, L_s_opacity               // anim = [CABasicAnimation
    bl      _mkstr                        //   animationWithKeyPath:@"opacity"]
    mov     x2, x0
    CLS     x0, C_CABasicAnimation
    SEL     x1, S_animationWithKeyPath
    bl      _objc_msgSend
    mov     x20, x0

    CLS     x0, C_NSNumber                // anim.fromValue = @1.0
    SEL     x1, S_numberWithDouble
    fmov    d0, #1.0
    bl      _objc_msgSend
    mov     x2, x0
    mov     x0, x20
    SEL     x1, S_setFromValue
    bl      _objc_msgSend

    CLS     x0, C_NSNumber                // anim.toValue = @0.25
    SEL     x1, S_numberWithDouble
    fmov    d0, #0.25
    bl      _objc_msgSend
    mov     x2, x0
    mov     x0, x20
    SEL     x1, S_setToValue
    bl      _objc_msgSend

    mov     x0, x20                       // anim.duration = 0.09
    SEL     x1, S_setDuration
    GADDR   x9, L_c_pulsedur
    ldr     d0, [x9]
    bl      _objc_msgSend

    mov     x0, x20                       // anim.autoreverses = YES
    SEL     x1, S_setAutoreverses
    mov     x2, #1
    bl      _objc_msgSend

    mov     x0, x20                       // anim.repeatCount = 2 (float in s0)
    SEL     x1, S_setRepeatCount
    fmov    s0, #2.0
    bl      _objc_msgSend

    GADDR   x0, L_s_pulsekey
    bl      _mkstr
    mov     x21, x0

    mov     x0, x19                       // [[view layer] addAnimation:anim
    SEL     x1, S_layer                   //                     forKey:@"calcPulse"]
    bl      _objc_msgSend
    SEL     x1, S_addAnimationForKey
    mov     x2, x20
    mov     x3, x21
    bl      _objc_msgSend

    ldr     x21, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// --------------------------------------------------------------- firework ---
// x0 = sparkle view. Runs two animations together: a rapid fade in/out and
// an expanding scale. The backing layer's model opacity stays at zero, so
// the sparkle disappears cleanly when Core Animation removes the animations.

.p2align 2
_firework:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     x23, [sp, #48]
    mov     x19, x0

    mov     x0, x19                       // layer = [sparkle layer]
    SEL     x1, S_layer
    bl      _objc_msgSend
    mov     x20, x0

    GADDR   x0, L_s_opacity               // opacity animation: 0 -> 1 -> 0
    bl      _mkstr
    mov     x2, x0
    CLS     x0, C_CABasicAnimation
    SEL     x1, S_animationWithKeyPath
    bl      _objc_msgSend
    mov     x21, x0

    CLS     x0, C_NSNumber
    SEL     x1, S_numberWithDouble
    fmov    d0, xzr
    bl      _objc_msgSend
    mov     x2, x0
    mov     x0, x21
    SEL     x1, S_setFromValue
    bl      _objc_msgSend

    CLS     x0, C_NSNumber
    SEL     x1, S_numberWithDouble
    fmov    d0, #1.0
    bl      _objc_msgSend
    mov     x2, x0
    mov     x0, x21
    SEL     x1, S_setToValue
    bl      _objc_msgSend

    mov     x0, x21
    SEL     x1, S_setDuration
    GADDR   x9, L_c_fireworkdur
    ldr     d0, [x9]
    bl      _objc_msgSend

    mov     x0, x21
    SEL     x1, S_setAutoreverses
    mov     x2, #1
    bl      _objc_msgSend

    GADDR   x0, L_s_fireopacity
    bl      _mkstr
    mov     x23, x0
    mov     x0, x20
    SEL     x1, S_addAnimationForKey
    mov     x2, x21
    mov     x3, x23
    bl      _objc_msgSend

    GADDR   x0, L_s_scale                 // scale animation: 0.15 -> 1.75 -> 0.15
    bl      _mkstr
    mov     x2, x0
    CLS     x0, C_CABasicAnimation
    SEL     x1, S_animationWithKeyPath
    bl      _objc_msgSend
    mov     x22, x0

    CLS     x0, C_NSNumber
    SEL     x1, S_numberWithDouble
    GADDR   x9, L_c_sparkfrom
    ldr     d0, [x9]
    bl      _objc_msgSend
    mov     x2, x0
    mov     x0, x22
    SEL     x1, S_setFromValue
    bl      _objc_msgSend

    CLS     x0, C_NSNumber
    SEL     x1, S_numberWithDouble
    GADDR   x9, L_c_sparkto
    ldr     d0, [x9]
    bl      _objc_msgSend
    mov     x2, x0
    mov     x0, x22
    SEL     x1, S_setToValue
    bl      _objc_msgSend

    mov     x0, x22
    SEL     x1, S_setDuration
    GADDR   x9, L_c_fireworkdur
    ldr     d0, [x9]
    bl      _objc_msgSend

    mov     x0, x22
    SEL     x1, S_setAutoreverses
    mov     x2, #1
    bl      _objc_msgSend

    GADDR   x0, L_s_firescale
    bl      _mkstr
    mov     x23, x0
    mov     x0, x20
    SEL     x1, S_addAnimationForKey
    mov     x2, x22
    mov     x3, x23
    bl      _objc_msgSend

    ldr     x23, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// -------------------------------------------------------------- fireworks ---
// Bursts every sparkle over the calculator display.

.p2align 2
_fireworks:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    GADDR   x19, _sparkles
1:
    ldr     x0, [x19], #8
    cbz     x0, 2f
    bl      _firework
    b       1b
2:
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ------------------------------------------------------------ applyPending ---
// entry = strtod(_entryBuf); acc = acc <pending-op> entry (or entry if none);
// formats the result, updates the display and launches fireworks.

.p2align 2
_applyPending:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    GADDR   x0, _entryBuf
    mov     x1, #0
    bl      _strtod                       // d0 = entry value
    GADDR   x9, _acc
    ldr     d1, [x9]
    GLOAD   x10, _pending
    cmp     x10, #12
    b.eq    1f
    cmp     x10, #13
    b.eq    2f
    cmp     x10, #14
    b.eq    3f
    cmp     x10, #15
    b.eq    4f
    fmov    d1, d0                        // no pending op: acc = entry
    b       5f
1:  fadd    d1, d1, d0
    b       5f
2:  fsub    d1, d1, d0
    b       5f
3:  fmul    d1, d1, d0
    b       5f
4:  fdiv    d1, d1, d0
5:
    str     d1, [x9]
    fmov    d0, d1
    bl      _format_to_buf
    bl      _updateDisplay
    bl      _fireworks
    ldp     x29, x30, [sp], #16
    ret

// ------------------------------------------------------------ buttonClicked ---
// IMP for -[CalcController buttonClicked:]  (x0 self, x1 _cmd, x2 sender)

.p2align 2
_buttonClicked:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     x20, x2                       // sender

    mov     x0, x2                        // tag = [sender tag]
    SEL     x1, S_tag
    bl      _objc_msgSend
    mov     x19, x0

    cmp     x19, #9
    b.le    Ldigit
    cmp     x19, #10
    b.eq    Ldot
    cmp     x19, #11
    b.eq    Lequals
    cmp     x19, #16
    b.eq    Lclear
    cmp     x19, #17
    b.eq    Lnegate
    cmp     x19, #18
    b.eq    Lpercent
					// tags 12..15: operators
Lop:
    GLOAD   x9, _startNew                 // pressing +,-,x,/ twice in a row
    cbnz    x9, 1f                        // only swaps the pending op
    bl      _applyPending
1:
    GSTORE  x19, _pending, x9
    mov     x9, #1
    GSTORE  x9, _startNew, x10
    b       Ldone

Ldigit:
    GADDR   x9, _startNew
    ldr     x10, [x9]
    cbz     x10, 1f
    str     xzr, [x9]                     // fresh entry after op / equals
    GSTORE  xzr, _entryLen, x11
1:
    GLOAD   x10, _entryLen
    cmp     x10, #1                       // collapse a lone leading "0"
    b.ne    2f
    GADDR   x11, _entryBuf
    ldrb    w12, [x11]
    cmp     w12, #48                      // '0'
    b.ne    2f
    mov     x10, #0
2:
    cmp     x10, #24                      // cap entry length
    b.ge    3f
    GADDR   x11, _entryBuf
    add     w12, w19, #48                 // '0' + digit
    strb    w12, [x11, x10]
    add     x10, x10, #1
    strb    wzr, [x11, x10]
    GSTORE  x10, _entryLen, x11
3:
    bl      _updateDisplay
    b       Ldone

Ldot:
    GADDR   x9, _startNew
    ldr     x10, [x9]
    cbz     x10, 1f
    str     xzr, [x9]                     // fresh entry: start from "0"
    GADDR   x11, _entryBuf
    mov     w12, #48
    strb    w12, [x11]
    strb    wzr, [x11, #1]
    mov     x10, #1
    GSTORE  x10, _entryLen, x12
1:
    GLOAD   x10, _entryLen
    GADDR   x11, _entryBuf
    mov     x13, #0
2:
    cmp     x13, x10                      // reject a second '.'
    b.ge    3f
    ldrb    w12, [x11, x13]
    cmp     w12, #46                      // '.'
    b.eq    4f
    add     x13, x13, #1
    b       2b
3:
    cmp     x10, #23
    b.ge    4f
    mov     w12, #46
    strb    w12, [x11, x10]
    add     x10, x10, #1
    strb    wzr, [x11, x10]
    GSTORE  x10, _entryLen, x12
4:
    bl      _updateDisplay
    b       Ldone

Lequals:
    GLOAD   x9, _startNew
    cbnz    x9, 1f
    bl      _applyPending                 // launches fireworks itself
    b       2f
1:
    bl      _fireworks                    // nothing to compute — celebrate anyway
2:
    GSTORE  xzr, _pending, x9
    mov     x9, #1
    GSTORE  x9, _startNew, x10
    b       Ldone

Lclear:
    GADDR   x9, _acc
    str     xzr, [x9]
    GSTORE  xzr, _pending, x9
    GSTORE  xzr, _startNew, x9
    GADDR   x11, _entryBuf
    mov     w12, #48                      // buf = "0"
    strb    w12, [x11]
    strb    wzr, [x11, #1]
    mov     x10, #1
    GSTORE  x10, _entryLen, x9
    bl      _updateDisplay
    b       Ldone

Lnegate:
    GADDR   x0, _entryBuf
    mov     x1, #0
    bl      _strtod
    fneg    d0, d0
    bl      _format_to_buf
    bl      _updateDisplay
    b       Ldone

Lpercent:
    GADDR   x0, _entryBuf
    mov     x1, #0
    bl      _strtod
    GADDR   x9, L_c_hundred
    ldr     d1, [x9]
    fdiv    d0, d0, d1
    bl      _format_to_buf
    bl      _updateDisplay
    b       Ldone

Ldone:
    mov     x0, x20                       // subtle flicker on the pressed button
    bl      _pulse
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// -------------------------------------------------------- shouldTerminate ---
// IMP for -[CalcController applicationShouldTerminateAfterLastWindowClosed:]

.p2align 2
_shouldTerminate:
    mov     w0, #1                        // YES
    ret

// ===================================================================== data

.section __TEXT,__cstring,cstring_literals
L_s_ctrlname:    .asciz "CalcController"
L_s_type_action: .asciz "v@:@"
L_s_type_bool:   .asciz "c@:@"
L_s_title:       .asciz "Calculator (pure asm)"
L_s_zero:        .asciz "0"
L_s_quit:        .asciz "Quit Calculator"
L_s_q:           .asciz "q"
L_s_opacity:     .asciz "opacity"
L_s_pulsekey:    .asciz "calcPulse"
L_s_scale:       .asciz "transform.scale"
L_s_fireopacity: .asciz "fireworkOpacity"
L_s_firescale:   .asciz "fireworkScale"
L_fmt_g:         .asciz "%.10g"

// selector names — order must match the S_* indices above
Ln_sharedApplication:          .asciz "sharedApplication"
Ln_setActivationPolicy:        .asciz "setActivationPolicy:"
Ln_alloc:                      .asciz "alloc"
Ln_init:                       .asciz "init"
Ln_initWithContentRect:        .asciz "initWithContentRect:styleMask:backing:defer:"
Ln_center:                     .asciz "center"
Ln_setTitle:                   .asciz "setTitle:"
Ln_contentView:                .asciz "contentView"
Ln_addSubview:                 .asciz "addSubview:"
Ln_makeKeyAndOrderFront:       .asciz "makeKeyAndOrderFront:"
Ln_activateIgnoringOtherApps:  .asciz "activateIgnoringOtherApps:"
Ln_run:                        .asciz "run"
Ln_stringWithUTF8String:       .asciz "stringWithUTF8String:"
Ln_labelWithString:            .asciz "labelWithString:"
Ln_setFrame:                   .asciz "setFrame:"
Ln_setFont:                    .asciz "setFont:"
Ln_monoFont:                   .asciz "monospacedDigitSystemFontOfSize:weight:"
Ln_setAlignment:               .asciz "setAlignment:"
Ln_buttonWithTitle:            .asciz "buttonWithTitle:target:action:"
Ln_setTag:                     .asciz "setTag:"
Ln_tag:                        .asciz "tag"
Ln_setStringValue:             .asciz "setStringValue:"
Ln_setWantsLayer:              .asciz "setWantsLayer:"
Ln_layer:                      .asciz "layer"
Ln_animationWithKeyPath:       .asciz "animationWithKeyPath:"
Ln_setFromValue:               .asciz "setFromValue:"
Ln_setToValue:                 .asciz "setToValue:"
Ln_setDuration:                .asciz "setDuration:"
Ln_setAutoreverses:            .asciz "setAutoreverses:"
Ln_setRepeatCount:             .asciz "setRepeatCount:"
Ln_addAnimationForKey:         .asciz "addAnimation:forKey:"
Ln_numberWithDouble:           .asciz "numberWithDouble:"
Ln_addItem:                    .asciz "addItem:"
Ln_setMainMenu:                .asciz "setMainMenu:"
Ln_initWithTitleActionKey:     .asciz "initWithTitle:action:keyEquivalent:"
Ln_setSubmenu:                 .asciz "setSubmenu:"
Ln_terminate:                  .asciz "terminate:"
Ln_buttonClicked:              .asciz "buttonClicked:"
Ln_setDelegate:                .asciz "setDelegate:"
Ln_shouldTerminate:            .asciz "applicationShouldTerminateAfterLastWindowClosed:"
Ln_systemFontOfSize:           .asciz "systemFontOfSize:"
Ln_setOpacity:                 .asciz "setOpacity:"

// class names — order must match the C_* indices above
Lc_NSApplication:    .asciz "NSApplication"
Lc_NSWindow:         .asciz "NSWindow"
Lc_NSString:         .asciz "NSString"
Lc_NSTextField:      .asciz "NSTextField"
Lc_NSButton:         .asciz "NSButton"
Lc_NSFont:           .asciz "NSFont"
Lc_CABasicAnimation: .asciz "CABasicAnimation"
Lc_NSNumber:         .asciz "NSNumber"
Lc_NSMenu:           .asciz "NSMenu"
Lc_NSMenuItem:       .asciz "NSMenuItem"
Lc_NSObject:         .asciz "NSObject"

// button titles
L_t_0:   .asciz "0"
L_t_1:   .asciz "1"
L_t_2:   .asciz "2"
L_t_3:   .asciz "3"
L_t_4:   .asciz "4"
L_t_5:   .asciz "5"
L_t_6:   .asciz "6"
L_t_7:   .asciz "7"
L_t_8:   .asciz "8"
L_t_9:   .asciz "9"
L_t_dot: .asciz "."
L_t_eq:  .asciz "="
L_t_add: .asciz "+"
L_t_sub: .asciz "\xe2\x88\x92"            // − U+2212 minus sign
L_t_mul: .asciz "\xc3\x97"                // × U+00D7
L_t_div: .asciz "\xc3\xb7"                // ÷ U+00F7
L_t_clr: .asciz "C"
L_t_neg: .asciz "\xc2\xb1"                // ± U+00B1
L_t_pct: .asciz "%"
L_t_spark_a: .asciz "\xe2\x9c\xa6"        // ✦ U+2726
L_t_spark_b: .asciz "\xe2\x9c\xa7"        // ✧ U+2727

.section __TEXT,__const
.p2align 3
L_c_winsize:  .double 260.0, 342.0        // content width, height
L_c_disprect: .double 10.0, 272.0, 240.0, 60.0
L_c_fontsize: .double 30.0
L_c_pulsedur: .double 0.09
L_c_sparkfontsize: .double 24.0
L_c_fireworkdur:   .double 0.32
L_c_sparkfrom:     .double 0.15
L_c_sparkto:       .double 1.75
L_c_hundred:  .double 100.0

.section __DATA,__data
.p2align 3
_sel_names:
    .quad Ln_sharedApplication
    .quad Ln_setActivationPolicy
    .quad Ln_alloc
    .quad Ln_init
    .quad Ln_initWithContentRect
    .quad Ln_center
    .quad Ln_setTitle
    .quad Ln_contentView
    .quad Ln_addSubview
    .quad Ln_makeKeyAndOrderFront
    .quad Ln_activateIgnoringOtherApps
    .quad Ln_run
    .quad Ln_stringWithUTF8String
    .quad Ln_labelWithString
    .quad Ln_setFrame
    .quad Ln_setFont
    .quad Ln_monoFont
    .quad Ln_setAlignment
    .quad Ln_buttonWithTitle
    .quad Ln_setTag
    .quad Ln_tag
    .quad Ln_setStringValue
    .quad Ln_setWantsLayer
    .quad Ln_layer
    .quad Ln_animationWithKeyPath
    .quad Ln_setFromValue
    .quad Ln_setToValue
    .quad Ln_setDuration
    .quad Ln_setAutoreverses
    .quad Ln_setRepeatCount
    .quad Ln_addAnimationForKey
    .quad Ln_numberWithDouble
    .quad Ln_addItem
    .quad Ln_setMainMenu
    .quad Ln_initWithTitleActionKey
    .quad Ln_setSubmenu
    .quad Ln_terminate
    .quad Ln_buttonClicked
    .quad Ln_setDelegate
    .quad Ln_shouldTerminate
    .quad Ln_systemFontOfSize
    .quad Ln_setOpacity
    .quad 0

_class_names:
    .quad Lc_NSApplication
    .quad Lc_NSWindow
    .quad Lc_NSString
    .quad Lc_NSTextField
    .quad Lc_NSButton
    .quad Lc_NSFont
    .quad Lc_CABasicAnimation
    .quad Lc_NSNumber
    .quad Lc_NSMenu
    .quad Lc_NSMenuItem
    .quad Lc_NSObject
    .quad 0

// button table: .quad title, .byte tag, col, row, width-in-cells, 4 pad bytes
// rows count from the bottom (Cocoa coordinates)
_buttons:
    .quad L_t_clr
    .byte 16, 0, 4, 1
    .space 4
    .quad L_t_neg
    .byte 17, 1, 4, 1
    .space 4
    .quad L_t_pct
    .byte 18, 2, 4, 1
    .space 4
    .quad L_t_div
    .byte 15, 3, 4, 1
    .space 4
    .quad L_t_7
    .byte 7, 0, 3, 1
    .space 4
    .quad L_t_8
    .byte 8, 1, 3, 1
    .space 4
    .quad L_t_9
    .byte 9, 2, 3, 1
    .space 4
    .quad L_t_mul
    .byte 14, 3, 3, 1
    .space 4
    .quad L_t_4
    .byte 4, 0, 2, 1
    .space 4
    .quad L_t_5
    .byte 5, 1, 2, 1
    .space 4
    .quad L_t_6
    .byte 6, 2, 2, 1
    .space 4
    .quad L_t_sub
    .byte 13, 3, 2, 1
    .space 4
    .quad L_t_1
    .byte 1, 0, 1, 1
    .space 4
    .quad L_t_2
    .byte 2, 1, 1, 1
    .space 4
    .quad L_t_3
    .byte 3, 2, 1, 1
    .space 4
    .quad L_t_add
    .byte 12, 3, 1, 1
    .space 4
    .quad L_t_0
    .byte 0, 0, 0, 2
    .space 4
    .quad L_t_dot
    .byte 10, 2, 0, 1
    .space 4
    .quad L_t_eq
    .byte 11, 3, 0, 1
    .space 4
    .quad 0

// firework glyph plus NSRect (x, y, width, height), 40 bytes per entry
_spark_defs:
    .quad L_t_spark_a
    .double 14.0, 286.0, 40.0, 40.0
    .quad L_t_spark_b
    .double 60.0, 298.0, 40.0, 40.0
    .quad L_t_spark_a
    .double 106.0, 284.0, 48.0, 48.0
    .quad L_t_spark_b
    .double 158.0, 298.0, 40.0, 40.0
    .quad L_t_spark_a
    .double 204.0, 286.0, 40.0, 40.0
    .quad 0

// mutable state
_entryBuf:   .asciz "0"
	.space 30
.p2align 3
_entryLen:   .quad 1
_acc:        .double 0.0
_pending:    .quad 0                      // 0 = none, else operator tag 12..15
_startNew:   .quad 0                      // next digit starts a fresh entry
_display:    .quad 0                      // NSTextField *
_controller: .quad 0                      // CalcController *
_sparkles:   .space 6 * 8                 // five NSTextFields + NULL terminator

_sels:       .space 42 * 8                // cached SELs
_classes:    .space 11 * 8                // cached Classes

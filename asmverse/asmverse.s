// =============================================================================
// ASMVERSE — a procedural universe for macOS, written in pure ARM64 assembly.
//
// The executable contains no C, Objective-C, Swift, shaders, images, or other
// visual assets. It talks to AppKit through the Objective-C runtime, owns a
// native RGBA pixel buffer, and synthesizes every frame with integer math.
// =============================================================================

.equ WIDTH,      640
.equ HEIGHT,     400
.equ ROW_BYTES, 2560

// ---------------------------------------------------------------- macros ----

.macro GADDR reg, sym
    adrp    \reg, \sym@PAGE
    add     \reg, \reg, \sym@PAGEOFF
.endm

.macro GLOAD reg, sym
    adrp    \reg, \sym@PAGE
    ldr     \reg, [\reg, \sym@PAGEOFF]
.endm

.macro GSTORE valreg, sym, scratch
    adrp    \scratch, \sym@PAGE
    str     \valreg, [\scratch, \sym@PAGEOFF]
.endm

.macro SEL reg, idx
    GADDR   \reg, _sels
    ldr     \reg, [\reg, #(\idx * 8)]
.endm

.macro CLS reg, idx
    GADDR   \reg, _classes
    ldr     \reg, [\reg, #(\idx * 8)]
.endm

.macro CLAMP255 reg, tmp
    mov     \tmp, #255
    cmp     \reg, \tmp
    csel    \reg, \reg, \tmp, ls
.endm

.macro FLOOR0 reg
    cmp     \reg, #0
    csel    \reg, \reg, wzr, gt
.endm

// ------------------------------------------------------- selector indices ---

.equ S_sharedApplication,           0
.equ S_setActivationPolicy,         1
.equ S_alloc,                       2
.equ S_init,                        3
.equ S_initWithContentRect,         4
.equ S_center,                      5
.equ S_setTitle,                    6
.equ S_contentView,                 7
.equ S_addSubview,                  8
.equ S_makeKeyAndOrderFront,        9
.equ S_activateIgnoringOtherApps,  10
.equ S_run,                        11
.equ S_stringWithUTF8String,       12
.equ S_imageViewWithImage,         13
.equ S_setFrame,                   14
.equ S_setImageScaling,            15
.equ S_setWantsLayer,              16
.equ S_setNeedsDisplay,            17
.equ S_initBitmap,                 18
.equ S_bitmapData,                 19
.equ S_initWithSize,               20
.equ S_addRepresentation,          21
.equ S_scheduledTimer,             22
.equ S_tick,                       23
.equ S_setDelegate,                24
.equ S_shouldTerminate,            25
.equ S_labelWithString,            26
.equ S_setFont,                    27
.equ S_monoFont,                   28
.equ S_setTextColor,               29
.equ S_whiteColor,                 30
.equ S_setAlignment,               31
.equ S_setAlphaValue,              32
.equ S_addItem,                    33
.equ S_setMainMenu,                34
.equ S_initWithTitleActionKey,     35
.equ S_setSubmenu,                 36
.equ S_terminate,                  37
.equ S_recache,                    38

// ----------------------------------------------------------- class indices --

.equ C_NSApplication,       0
.equ C_NSWindow,            1
.equ C_NSString,            2
.equ C_NSBitmapImageRep,    3
.equ C_NSImage,             4
.equ C_NSImageView,         5
.equ C_NSTimer,             6
.equ C_NSObject,            7
.equ C_NSTextField,         8
.equ C_NSFont,              9
.equ C_NSColor,            10
.equ C_NSMenu,             11
.equ C_NSMenuItem,         12

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

    CLS     x0, C_NSApplication
    SEL     x1, S_sharedApplication
    bl      _objc_msgSend
    mov     x19, x0                       // NSApp

    mov     x0, x19
    SEL     x1, S_setActivationPolicy
    mov     x2, #0                        // regular application
    bl      _objc_msgSend

    // Build the application controller class at runtime.
    CLS     x0, C_NSObject
    GADDR   x1, L_s_ctrlname
    mov     x2, #0
    bl      _objc_allocateClassPair
    mov     x20, x0

    mov     x0, x20
    SEL     x1, S_tick
    GADDR   x2, _tick
    GADDR   x3, L_s_type_action
    bl      _class_addMethod

    mov     x0, x20
    SEL     x1, S_shouldTerminate
    GADDR   x2, _shouldTerminate
    GADDR   x3, L_s_type_bool
    bl      _class_addMethod

    mov     x0, x20
    bl      _objc_registerClassPair

    mov     x0, x20
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_init
    bl      _objc_msgSend
    mov     x22, x0
    GSTORE  x22, _controller, x9

    mov     x0, x19
    SEL     x1, S_setDelegate
    mov     x2, x22
    bl      _objc_msgSend

    // Minimal main menu with a functioning Cmd+Q.
    CLS     x0, C_NSMenu
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_init
    bl      _objc_msgSend
    mov     x25, x0                       // menu bar

    CLS     x0, C_NSMenuItem
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_init
    bl      _objc_msgSend
    mov     x26, x0                       // root menu item

    mov     x0, x25
    SEL     x1, S_addItem
    mov     x2, x26
    bl      _objc_msgSend

    mov     x0, x19
    SEL     x1, S_setMainMenu
    mov     x2, x25
    bl      _objc_msgSend

    CLS     x0, C_NSMenu
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_init
    bl      _objc_msgSend
    mov     x27, x0                       // application menu

    GADDR   x0, L_s_quit
    bl      _mkstr
    mov     x23, x0
    GADDR   x0, L_s_q
    bl      _mkstr
    mov     x24, x0

    CLS     x0, C_NSMenuItem
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initWithTitleActionKey
    mov     x2, x23
    SEL     x3, S_terminate
    mov     x4, x24
    bl      _objc_msgSend
    mov     x28, x0

    mov     x0, x27
    SEL     x1, S_addItem
    mov     x2, x28
    bl      _objc_msgSend

    mov     x0, x26
    SEL     x1, S_setSubmenu
    mov     x2, x27
    bl      _objc_msgSend

    // Window and content view.
    CLS     x0, C_NSWindow
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initWithContentRect
    fmov    d0, xzr
    fmov    d1, xzr
    GADDR   x9, L_c_size
    ldp     d2, d3, [x9]
    mov     x2, #7                        // titled, closable, miniaturizable
    mov     x3, #2                        // buffered
    mov     x4, #0
    bl      _objc_msgSend
    mov     x21, x0

    mov     x0, x21
    SEL     x1, S_center
    bl      _objc_msgSend

    GADDR   x0, L_s_title
    bl      _mkstr
    mov     x2, x0
    mov     x0, x21
    SEL     x1, S_setTitle
    bl      _objc_msgSend

    mov     x0, x21
    SEL     x1, S_contentView
    bl      _objc_msgSend
    mov     x24, x0                       // content view

    // NSBitmapImageRep owns the mutable RGBA framebuffer.
    GADDR   x0, L_s_deviceRGB
    bl      _mkstr
    mov     x28, x0

    CLS     x0, C_NSBitmapImageRep
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initBitmap
    mov     x2, #0                        // let AppKit allocate planes
    mov     x3, #WIDTH
    mov     x4, #HEIGHT
    mov     x5, #8                        // bits per sample
    mov     x6, #4                        // RGBA
    mov     x7, #1                        // alpha
    sub     sp, sp, #32
    str     xzr, [sp]                     // non-planar
    str     x28, [sp, #8]                 // device RGB
    mov     x9, #ROW_BYTES
    str     x9, [sp, #16]
    mov     x9, #32
    str     x9, [sp, #24]
    bl      _objc_msgSend
    add     sp, sp, #32
    mov     x23, x0
    GSTORE  x23, _bitmap, x9

    mov     x0, x23
    SEL     x1, S_bitmapData
    bl      _objc_msgSend
    GSTORE  x0, _pixels, x9

    // Wrap the bitmap in an NSImage and present it in an NSImageView.
    CLS     x0, C_NSImage
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initWithSize
    GADDR   x9, L_c_size
    ldp     d0, d1, [x9]
    bl      _objc_msgSend
    mov     x25, x0
    GSTORE  x25, _image, x9

    mov     x0, x25
    SEL     x1, S_addRepresentation
    mov     x2, x23
    bl      _objc_msgSend

    CLS     x0, C_NSImageView
    SEL     x1, S_imageViewWithImage
    mov     x2, x25
    bl      _objc_msgSend
    mov     x26, x0
    GSTORE  x26, _imageView, x9

    mov     x0, x26
    SEL     x1, S_setFrame
    GADDR   x9, L_c_frame
    ldp     d0, d1, [x9]
    ldp     d2, d3, [x9, #16]
    bl      _objc_msgSend

    mov     x0, x26
    SEL     x1, S_setImageScaling
    mov     x2, #1                        // fill axes; native size is exact
    bl      _objc_msgSend

    mov     x0, x26
    SEL     x1, S_setWantsLayer
    mov     x2, #1
    bl      _objc_msgSend

    mov     x0, x24
    SEL     x1, S_addSubview
    mov     x2, x26
    bl      _objc_msgSend

    // Heads-up display: ordinary AppKit presentation, still driven from asm.
    GADDR   x0, L_s_hud
    bl      _mkstr
    mov     x2, x0
    CLS     x0, C_NSTextField
    SEL     x1, S_labelWithString
    bl      _objc_msgSend
    mov     x27, x0

    mov     x0, x27
    SEL     x1, S_setFrame
    GADDR   x9, L_c_hudframe
    ldp     d0, d1, [x9]
    ldp     d2, d3, [x9, #16]
    bl      _objc_msgSend

    CLS     x0, C_NSFont
    SEL     x1, S_monoFont
    GADDR   x9, L_c_hudfont
    ldr     d0, [x9]
    fmov    d1, xzr
    bl      _objc_msgSend
    mov     x2, x0
    mov     x0, x27
    SEL     x1, S_setFont
    bl      _objc_msgSend

    CLS     x0, C_NSColor
    SEL     x1, S_whiteColor
    bl      _objc_msgSend
    mov     x2, x0
    mov     x0, x27
    SEL     x1, S_setTextColor
    bl      _objc_msgSend

    mov     x0, x27
    SEL     x1, S_setAlphaValue
    GADDR   x9, L_c_hudalpha
    ldr     d0, [x9]
    bl      _objc_msgSend

    mov     x0, x24
    SEL     x1, S_addSubview
    mov     x2, x27
    bl      _objc_msgSend

    // Draw frame zero before exposing the window.
    bl      _render

    mov     x0, x21
    SEL     x1, S_makeKeyAndOrderFront
    mov     x2, #0
    bl      _objc_msgSend

    mov     x0, x19
    SEL     x1, S_activateIgnoringOtherApps
    mov     x2, #1
    bl      _objc_msgSend

    // A run-loop timer drives the integer renderer at 30 frames per second.
    CLS     x0, C_NSTimer
    SEL     x1, S_scheduledTimer
    GADDR   x9, L_c_frameInterval
    ldr     d0, [x9]
    mov     x2, x22
    SEL     x3, S_tick
    mov     x4, #0
    mov     x5, #1
    bl      _objc_msgSend

    mov     x0, x19
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

// -------------------------------------------------------------------- tick --
// IMP for -[ASMVerseController tick:].

.p2align 2
_tick:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    GADDR   x9, _frame
    ldr     x10, [x9]
    add     x10, x10, #1
    str     x10, [x9]

    bl      _render

    GLOAD   x0, _image
    SEL     x1, S_recache
    bl      _objc_msgSend

    GLOAD   x0, _imageView
    SEL     x1, S_setNeedsDisplay
    mov     x2, #1
    bl      _objc_msgSend

    ldp     x29, x30, [sp], #16
    ret

// ------------------------------------------------------------------ render --
// Integer-only procedural renderer. The scene combines:
//   - a rotating complex-quadratic nebula field
//   - deterministic xorshift stars with frame-driven scintillation
//   - a tilted accretion disc with animated hot bands
//   - a violet photon ring and an absolute-black event horizon
//
// Pixels are written as little-endian RGBA (packed as 0xAABBGGRR).

.p2align 2
_render:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]

    GLOAD   x19, _pixels
    GLOAD   x20, _frame
    mov     w21, #0                       // y

Lrow:
    sub     w22, w21, #200                // dy
    mul     w23, w22, w22                 // dy squared
    mov     w24, #0                       // x

Lpixel:
    sub     w25, w24, #320                // dx
    mul     w26, w25, w25                 // dx squared
    add     w27, w26, w23                 // radial distance squared

    // Complex-quadratic interference field: cheap, smooth-looking nebulae.
    mul     w8, w25, w22
    asr     w8, w8, #3
    add     w8, w8, w27, lsr #5
    sub     w8, w8, w20, lsl #2
    and     w8, w8, #255
    sub     w8, w8, #128
    cmp     w8, #0
    cneg    w8, w8, lt
    mov     w9, #74
    subs    w9, w9, w8                    // nebula density
    csel    w9, w9, wzr, gt

    lsr     w10, w9, #2                   // red
    add     w10, w10, #2
    lsr     w11, w9, #3                   // green
    add     w11, w11, #3
    add     w12, w9, #10                  // blue

    // Stable star positions from a two-dimensional xorshift hash.
    mov     w14, #1973
    madd    w28, w24, w14, wzr
    mov     w14, #9277
    madd    w28, w21, w14, w28
    movz    w14, #0x21eb
    movk    w14, #0x68bc, lsl #16
    add     w28, w28, w14
    eor     w28, w28, w28, lsl #13
    eor     w28, w28, w28, lsr #17
    eor     w28, w28, w28, lsl #5

    and     w8, w28, #0x3fff
    cmp     w8, #5
    b.hi    Ldisk
    eor     w8, w28, w20, lsl #11
    lsr     w8, w8, #16
    and     w8, w8, #63
    add     w8, w8, #190
    mov     w10, w8
    sub     w11, w8, #20
    add     w12, w8, #2

Ldisk:
    // A tilted elliptical ring becomes the black hole's accretion disc.
    add     w8, w22, w25, asr #3
    mul     w8, w8, w8
    lsl     w8, w8, #6
    add     w8, w8, w26
    mov     w13, #22500
    sub     w8, w8, w13
    cmp     w8, #0
    cneg    w8, w8, lt
    mov     w14, #7000
    subs    w14, w14, w8
    b.le    Lphoton
    lsr     w14, w14, #4
    CLAMP255 w14, w15

    // Hot material races around the ring as the frame counter advances.
    lsr     w15, w28, #8
    add     w15, w15, w20, lsl #2
    and     w15, w15, #31
    sub     w14, w14, w15
    FLOOR0  w14

    add     w10, w10, w14
    CLAMP255 w10, w15
    add     w11, w11, w14, lsr #1
    CLAMP255 w11, w15
    add     w12, w12, w14, lsr #4
    CLAMP255 w12, w15

Lphoton:
    // Violet photon ring immediately outside the event horizon.
    mov     w8, #1500
    sub     w8, w27, w8
    cmp     w8, #0
    cneg    w8, w8, lt
    mov     w13, #520
    subs    w13, w13, w8
    b.le    Lvignette
    lsr     w13, w13, #1
    add     w10, w10, w13
    CLAMP255 w10, w14
    add     w11, w11, w13, lsr #2
    CLAMP255 w11, w14
    add     w12, w12, w13
    CLAMP255 w12, w14

Lvignette:
    // Edge falloff gives the scene depth and makes the core feel luminous.
    lsr     w8, w27, #13
    subs    w10, w10, w8
    FLOOR0  w10
    subs    w11, w11, w8
    FLOOR0  w11
    subs    w12, w12, w8
    FLOOR0  w12

    // Nothing survives inside the event horizon.
    cmp     w27, #1100
    b.hs    Lpack
    mov     w10, #0
    mov     w11, #0
    mov     w12, #1

Lpack:
    orr     w13, w10, w11, lsl #8
    orr     w13, w13, w12, lsl #16
    movz    w14, #0xff00, lsl #16
    orr     w13, w13, w14
    str     w13, [x19], #4

    add     w24, w24, #1
    cmp     w24, #WIDTH
    b.lt    Lpixel
    add     w21, w21, #1
    cmp     w21, #HEIGHT
    b.lt    Lrow

    ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// -------------------------------------------------------- shouldTerminate ---

.p2align 2
_shouldTerminate:
    mov     w0, #1
    ret

// ===================================================================== data

.section __TEXT,__cstring,cstring_literals
L_s_ctrlname:       .asciz "ASMVerseController"
L_s_type_action:    .asciz "v@:@"
L_s_type_bool:      .asciz "c@:@"
L_s_title:          .asciz "ASMVERSE — pure ARM64 procedural universe"
L_s_hud:            .asciz "ASMVERSE  //  PURE ARM64  //  ZERO VISUAL ASSETS"
L_s_quit:           .asciz "Quit ASMVERSE"
L_s_q:              .asciz "q"
L_s_deviceRGB:      .asciz "NSDeviceRGBColorSpace"

Ln_sharedApplication:        .asciz "sharedApplication"
Ln_setActivationPolicy:      .asciz "setActivationPolicy:"
Ln_alloc:                    .asciz "alloc"
Ln_init:                     .asciz "init"
Ln_initWithContentRect:      .asciz "initWithContentRect:styleMask:backing:defer:"
Ln_center:                   .asciz "center"
Ln_setTitle:                 .asciz "setTitle:"
Ln_contentView:              .asciz "contentView"
Ln_addSubview:               .asciz "addSubview:"
Ln_makeKeyAndOrderFront:     .asciz "makeKeyAndOrderFront:"
Ln_activateIgnoringOtherApps:.asciz "activateIgnoringOtherApps:"
Ln_run:                      .asciz "run"
Ln_stringWithUTF8String:     .asciz "stringWithUTF8String:"
Ln_imageViewWithImage:       .asciz "imageViewWithImage:"
Ln_setFrame:                 .asciz "setFrame:"
Ln_setImageScaling:          .asciz "setImageScaling:"
Ln_setWantsLayer:            .asciz "setWantsLayer:"
Ln_setNeedsDisplay:          .asciz "setNeedsDisplay:"
Ln_initBitmap:               .asciz "initWithBitmapDataPlanes:pixelsWide:pixelsHigh:bitsPerSample:samplesPerPixel:hasAlpha:isPlanar:colorSpaceName:bytesPerRow:bitsPerPixel:"
Ln_bitmapData:               .asciz "bitmapData"
Ln_initWithSize:             .asciz "initWithSize:"
Ln_addRepresentation:       .asciz "addRepresentation:"
Ln_scheduledTimer:           .asciz "scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:"
Ln_tick:                     .asciz "tick:"
Ln_setDelegate:              .asciz "setDelegate:"
Ln_shouldTerminate:          .asciz "applicationShouldTerminateAfterLastWindowClosed:"
Ln_labelWithString:          .asciz "labelWithString:"
Ln_setFont:                  .asciz "setFont:"
Ln_monoFont:                 .asciz "monospacedSystemFontOfSize:weight:"
Ln_setTextColor:             .asciz "setTextColor:"
Ln_whiteColor:               .asciz "whiteColor"
Ln_setAlignment:             .asciz "setAlignment:"
Ln_setAlphaValue:            .asciz "setAlphaValue:"
Ln_addItem:                  .asciz "addItem:"
Ln_setMainMenu:              .asciz "setMainMenu:"
Ln_initWithTitleActionKey:   .asciz "initWithTitle:action:keyEquivalent:"
Ln_setSubmenu:               .asciz "setSubmenu:"
Ln_terminate:                .asciz "terminate:"
Ln_recache:                  .asciz "recache"

Lc_NSApplication:    .asciz "NSApplication"
Lc_NSWindow:         .asciz "NSWindow"
Lc_NSString:         .asciz "NSString"
Lc_NSBitmapImageRep: .asciz "NSBitmapImageRep"
Lc_NSImage:          .asciz "NSImage"
Lc_NSImageView:      .asciz "NSImageView"
Lc_NSTimer:          .asciz "NSTimer"
Lc_NSObject:         .asciz "NSObject"
Lc_NSTextField:      .asciz "NSTextField"
Lc_NSFont:           .asciz "NSFont"
Lc_NSColor:          .asciz "NSColor"
Lc_NSMenu:           .asciz "NSMenu"
Lc_NSMenuItem:       .asciz "NSMenuItem"

.section __TEXT,__const
.p2align 3
L_c_size:          .double 640.0, 400.0
L_c_frame:         .double 0.0, 0.0, 640.0, 400.0
L_c_hudframe:      .double 14.0, 370.0, 500.0, 20.0
L_c_hudfont:       .double 12.0
L_c_hudalpha:      .double 0.78
L_c_frameInterval: .double 0.03333333333333333

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
    .quad Ln_imageViewWithImage
    .quad Ln_setFrame
    .quad Ln_setImageScaling
    .quad Ln_setWantsLayer
    .quad Ln_setNeedsDisplay
    .quad Ln_initBitmap
    .quad Ln_bitmapData
    .quad Ln_initWithSize
    .quad Ln_addRepresentation
    .quad Ln_scheduledTimer
    .quad Ln_tick
    .quad Ln_setDelegate
    .quad Ln_shouldTerminate
    .quad Ln_labelWithString
    .quad Ln_setFont
    .quad Ln_monoFont
    .quad Ln_setTextColor
    .quad Ln_whiteColor
    .quad Ln_setAlignment
    .quad Ln_setAlphaValue
    .quad Ln_addItem
    .quad Ln_setMainMenu
    .quad Ln_initWithTitleActionKey
    .quad Ln_setSubmenu
    .quad Ln_terminate
    .quad Ln_recache
    .quad 0

_class_names:
    .quad Lc_NSApplication
    .quad Lc_NSWindow
    .quad Lc_NSString
    .quad Lc_NSBitmapImageRep
    .quad Lc_NSImage
    .quad Lc_NSImageView
    .quad Lc_NSTimer
    .quad Lc_NSObject
    .quad Lc_NSTextField
    .quad Lc_NSFont
    .quad Lc_NSColor
    .quad Lc_NSMenu
    .quad Lc_NSMenuItem
    .quad 0

_pixels:     .quad 0
_bitmap:     .quad 0
_image:      .quad 0
_imageView:  .quad 0
_controller: .quad 0
_frame:      .quad 0

_sels:       .space 39 * 8
_classes:    .space 13 * 8

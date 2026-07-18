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
.equ S_setImage,                   39
.equ S_release,                    40
.equ S_setStringValue,             41
.equ S_setCacheMode,               42
.equ S_initWithFramePullsDown,      43
.equ S_addItemWithTitle,            44
.equ S_selectItemAtIndex,           45
.equ S_indexOfSelectedItem,         46
.equ S_setTarget,                   47
.equ S_setAction,                   48
.equ S_resolutionChanged,           49
.equ S_cycleResolution,             50
.equ S_mainScreen,                  51
.equ S_maximumFramesPerSecond,      52
.equ S_display,                     53
.equ S_setAutoresizingMask,         54
.equ S_setContentSize,              55
.equ S_makeFirstResponder,          56
.equ S_keyDown,                     57
.equ S_keyCode,                     58
.equ S_acceptsFirstResponder,       59

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
.equ C_NSPopUpButton,      13
.equ C_NSScreen,           14
.equ C_NSResponder,        15

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
    CLS     x0, C_NSResponder
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
    SEL     x1, S_resolutionChanged
    GADDR   x2, _resolutionChanged
    GADDR   x3, L_s_type_action
    bl      _class_addMethod

    mov     x0, x20
    SEL     x1, S_cycleResolution
    GADDR   x2, _cycleResolution
    GADDR   x3, L_s_type_action
    bl      _class_addMethod

    mov     x0, x20
    SEL     x1, S_keyDown
    GADDR   x2, _keyDown
    GADDR   x3, L_s_type_action
    bl      _class_addMethod

    mov     x0, x20
    SEL     x1, S_acceptsFirstResponder
    GADDR   x2, _acceptsFirstResponder
    GADDR   x3, L_s_type_bool_noarg
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

    GADDR   x0, L_s_cycleResolution
    bl      _mkstr
    mov     x23, x0
    GADDR   x0, L_s_r
    bl      _mkstr
    mov     x24, x0

    CLS     x0, C_NSMenuItem
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initWithTitleActionKey
    mov     x2, x23
    SEL     x3, S_cycleResolution
    mov     x4, x24
    bl      _objc_msgSend
    mov     x28, x0

    mov     x0, x28
    SEL     x1, S_setTarget
    mov     x2, x22
    bl      _objc_msgSend

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
    GSTORE  x21, _window, x9

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
    GSTORE  x0, _deviceRGB, x9

    bl      _createBitmap
    mov     x23, x0

    // Wrap the bitmap in an NSImage and present it in an NSImageView.
    CLS     x0, C_NSImage
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initWithSize
    GADDR   x9, L_c_size
    ldp     d0, d1, [x9]
    bl      _objc_msgSend
    mov     x25, x0

    mov     x0, x25
    SEL     x1, S_setCacheMode
    mov     x2, #3                        // NSImageCacheNever
    bl      _objc_msgSend

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

    mov     x0, x25                       // image view retained the image
    SEL     x1, S_release
    bl      _objc_msgSend

    mov     x0, x23                       // image retained the representation
    SEL     x1, S_release
    bl      _objc_msgSend

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

    mov     x0, x26
    SEL     x1, S_setAutoresizingMask
    mov     x2, #18                       // width + height sizable
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
    GSTORE  x27, _hud, x9

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

    mov     x0, x27
    SEL     x1, S_setAutoresizingMask
    mov     x2, #10                       // width sizable, pinned to top
    bl      _objc_msgSend

    mov     x0, x24
    SEL     x1, S_addSubview
    mov     x2, x27
    bl      _objc_msgSend

    // Resolution selector. Cmd+R invokes the same state transition.
    CLS     x0, C_NSPopUpButton
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initWithFramePullsDown
    GADDR   x9, L_c_popupframe
    ldp     d0, d1, [x9]
    ldp     d2, d3, [x9, #16]
    mov     x2, #0
    bl      _objc_msgSend
    mov     x28, x0
    GSTORE  x28, _popup, x9

    GADDR   x0, L_s_resLow
    bl      _mkstr
    mov     x2, x0
    mov     x0, x28
    SEL     x1, S_addItemWithTitle
    bl      _objc_msgSend

    GADDR   x0, L_s_resMedium
    bl      _mkstr
    mov     x2, x0
    mov     x0, x28
    SEL     x1, S_addItemWithTitle
    bl      _objc_msgSend

    GADDR   x0, L_s_resHigh
    bl      _mkstr
    mov     x2, x0
    mov     x0, x28
    SEL     x1, S_addItemWithTitle
    bl      _objc_msgSend

    mov     x0, x28
    SEL     x1, S_setTarget
    mov     x2, x22
    bl      _objc_msgSend

    mov     x0, x28
    SEL     x1, S_setAction
    SEL     x2, S_resolutionChanged
    bl      _objc_msgSend

    mov     x0, x28
    SEL     x1, S_selectItemAtIndex
    mov     x2, #0                        // default: efficient 160x100
    bl      _objc_msgSend

    mov     x0, x28
    SEL     x1, S_setAutoresizingMask
    mov     x2, #9                        // pinned to top-right
    bl      _objc_msgSend

    mov     x0, x24
    SEL     x1, S_addSubview
    mov     x2, x28
    bl      _objc_msgSend

    // Draw frame zero before exposing the window.
    bl      _render

    mov     x0, x21
    SEL     x1, S_makeKeyAndOrderFront
    mov     x2, #0
    bl      _objc_msgSend

    mov     x0, x21
    SEL     x1, S_makeFirstResponder
    mov     x2, x22
    bl      _objc_msgSend

    mov     x0, x19
    SEL     x1, S_activateIgnoringOtherApps
    mov     x2, #1
    bl      _objc_msgSend

    // Pace at the active display's maximum refresh rate. Rendering thousands
    // of frames that AppKit cannot present only burns CPU and starves drawing.
    CLS     x0, C_NSScreen
    SEL     x1, S_mainScreen
    bl      _objc_msgSend
    SEL     x1, S_maximumFramesPerSecond
    bl      _objc_msgSend
    mov     x9, #120
    cmp     x0, #1
    csel    x9, x0, x9, ge
    scvtf   d1, x9
    fmov    d0, #1.0
    fdiv    d0, d0, d1

    CLS     x0, C_NSTimer
    SEL     x1, S_scheduledTimer
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
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    GADDR   x9, _frame
    ldr     x10, [x9]
    add     x10, x10, #1
    str     x10, [x9]

    bl      _objc_autoreleasePoolPush
    mov     x20, x0

    bl      _createBitmap
    mov     x19, x0
    bl      _render
    mov     x0, x19
    bl      _presentFrame
    bl      _updateStats

    mov     x0, x20
    bl      _objc_autoreleasePoolPop

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ------------------------------------------------------ applyResolutionIndex --
// x0 = 0..2. Updates the render dimensions and virtual-coordinate scale.

.p2align 2
_applyResolutionIndex:
    cmp     x0, #2
    csel    x0, x0, xzr, ls
    GSTORE  x0, _resolutionIndex, x9

    GADDR   x9, _resolutionTable
    mov     x10, #24
    madd    x9, x0, x10, x9
    ldp     x11, x12, [x9]
    ldr     x13, [x9, #16]
    GSTORE  x11, _renderWidth, x14
    GSTORE  x12, _renderHeight, x14
    GSTORE  x13, _coordScale, x14

    GSTORE  xzr, _statsFrames, x14
    GSTORE  xzr, _statsTime, x14
    ret

// --------------------------------------------------------- resolutionChanged --
// IMP for -[ASMVerseController resolutionChanged:].

.p2align 2
_resolutionChanged:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     x0, x2
    SEL     x1, S_indexOfSelectedItem
    bl      _objc_msgSend
    mov     x19, x0
    bl      _applyResolutionIndex
    mov     x0, x19
    bl      _resizeForResolution
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ------------------------------------------------------------ cycleResolution --
// IMP for Cmd+R. Cycles low -> medium -> high -> low and synchronizes the
// dropdown selection.

.p2align 2
_cycleResolution:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]

    GLOAD   x19, _resolutionIndex
    add     x19, x19, #1
    cmp     x19, #3
    csel    x19, x19, xzr, lo
    mov     x0, x19
    bl      _applyResolutionIndex
    mov     x0, x19
    bl      _resizeForResolution

    GLOAD   x0, _popup
    SEL     x1, S_selectItemAtIndex
    mov     x2, x19
    bl      _objc_msgSend

    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// -------------------------------------------------------- resizeForResolution --
// x0 = resolution index. Resize the content surface and return keyboard focus
// to the controller so arrow keys keep steering after dropdown interaction.

.p2align 2
_resizeForResolution:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    mov     x19, x0

    GADDR   x9, _windowSizeTable
    add     x9, x9, x19, lsl #4
    ldp     d0, d1, [x9]
    GLOAD   x0, _window
    SEL     x1, S_setContentSize
    bl      _objc_msgSend

    GLOAD   x0, _window
    SEL     x1, S_center
    bl      _objc_msgSend

    GLOAD   x0, _window
    SEL     x1, S_makeFirstResponder
    GLOAD   x2, _controller
    bl      _objc_msgSend

    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------- keyDown --
// Native NSResponder keyboard handling: Left/Right orbit around the black
// hole; Up/Down change the accretion-plane tilt.

.p2align 2
_keyDown:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x0, x2
    SEL     x1, S_keyCode
    bl      _objc_msgSend

    cmp     w0, #123                      // left
    b.eq    Lkey_left
    cmp     w0, #124                      // right
    b.eq    Lkey_right
    cmp     w0, #125                      // down
    b.eq    Lkey_down
    cmp     w0, #126                      // up
    b.eq    Lkey_up
    b       Lkey_done

Lkey_left:
    GADDR   x9, _cameraOrbit
    ldr     w10, [x9]
    sub     w10, w10, #4
    mov     w11, #-32
    cmp     w10, w11
    csel    w10, w10, w11, ge
    str     w10, [x9]
    b       Lkey_done

Lkey_right:
    GADDR   x9, _cameraOrbit
    ldr     w10, [x9]
    add     w10, w10, #4
    mov     w11, #32
    cmp     w10, w11
    csel    w10, w10, w11, le
    str     w10, [x9]
    b       Lkey_done

Lkey_down:
    GADDR   x9, _cameraTilt
    ldr     w10, [x9]
    sub     w10, w10, #8
    mov     w11, #32
    cmp     w10, w11
    csel    w10, w10, w11, ge
    str     w10, [x9]
    b       Lkey_done

Lkey_up:
    GADDR   x9, _cameraTilt
    ldr     w10, [x9]
    add     w10, w10, #8
    mov     w11, #128
    cmp     w10, w11
    csel    w10, w10, w11, le
    str     w10, [x9]

Lkey_done:
    ldp     x29, x30, [sp], #16
    ret

.p2align 2
_acceptsFirstResponder:
    mov     w0, #1
    ret

// -------------------------------------------------------------- createBitmap --
// Allocates a fresh bitmap representation for one rendered frame and points
// _pixels at its storage. The caller owns the returned representation.

.p2align 2
_createBitmap:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]

    CLS     x0, C_NSBitmapImageRep
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initBitmap
    mov     x2, #0                        // let AppKit allocate planes
    GLOAD   x3, _renderWidth
    GLOAD   x4, _renderHeight
    mov     x5, #8                        // bits per sample
    mov     x6, #4                        // RGBA
    mov     x7, #1                        // alpha
    sub     sp, sp, #32
    str     xzr, [sp]                     // non-planar
    GLOAD   x9, _deviceRGB
    str     x9, [sp, #8]
    lsl     x9, x3, #2
    str     x9, [sp, #16]
    mov     x9, #32
    str     x9, [sp, #24]
    bl      _objc_msgSend
    add     sp, sp, #32
    mov     x19, x0

    mov     x0, x19
    SEL     x1, S_bitmapData
    bl      _objc_msgSend
    GSTORE  x0, _pixels, x9

    mov     x0, x19
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ------------------------------------------------------------- presentFrame --
// x0 = freshly rendered NSBitmapImageRep. A fresh representation and NSImage
// cache identity on every tick prevents AppKit from presenting stale pixels.
// NSImageView retains the image; explicit releases keep memory stable.

.p2align 2
_presentFrame:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    mov     x19, x0                       // bitmap representation

    CLS     x0, C_NSImage
    SEL     x1, S_alloc
    bl      _objc_msgSend
    SEL     x1, S_initWithSize
    GADDR   x9, L_c_size
    ldp     d0, d1, [x9]
    bl      _objc_msgSend
    mov     x20, x0                       // image

    mov     x0, x20
    SEL     x1, S_setCacheMode
    mov     x2, #3                        // NSImageCacheNever
    bl      _objc_msgSend

    mov     x0, x20
    SEL     x1, S_addRepresentation
    mov     x2, x19
    bl      _objc_msgSend

    GLOAD   x0, _imageView
    SEL     x1, S_setImage
    mov     x2, x20
    bl      _objc_msgSend

    GLOAD   x0, _imageView
    SEL     x1, S_display
    bl      _objc_msgSend

    mov     x0, x20
    SEL     x1, S_release
    bl      _objc_msgSend

    mov     x0, x19
    SEL     x1, S_release
    bl      _objc_msgSend

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// -------------------------------------------------------------- readCpuUs ---
// Returns cumulative user + system CPU time in microseconds and refreshes the
// rusage buffer. Darwin reports ru_maxrss in bytes at offset 32.

.p2align 2
_readCpuUs:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x0, #0                        // RUSAGE_SELF
    GADDR   x1, _rusage
    bl      _getrusage

    GADDR   x9, _rusage
    ldr     x10, [x9]                    // user seconds
    ldr     w11, [x9, #8]                // user microseconds
    movz    x12, #0x4240
    movk    x12, #0x000f, lsl #16
    madd    x10, x10, x12, x11
    ldr     x13, [x9, #16]               // system seconds
    ldr     w14, [x9, #24]               // system microseconds
    madd    x13, x13, x12, x14
    add     x0, x10, x13

    ldp     x29, x30, [sp], #16
    ret

// ------------------------------------------------------- readResidentBytes ---
// Returns current resident memory from MACH_TASK_BASIC_INFO, rather than the
// monotonically increasing ru_maxrss high-water mark.

.p2align 2
_readResidentBytes:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    adrp    x9, _mach_task_self_@GOTPAGE
    ldr     x9, [x9, _mach_task_self_@GOTPAGEOFF]
    ldr     w0, [x9]
    mov     w1, #20                       // MACH_TASK_BASIC_INFO
    GADDR   x2, _taskInfo
    GADDR   x3, _taskInfoCount
    mov     w9, #12                       // reset in/out count each sample
    str     w9, [x3]
    bl      _task_info

    GADDR   x9, _taskInfo
    ldr     x0, [x9, #8]                 // resident_size
    ldp     x29, x30, [sp], #16
    ret

// ------------------------------------------------------------- updateStats ---
// Once per second: FPS = rendered frames / wall time; CPU = process CPU-time
// delta / wall-time delta; memory = current Mach resident size. The same line
// is shown in the HUD and printed to stdout for terminal launches.

.p2align 2
_updateStats:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]

    GADDR   x19, _statsFrames
    ldr     x20, [x19]
    add     x20, x20, #1
    str     x20, [x19]

    bl      _CACurrentMediaTime
    fmov    d4, d0                        // now
    GADDR   x21, _statsTime
    ldr     d5, [x21]
    fcmp    d5, #0.0
    b.ne    Lstats_check

    str     d4, [x21]
    str     xzr, [x19]
    bl      _readCpuUs
    GSTORE  x0, _lastCpuUs, x9
    b       Lstats_done

Lstats_check:
    fsub    d3, d4, d5                    // elapsed wall seconds
    GADDR   x9, L_c_one
    ldr     d2, [x9]
    fcmp    d3, d2
    b.lt    Lstats_done

    str     d4, [x21]
    str     d3, [sp, #48]
    scvtf   d0, x20
    fdiv    d0, d0, d3                    // measured FPS
    str     d0, [sp, #56]
    str     xzr, [x19]

    bl      _readCpuUs
    mov     x22, x0
    GADDR   x9, _lastCpuUs
    ldr     x10, [x9]
    sub     x10, x22, x10
    str     x22, [x9]

    scvtf   d1, x10
    GADDR   x9, L_c_million
    ldr     d2, [x9]
    fdiv    d1, d1, d2                    // CPU seconds
    ldr     d3, [sp, #48]
    fdiv    d1, d1, d3
    GADDR   x9, L_c_hundred
    ldr     d2, [x9]
    fmul    d1, d1, d2                    // process CPU percent
    str     d1, [sp, #64]

    bl      _readResidentBytes
    scvtf   d2, x0
    GADDR   x9, L_c_megabyte
    ldr     d3, [x9]
    fdiv    d2, d2, d3
    str     d2, [sp, #72]

    GADDR   x0, _statsBuf
    mov     x1, #160
    GADDR   x2, L_fmt_stats
    ldr     d0, [sp, #56]
    ldr     d1, [sp, #64]
    ldr     d2, [sp, #72]
    GLOAD   x11, _renderWidth
    GLOAD   x12, _renderHeight
    GLOAD   x13, _cameraOrbit
    GLOAD   x14, _cameraTilt
    sub     sp, sp, #64
    str     d0, [sp]
    str     d1, [sp, #8]
    str     d2, [sp, #16]
    str     x11, [sp, #24]
    str     x12, [sp, #32]
    str     x13, [sp, #40]
    str     x14, [sp, #48]
    bl      _snprintf
    add     sp, sp, #64

    GADDR   x0, _statsBuf
    bl      _puts

    GADDR   x0, _statsBuf
    bl      _mkstr
    mov     x2, x0
    GLOAD   x0, _hud
    SEL     x1, S_setStringValue
    bl      _objc_msgSend

Lstats_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
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
    stp     x29, x30, [sp, #-128]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]

    GLOAD   x19, _pixels
    GLOAD   x20, _frame
    GLOAD   x16, _renderWidth
    GLOAD   x17, _renderHeight
    // x18 is reserved by Darwin and may be clobbered asynchronously. Keep the
    // selected scale in a stack local instead.
    GLOAD   x8, _coordScale
    str     x8, [sp, #96]

    GLOAD   x8, _cameraOrbit
    str     w8, [sp, #112]
    GLOAD   x8, _cameraTilt
    str     w8, [sp, #116]

    // Sample an exact point on the canonical ellipse, then invert the active
    // camera shear and tilt so the beacon stays glued to the rendered ring.
    GADDR   x8, _orbitTable
    lsr     w9, w20, #2
    and     w9, w9, #63
    add     x8, x8, x9, lsl #2
    ldrsh   w9, [x8]                      // canonical x
    ldrsh   w10, [x8, #2]                 // canonical plane y
    str     w9, [sp, #104]
    str     w10, [sp, #120]               // also determines front/back
    lsl     w11, w10, #6
    ldr     w12, [sp, #116]
    sdiv    w11, w11, w12                 // undo camera tilt
    ldr     w12, [sp, #112]
    mul     w13, w9, w12
    asr     w13, w13, #6
    sub     w11, w11, w13                 // undo camera orbit shear
    str     w11, [sp, #108]
    mov     w21, #0                       // y

Lrow:
    lsr     w8, w17, #1
    sub     w22, w21, w8
    ldr     w8, [sp, #96]
    mul     w22, w22, w8                  // virtual-space dy
    mul     w23, w22, w22                 // dy squared
    mov     w24, #0                       // x

Lpixel:
    lsr     w8, w16, #1
    sub     w25, w24, w8
    ldr     w8, [sp, #96]
    mul     w25, w25, w8                  // virtual-space dx
    mul     w26, w25, w25                 // dx squared
    add     w27, w26, w23                 // radial distance squared

    // Complex-quadratic interference field: cheap, smooth-looking nebulae.
    mul     w8, w25, w22
    asr     w8, w8, #3
    add     w8, w8, w27, lsr #5
    sub     w8, w8, w20, lsr #1
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

    // Stable 2x2 flare cells from a two-dimensional xorshift hash. Grouping
    // samples makes scintillation readable even at native HIGH resolution.
    lsr     w8, w24, #1
    mov     w14, #1973
    madd    w28, w8, w14, wzr
    lsr     w8, w21, #1
    mov     w14, #9277
    madd    w28, w8, w14, w28
    movz    w14, #0x21eb
    movk    w14, #0x68bc, lsl #16
    add     w28, w28, w14
    eor     w28, w28, w28, lsl #13
    eor     w28, w28, w28, lsr #17
    eor     w28, w28, w28, lsl #5

    and     w8, w28, #0x3fff
    cmp     w8, #30
    b.hi    Ldisk
    lsr     w8, w20, #3
    add     w8, w8, w28, lsr #16
    and     w8, w8, #63
    sub     w8, w8, #32
    cmp     w8, #0
    cneg    w8, w8, lt
    lsl     w8, w8, #3                    // fade fully out, then flare white
    CLAMP255 w8, w15
    mov     w10, w8
    add     w11, w8, w8, lsr #1
    lsr     w11, w11, #1
    add     w12, w8, #24
    CLAMP255 w12, w15

Ldisk:
    // Camera-controlled shear orbits around the object; vertical scale tilts
    // its accretion plane toward or away from edge-on.
    ldr     w14, [sp, #112]
    mul     w8, w25, w14
    asr     w8, w8, #6
    add     w8, w22, w8
    ldr     w14, [sp, #116]
    mul     w8, w8, w14
    asr     w8, w8, #6
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
    add     w15, w15, w20, lsr #3
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
    b.le    Lhotspot
    lsr     w13, w13, #1
    add     w10, w10, w13
    CLAMP255 w10, w14
    add     w11, w11, w13, lsr #2
    CLAMP255 w11, w14
    add     w12, w12, w13
    CLAMP255 w12, w14

Lhotspot:
    // A bright blue-white beacon orbits along the accretion disc. Unlike the
    // slower nebula phase and hot bands, its translation is obvious at a
    // glance and remains speed-consistent on a 120 Hz display.
    ldr     w8, [sp, #104]
    sub     w8, w25, w8
    mul     w8, w8, w8
    ldr     w14, [sp, #108]
    sub     w14, w22, w14
    mul     w14, w14, w14
    add     w8, w8, w14
    cmp     w8, #160
    b.hs    Lvignette
    mov     w13, #160
    sub     w13, w13, w8
    add     w10, w10, w13
    CLAMP255 w10, w15
    add     w11, w11, w13
    CLAMP255 w11, w15
    mov     w12, #255

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
    b.hs    LfrontArc
    mov     w10, #0
    mov     w11, #0
    mov     w12, #1

LfrontArc:
    // Redraw only the near half after the event horizon. The far half remains
    // behind the planet while the near half visibly crosses its face.
    ldr     w14, [sp, #112]
    mul     w8, w25, w14
    asr     w8, w8, #6
    add     w8, w22, w8
    ldr     w14, [sp, #116]
    mul     w8, w8, w14
    asr     w8, w8, #6
    cmp     w8, #0
    b.le    LfrontBeacon
    mul     w8, w8, w8
    lsl     w8, w8, #6
    add     w8, w8, w26
    mov     w13, #22500
    sub     w8, w8, w13
    cmp     w8, #0
    cneg    w8, w8, lt
    mov     w14, #7000
    subs    w14, w14, w8
    b.le    LfrontBeacon
    lsr     w14, w14, #4
    CLAMP255 w14, w15
    add     w10, w10, w14
    CLAMP255 w10, w15
    add     w11, w11, w14, lsr #1
    CLAMP255 w11, w15
    add     w12, w12, w14, lsr #4
    CLAMP255 w12, w15

LfrontBeacon:
    // The near-side beacon must also be redrawn over the event horizon.
    ldr     w8, [sp, #120]
    cmp     w8, #0
    b.le    Lpack
    ldr     w8, [sp, #104]
    sub     w8, w25, w8
    mul     w8, w8, w8
    ldr     w14, [sp, #108]
    sub     w14, w22, w14
    mul     w14, w14, w14
    add     w8, w8, w14
    cmp     w8, #160
    b.hs    Lpack
    mov     w13, #160
    sub     w13, w13, w8
    add     w10, w10, w13
    CLAMP255 w10, w15
    add     w11, w11, w13
    CLAMP255 w11, w15
    mov     w12, #255

Lpack:
    orr     w13, w10, w11, lsl #8
    orr     w13, w13, w12, lsl #16
    movz    w14, #0xff00, lsl #16
    orr     w13, w13, w14

    // Store the logical-resolution sample. NSImageView scales the freshly
    // allocated bitmap to the fixed 640x400 presentation surface.
    uxtw    x8, w21
    uxtw    x9, w16
    lsl     x9, x9, #2                    // logical row bytes
    madd    x8, x8, x9, x19
    uxtw    x10, w24
    str     w13, [x8, x10, lsl #2]

    add     w24, w24, #1
    cmp     w24, w16
    b.lt    Lpixel
    add     w21, w21, #1
    cmp     w21, w17
    b.lt    Lrow

    ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #128
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
L_s_type_bool_noarg:.asciz "c@:"
L_s_title:          .asciz "ASMVERSE — pure ARM64 procedural universe"
L_s_hud:            .asciz "ASMVERSE  //  STARTING LIVE TELEMETRY..."
L_s_quit:           .asciz "Quit ASMVERSE"
L_s_q:              .asciz "q"
L_s_cycleResolution:.asciz "Cycle Resolution"
L_s_r:              .asciz "r"
L_s_resLow:         .asciz "160 x 100  LOW"
L_s_resMedium:      .asciz "320 x 200  MED"
L_s_resHigh:        .asciz "640 x 400  HIGH"
L_s_deviceRGB:      .asciz "NSDeviceRGBColorSpace"
L_fmt_stats:        .asciz "FPS %5.1f // CPU %4.1f%% // MEM %5.1f MB // %lux%lu // CAM %+ld/%lu"

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
Ln_setImage:                 .asciz "setImage:"
Ln_release:                  .asciz "release"
Ln_setStringValue:           .asciz "setStringValue:"
Ln_setCacheMode:             .asciz "setCacheMode:"
Ln_initWithFramePullsDown:    .asciz "initWithFrame:pullsDown:"
Ln_addItemWithTitle:          .asciz "addItemWithTitle:"
Ln_selectItemAtIndex:         .asciz "selectItemAtIndex:"
Ln_indexOfSelectedItem:       .asciz "indexOfSelectedItem"
Ln_setTarget:                 .asciz "setTarget:"
Ln_setAction:                 .asciz "setAction:"
Ln_resolutionChanged:         .asciz "resolutionChanged:"
Ln_cycleResolution:           .asciz "cycleResolution:"
Ln_mainScreen:                .asciz "mainScreen"
Ln_maximumFramesPerSecond:    .asciz "maximumFramesPerSecond"
Ln_display:                   .asciz "display"
Ln_setAutoresizingMask:       .asciz "setAutoresizingMask:"
Ln_setContentSize:            .asciz "setContentSize:"
Ln_makeFirstResponder:        .asciz "makeFirstResponder:"
Ln_keyDown:                   .asciz "keyDown:"
Ln_keyCode:                   .asciz "keyCode"
Ln_acceptsFirstResponder:     .asciz "acceptsFirstResponder"

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
Lc_NSPopUpButton:    .asciz "NSPopUpButton"
Lc_NSScreen:          .asciz "NSScreen"
Lc_NSResponder:       .asciz "NSResponder"

.section __TEXT,__const
.p2align 3
L_c_size:          .double 640.0, 400.0
L_c_frame:         .double 0.0, 0.0, 640.0, 400.0
L_c_hudframe:      .double 14.0, 370.0, 475.0, 20.0
L_c_popupframe:    .double 495.0, 365.0, 132.0, 27.0
L_c_hudfont:       .double 12.0
L_c_hudalpha:      .double 0.78
L_c_one:           .double 1.0
L_c_million:       .double 1000000.0
L_c_hundred:       .double 100.0
L_c_megabyte:      .double 1048576.0

_resolutionTable:
    .quad 160, 100, 4
    .quad 320, 200, 2
    .quad 640, 400, 1

_windowSizeTable:
    .double 640.0, 400.0
    .double 800.0, 500.0
    .double 1024.0, 640.0

.p2align 2
_orbitTable:
    .short  150, 0, 149, 2, 147, 4, 144, 5
    .short  139, 7, 132, 9, 125, 10, 116, 12
    .short  106, 13, 95, 14, 83, 16, 71, 17
    .short  57, 17, 44, 18, 29, 18, 15, 19
    .short  0, 19, -15, 19, -29, 18, -44, 18
    .short  -57, 17, -71, 17, -83, 16, -95, 14
    .short  -106, 13, -116, 12, -125, 10, -132, 9
    .short  -139, 7, -144, 5, -147, 4, -149, 2
    .short  -150, 0, -149, -2, -147, -4, -144, -5
    .short  -139, -7, -132, -9, -125, -10, -116, -12
    .short  -106, -13, -95, -14, -83, -16, -71, -17
    .short  -57, -17, -44, -18, -29, -18, -15, -19
    .short  0, -19, 15, -19, 29, -18, 44, -18
    .short  57, -17, 71, -17, 83, -16, 95, -14
    .short  106, -13, 116, -12, 125, -10, 132, -9
    .short  139, -7, 144, -5, 147, -4, 149, -2

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
    .quad Ln_setImage
    .quad Ln_release
    .quad Ln_setStringValue
    .quad Ln_setCacheMode
    .quad Ln_initWithFramePullsDown
    .quad Ln_addItemWithTitle
    .quad Ln_selectItemAtIndex
    .quad Ln_indexOfSelectedItem
    .quad Ln_setTarget
    .quad Ln_setAction
    .quad Ln_resolutionChanged
    .quad Ln_cycleResolution
    .quad Ln_mainScreen
    .quad Ln_maximumFramesPerSecond
    .quad Ln_display
    .quad Ln_setAutoresizingMask
    .quad Ln_setContentSize
    .quad Ln_makeFirstResponder
    .quad Ln_keyDown
    .quad Ln_keyCode
    .quad Ln_acceptsFirstResponder
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
    .quad Lc_NSPopUpButton
    .quad Lc_NSScreen
    .quad Lc_NSResponder
    .quad 0

_pixels:     .quad 0
_deviceRGB:  .quad 0
_imageView:  .quad 0
_hud:        .quad 0
_popup:      .quad 0
_controller: .quad 0
_window:     .quad 0
_frame:      .quad 0
_renderWidth:    .quad 160
_renderHeight:   .quad 100
_coordScale:     .quad 4
_resolutionIndex:.quad 0
_cameraOrbit:   .quad 8
_cameraTilt:    .quad 64
_statsTime:  .double 0.0
_lastCpuUs:  .quad 0
_statsFrames:.quad 0
_statsBuf:   .space 160
.p2align 3
_rusage:     .space 160
.p2align 3
_taskInfo:   .space 48
_taskInfoCount:
    .long 12
    .space 4

_sels:       .space 60 * 8
_classes:    .space 16 * 8

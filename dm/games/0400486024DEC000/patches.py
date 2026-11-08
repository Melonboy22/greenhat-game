# The Legend of Zelda: Ocarina of Time (0400486024DEC000): the rewriter's patches of this game's own builds (dm/tools/patch_nso.py, "Registered patches").
#
# Ultrawide (opt-in at build time): DM_ULTRAWIDE=<width>x<height> (the screen, e.g. 3440x1440 or 2560x1080) makes the game render that shape natively, with a wider view,
# not a stretch. The game sizes everything from its 1440-high docked output, so the widths become 1440 x the screen's ratio (3440 for 21:9, a multiple of 16); the 3D view
# takes its aspect from the render size, so the field of view widens and nothing is distorted; the HUD stays at its 16:9 place in the middle. The host shows the game's
# crop (WindowCrop) scaled to the window, so with DM_FULLSCREEN=1 it fills the screen. Found on a 3440x1440 screen (Mac, M4 Pro):
#   main+0x1202ee0  the graphics setup config's output size (stur at [x21+0x14], read back as the swap chain size at main+0x346c24c): 2560 x 1440
#   main+0x31f39f4  the render size config, docked 2560 x 1440 and handheld (main+0x31f3a00) 1920 x 1080
#   main+0xecbc80   2560.0f beside 1440.0f in the same object's init (its float copy of the output size)
#   main+0x3f58540  the output resolution table (640x480 ... 3840x2160, read at main+0x112c600 by the display mode): each width from its height
# Without it the swap chain is 2560x1440 and the game's crop 16:9 (2048x1152 at its usual 80 % dynamic resolution); with 3440x1440 the swap chain is 3440x1440 and the crop
# 2752x1152 (2.389:1). Movies and the opening title stay 16:9 in the middle of the wider picture.
import os, struct
from nso_asm import ADRP, B

CUTS = {}
_uw = os.environ.get('DM_ULTRAWIDE', '')
if _uw:
    _w, _h = (int(v) for v in _uw.lower().split('x'))
    _ratio = _w / _h
    def _width(h): return int(round(h * _ratio / 16)) * 16
    def _movz(imm, rd, x64): return struct.pack('<I', (0xD2800000 if x64 else 0x52800000) | imm << 5 | rd).hex()
    _table = [640, 480, 720, 480, 1280, 720, 1600, 900, 1920, 1080, 2560, 1440, 3840, 2160]
    _wide = [v if i % 2 else _width(_table[i + 1]) for i, v in enumerate(_table)]
    _f = struct.unpack('<I', struct.pack('<f', float(_width(1440))))[0] >> 16
    CUTS.setdefault('e0f3ccfaf50065ae4ea01eb5aeb13b1a', []).extend([
        (0x1202ee0, _movz(2560, 8, True), _movz(_width(1440), 8, True), 'ultrawide: graphics setup output width 2560 → %d (DM_ULTRAWIDE)' % _width(1440)),
        (0x31f39f4, _movz(2560, 8, True), _movz(_width(1440), 8, True), 'ultrawide: docked render width 2560 → %d' % _width(1440)),
        (0x31f3a00, _movz(1920, 8, True), _movz(_width(1080), 8, True), 'ultrawide: handheld render width 1920 → %d' % _width(1080)),
        (0xecbc80, struct.pack('<I', 0x52A8A409).hex(), struct.pack('<I', 0x52A00009 | _f << 5).hex(), 'ultrawide: output width 2560.0f → %d.0f' % _width(1440)),
        (0x3f58540, struct.pack('<14I', *_table).hex(), struct.pack('<14I', *_wide).hex(), 'ultrawide: output resolution table widths from their heights'),
    ])

# Real-time speed. The frame loop (main+0x6e6be0) computes each frame's step as a constant over its target frame rate and never reads the clock: s1 is 60, or 30 in one mode of the game
# (the fcsel at main+0x6e6cc0), s0 the target, so one frame is one step however long it took and everything runs slowly below the target. Found by gunvalk (zortos293/Lichii PR #216).
# The stub keeps that division and takes the larger of it and s1 x the measured frame time (state +0x38, float seconds, hle_nvn.c): 0 there leaves the game's own step, and the step is
# never below it. It marks state +0x3c so the host measures only for a main that reads the value. x16, x17 and s0 are not read again before they are written after the site
def real_speed(ctx):
    here, emit = ctx.here, ctx.emit
    ctx.site(0x6e6cc4, '2818201e')
    start = here()
    emit(0x1e201828)                       # fdiv s8,s1,s0        the game's own step
    emit(ADRP(16, here(), ctx.state))
    for w in (0x52800031,   # mov w17,#1
              0xb9003e11,   # str w17,[x16,#0x3c]  this main reads the frame time
              0xbd403a00,   # ldr s0,[x16,#0x38]   seconds; 0 = at the target
              0x1e210800,   # fmul s0,s0,s1
              0x1e204908):  # fmax s8,s8,s0
        emit(w)
    emit(B(here(), 0x6e6cc8))
    ctx.put(0x6e6cc4, [B(0x6e6cc4, start)], 'frame step from the measured frame time, never below the game\'s own (state +0x38)')


# Frame rate limiter (from cheemu21's kid-with-sword-remake, its V4 frame step). The game has its own frame-rate controller (main+0x3b4ef60, called once a frame with x20 = its
# config): from the measured frame time it picks a vsync interval between config +0x0 and +0x4 (with hysteresis, +0x50 / +0x54), stores it at +0x48 and fps = 60 / interval
# at +0x58, then at main+0x3b4f074 (where its paths meet) calls main+0x3b4f160, which hands +0x58 to setFrameRate (main+0x4dc0f0), and the framework's setInterval
# (main+0x346c5c0) with +0x48, which sets the window's present interval (main+0xf49970) and the framework's fps (+0xfc = 60 / interval). So 30 fps (interval 2) is the game's
# own mode, with its game time stepping by the interval. The stub at main+0x3b4f074 replaces the interval and fps with the host's step (state page +0x20, 1 = 60 fps, 2 = 30) while
# a target fps is set (state +0x0, the launcher's Frame rate / DM_FPS_TARGET; 0 = the game's own choice), and counts the vsyncs stepped (+0x30) for the host's speed check.
# real_speed's step (state +0x38) stays: at 30 the game's own 30 fps mode already steps by two, and the measured time only raises the step when a frame comes later than that
def fps_limit(ctx):
    here, emit = ctx.here, ctx.emit
    site = 0x3b4f074
    ctx.site(site, 'e00314aa')   # mov x0,x20
    start = here(); emit(ADRP(16, here(), ctx.state))
    for w in (0xb9400211,   # ldr w17,[x16]           target fps (float bits; 0 = off)
              0x34000151,   # cbz w17,orig (+10)
              0xb9402211,   # ldr w17,[x16,#0x20]     step in vsyncs
              0x34000111,   # cbz w17,orig (+8)       not decided yet
              0xb9004a91,   # str w17,[x20,#0x48]     the controller's interval
              0x52800789,   # mov w9,#60
              0x1ad10929,   # udiv w9,w9,w17
              0xb9005a89,   # str w9,[x20,#0x58]      its fps, which setFrameRate takes
              0xf9401a09,   # ldr x9,[x16,#0x30]
              0x8b314129,   # add x9,x9,w17,uxtw
              0xf9001a09,   # str x9,[x16,#0x30]      vsyncs stepped
              0xaa1403e0):  # orig: mov x0,x20
        emit(w)
    emit(B(here(), site + 4))
    ctx.put(site, [B(site, start)], "frame rate limiter: the frame-rate controller's interval and fps follow the host's vsyncs (state page target fps; 0 = the game's own choice)")
    ctx.fps_limit = 1   # the launcher offers the game's own step (fps_target 0, the default) and 30


# Render scale (DM_RENDER_SCALE, state +0x10, dm/host/loader.c). The 3D views' sizes come from the scale the engine stores at main+0x31d3f48 (str s0,[x20,#0xe5c], found by
# upstream PR #1497), but that store and the size loop after it (main+0x31d3fd8, which clears the "scale changed" bit 3 of [x20+0xe2c] at main+0x31d40b4) run only in a frame
# where the dynamic-resolution controller (bl main+0x805aa0) answers status 0, a new scale: at a steady 60 fps it never does, so a stub at the store alone changed nothing until
# the game came under load. Two stubs: at the controller's answer (main+0x31d3ee4, ubfx of its status byte) a host scale below 1.0 that is not the stored one makes the status 0, so
# that frame recomputes the sizes; at the store the host scale replaces the game's (seedds' fixed form of #1497's ceiling). The scale is then fixed and the dynamic resolution off;
# 0, unset or 1.0 run the game's own code. Registers and flags are kept but x8 (the status, as the game reads it next) and s0 (dead after the store: main+0x31d3f84 reloads it).
# The scale is a fraction of the output (the size loop's cap at main+0x31d3fe8 is skipped on this path, bit 0x13 of +0xe20): docked, 0.75 is the game's usual 1920x1080 and 0.5
# draws 1280x720, 0.9 2328x1310. The game picks its NDSR network by the ratio, and nvn_mtl.m's DM_NDSR replacement takes whichever follows the chain's third dispatch
_SCALE_STATUS, _SCALE_STORE = 0x31d3ee4, 0x31d3f48

def _bcond(frm, to, cond): return 0x54000000 | (((to - frm) >> 2) & 0x7ffff) << 5 | cond
def _cbz_w(frm, to, rt): return 0x34000000 | (((to - frm) >> 2) & 0x7ffff) << 5 | rt

def render_scale(ctx):
    here, emit = ctx.here, ctx.emit
    ctx.site(_SCALE_STATUS, '089c60d3')   # ubfx x8,x0,#32,#8: the controller's status byte
    s = here(); at = lambda k: s + 4 * k   # the stub's k-th word; done is word 16
    for k, w in enumerate((
            0xd3609c08,                       # ubfx x8,x0,#32,#8     the original
            0xa9be47f0,                       # stp x16,x17,[sp,#-32]!
            0xd53b4210,                       # mrs x16,nzcv
            0xf9000bf0,                       # str x16,[sp,#16]
            ADRP(16, at(4), ctx.state),
            0xb9401211,                       # ldr w17,[x16,#0x10]  the host scale's bits
            _cbz_w(at(6), at(16), 17),        # cbz w17,done         unset
            0x52a7f010,                       # mov w16,#0x3f800000
            0x6b10023f,                       # cmp w17,w16
            _bcond(at(9), at(16), 0x2),       # b.hs done            1.0 or more, negative or NaN: the game's own
            0x7100051f,                       # cmp w8,#1
            _bcond(at(11), at(16), 0x0),      # b.eq done            status 1, the game's other request (main+0x31d3f4c), is left alone
            0xb94e5e90,                       # ldr w16,[x20,#0xe5c] the stored scale
            0x6b11021f,                       # cmp w16,w17
            _bcond(at(14), at(16), 0x0),      # b.eq done            already the host's
            0x52800008,                       # mov w8,#0            status 0: a new scale, so the sizes are recomputed
            0xf9400bf0,                       # done: ldr x16,[sp,#16]
            0xd51b4210,                       # msr nzcv,x16
            0xa8c247f0)):                     # ldp x16,x17,[sp],#32
        assert here() == at(k); emit(w)
    emit(B(here(), _SCALE_STATUS + 4))
    ctx.put(_SCALE_STATUS, [B(_SCALE_STATUS, s)], 'dynamic-resolution status: a host render scale not yet stored asks for new 3D sizes (state +0x10)')

    ctx.site(_SCALE_STORE, '805e0ebd')    # str s0,[x20,#0xe5c]
    s = here()   # original is word 11
    for k, w in enumerate((
            0xadbf7ffe,                       # stp q30,q31,[sp,#-32]!
            0xa9bf47f0,                       # stp x16,x17,[sp,#-16]!
            ADRP(16, at(2), ctx.state),
            0xd53b4211,                       # mrs x17,nzcv
            0xbd40121e,                       # ldr s30,[x16,#0x10]  the host scale
            0x1e2023c8,                       # fcmp s30,#0.0
            _bcond(at(6), at(11), 0xd),       # b.le original        unset, negative or NaN
            0x1e2e101f,                       # fmov s31,#1.0
            0x1e3f23c0,                       # fcmp s30,s31
            _bcond(at(9), at(11), 0xa),       # b.ge original        1.0 or more
            0x1e2043c0,                       # fmov s0,s30          the host's fixed scale
            0xbd0e5e80,                       # original: str s0,[x20,#0xe5c]
            0xbd001600,                       # str s0,[x16,#0x14]   the scale stored, for the host's log (A11)
            0xd51b4211,                       # msr nzcv,x17
            0xa8c147f0,                       # ldp x16,x17,[sp],#16
            0xacc17ffe)):                     # ldp q30,q31,[sp],#32
        assert here() == at(k); emit(w)
    emit(B(here(), _SCALE_STORE + 4))
    ctx.put(_SCALE_STORE, [B(_SCALE_STORE, s)], 'final 3D view scale: the host render scale fixes it below 1.0 (1.0 = the game\'s dynamic resolution)')

    ctx.render_scale = 1


# The dynamic resolution's GPU load (stan69b/nxnative oot-main f4b3abd6). The GPU meter (main+0x5a8f0, each frame) takes the GPU time between two counter timestamps in microseconds
# and its load as a percent of one 1/60 s frame (main+0x5aa54 loads 16666.67 from main+0x3e40ec8, which nothing else reads); the resolution controller steps down above its palette's
# LoadThreshold (98) and up after IncreaseCounterMax (60) frames below it. Under a 30 fps target a frame has 33.3 ms, but the load stayed a percent of 16.7 ms, so a 25 ms frame read
# 150% and the scene stayed at its floor (683x384 of 1536x864 in stan69b's measurement). The stub loads the target's frame time instead, 1e6 / target fps (state +0x0, a float:
# 16666.67 at 60, 33333.33 at 30); without a target, the game's constant. The target, not the step decided per frame: a late frame must not raise its own budget. It matters only with
# the dynamic resolution on (render scale 1.0) and GPU times the meter can read (counter reports per segment, DM_NVN_GPU_TS=segment).
# A11 (kid-with-sword-remake): the budget is a share of that frame time (state +0x18, DM_DRS_BUDGET, 0.85 by default). At the whole 33.3 ms the controller stepped down only above
# 98 % (32.6 ms): on an A20 Pro the GPU sat at 29-30 ms with a p95 of 35-37 ms, the scene stayed at 1920x1080 and the late frames were held a third vsync (log 48)
def gpu_meter_budget(ctx):
    here, emit = ctx.here, ctx.emit
    site = 0x5aa54
    ctx.site(site, '02c94ebd')   # ldr s2,[x8,#0xec8]   16666.67 (x8 = its page)
    start = here(); emit(ADRP(9, here(), ctx.state))
    for w in (0xb9400129,   # ldr w9,[x9]            target fps (float bits; 0 = off)
              0x340001a9,   # cbz w9,orig (+13)
              0x1e270123,   # fmov s3,w9
              0x52848009,   # mov w9,#0x2400
              0x72a92e89,   # movk w9,#0x4974,lsl #16   1e6
              0x1e270122,   # fmov s2,w9
              0x1e231842):  # fdiv s2,s2,s3          the target's frame time in microseconds
        emit(w)
    emit(ADRP(9, here(), ctx.state))
    emit(0xbd001d20)        # str s0,[x9,#0x1c]      the GPU time the meter measured, microseconds (s0 at this site: its two counter timestamps apart, scaled), for the host's log (A13)
    emit(0xb9401929)        # ldr w9,[x9,#0x18]      budget share (float bits; 0 = all of it)
    emit(0x34000069)        # cbz w9,+3
    emit(0x1e270123)        # fmov s3,w9
    emit(0x1e230842)        # fmul s2,s2,s3          the share of the frame the GPU may take
    emit(B(here(), site + 4))
    emit(0xbd4ec902)        # orig: ldr s2,[x8,#0xec8]
    emit(B(here(), site + 4))
    ctx.put(site, [B(site, start)], "GPU meter: the load is a percent of the target's frame time (state +0x0 target fps; 0 = the game's 1/60 s)")


def frame_step(ctx):   # the four stubs of this build, each at its own site
    real_speed(ctx)
    fps_limit(ctx)
    render_scale(ctx)
    gpu_meter_budget(ctx)


FRAME_STEP = {'e0f3ccfaf50065ae4ea01eb5aeb13b1a': frame_step}   # 1.1.1 (v131072), the main of v0 too

BINDING = [
    {'what': 'ultrawide output and render sizes (opt-in, DM_ULTRAWIDE)', 'now': 'build', 'goal': 'game', 'purpose': 'rendering',
     'why': "the game's own size constants; a function-matched rule could carry them over the game's updates"},
    {'what': 'frame step from the measured frame time', 'now': 'build', 'goal': 'game', 'purpose': 'frame rate',
     'why': "this game's own frame loop; the frame-step state page is general",
     'blocked': 'frame-step stubs have no function-matched form yet'},
    {'what': "frame rate limiter: the frame-rate controller's interval and fps from the host", 'now': 'build', 'goal': 'game', 'purpose': 'frame rate',
     'why': "the game's own 30 fps mode (interval 2), chosen by the host's step so presentation and game time agree (from cheemu21's kid-with-sword-remake)",
     'blocked': 'frame-step stubs have no function-matched form yet'},
    {'what': 'render scale at the dynamic-resolution status and the final 3D view scale store', 'now': 'build', 'goal': 'game', 'purpose': 'rendering',
     'why': "the game's controller status and final scale store are its own code at fixed addresses",
     'blocked': 'the two sites and their roles are verified for this main build only',
     'checked': 'v131072 main E0F3CCFAF50065AE4EA01EB5AEB13B1A: the status ubfx at +0x31d3ee4, the store at +0x31d3f48 and the size loop that clears bit 3 of +0xe2c, 2026-11-06'},
    {'what': "GPU meter's budget follows the target fps (dynamic resolution)", 'now': 'build', 'goal': 'engine', 'purpose': 'rendering',
     'why': "the game's own GPU meter divides by a literal 1/60 s; another build moves the literal and its load (from stan69b's oot-main f4b3abd6)",
     'blocked': 'frame-step stubs have no function-matched form yet'},
]

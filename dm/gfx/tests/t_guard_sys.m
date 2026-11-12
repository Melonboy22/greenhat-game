// The GPU memory guard's system side (guard_sys_tick): the level follows the memory the system can still give against the margin (DM_NVN_SYS_MARGIN_MB), and guard_level takes the higher of it
// and the working-set side. The test ends in well under the timer's GUARD_TICKS (1 s) over the stop level, so the front end's stop is never reached
#define nvn_game_fps nvn_game_fps_mtl_default
#include "../nvn/nvn_mtl.m"
#undef nvn_game_fps
uint64_t g_t0_ns;
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(c, s) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s\n", s); } } while (0)
int main(int argc, char **argv) { @autoreleasepool {
    setenv("DM_NVN_SYS_MARGIN_MB", "1048576", 1);   // a 1 TB margin: the system never has that much left
    setenv("DM_NVN_SYS_MARGIN_DECAY_S", "0", 1);
    int deflt = argc > 1 && !strcmp(argv[1], "--default-max");   // a run of its own: the cap is read once
    if (!deflt) setenv("DM_NVN_SYS_MARGIN_MAX_MB", "4096", 1);   // the checks below take warnings up to 4 GB   // the margin comes down a step at each tick (margin_decay)
    mtl_init();
    CHECK(atomic_load(&g_sys_margin) == (1048576ull << 20), "the margin comes from DM_NVN_SYS_MARGIN_MB");
    guard_sys_tick();
    CHECK(atomic_load(&g_sys_avail) > 0, "the system's available memory is read");
    CHECK(atomic_load(&g_sys_lv) == GUARD_STOP, "available memory under the margin: stop");
    CHECK(!g_guard.stop || guard_level(0) == GUARD_STOP, "guard_level takes the system side even with nothing resident");
    atomic_store(&g_sys_margin, 1ull << 20); guard_sys_tick();   // 1 MB: always more left than that
    CHECK(atomic_load(&g_sys_lv) == GUARD_OK, "available memory over twice the margin: no level");
    CHECK(!g_guard.stop || guard_level(0) == GUARD_OK, "and guard_level is back to the working-set side");
    uint64_t avail = atomic_load(&g_sys_avail);
    atomic_store(&g_sys_margin, avail / 2 + (64ull << 20)); guard_sys_tick();   // between the margin and twice it, unless the system moved by more than 64 MB in between
    CHECK(atomic_load(&g_sys_lv) == GUARD_EVICT, "available memory between the margin and twice it: evict");
    // Memory pressure events (guard_pressure): a warning raises the margin by 512 MB, up to 4 GB; back to normal, it comes down a step per DM_NVN_SYS_MARGIN_DECAY_S (0 here: a step at
    // each tick) with no warning in between (margin_decay)
    atomic_store(&g_sys_margin_base, 1024ull << 20); atomic_store(&g_sys_margin, 1024ull << 20);
    if (deflt) {   // DM_NVN_SYS_MARGIN_MAX_MB unset: warnings take the margin to the base plus 1 GB at most
        for (int i = 0; i < 8; i++) guard_pressure(DISPATCH_MEMORYPRESSURE_WARN);
        CHECK(atomic_load(&g_sys_margin) == (2048ull << 20), "by default warnings raise the margin to the base plus 1 GB (2,048 MB), no further");
        printf("t_guard_sys (default max): %d checks, %d failed\n", checks, failed);
        return failed != 0;
    }
    guard_pressure(DISPATCH_MEMORYPRESSURE_WARN); guard_pressure(DISPATCH_MEMORYPRESSURE_WARN); guard_pressure(DISPATCH_MEMORYPRESSURE_CRITICAL);
    CHECK(atomic_load(&g_sys_margin) == (2560ull << 20), "three pressure events raise the margin to 2,560 MB");
    for (int i = 0; i < 8; i++) guard_pressure(DISPATCH_MEMORYPRESSURE_WARN);
    CHECK(atomic_load(&g_sys_margin) == (4096ull << 20), "the raised margin stops at 4 GB");
    guard_sys_tick(); CHECK(atomic_load(&g_sys_margin) == (4096ull << 20), "no normal event yet: the margin stays");
    guard_pressure(DISPATCH_MEMORYPRESSURE_NORMAL);
    CHECK(atomic_load(&g_sys_margin) == (4096ull << 20), "pressure back to normal: the margin is not dropped at once");
    guard_sys_tick(); CHECK(atomic_load(&g_sys_margin) == (3584ull << 20), "a decay period later: one 512 MB step down");
    guard_sys_tick(); guard_sys_tick(); CHECK(atomic_load(&g_sys_margin) == (2560ull << 20), "a step per period");
    guard_pressure(DISPATCH_MEMORYPRESSURE_WARN);
    CHECK(atomic_load(&g_sys_margin) == (3072ull << 20), "a warning raises it again from where it is");
    guard_sys_tick(); CHECK(atomic_load(&g_sys_margin) == (3072ull << 20), "after a warning no step down until the next normal event");
    guard_pressure(DISPATCH_MEMORYPRESSURE_NORMAL); for (int i = 0; i < 10; i++) guard_sys_tick();
    CHECK(atomic_load(&g_sys_margin) == (1024ull << 20), "the steps stop at the base");
    atomic_store(&g_sys_margin_base, 0); atomic_store(&g_sys_margin, 0); guard_pressure(DISPATCH_MEMORYPRESSURE_WARN);
    CHECK(atomic_load(&g_sys_margin) == 0, "with the system side off (margin 0) pressure events change nothing");
    atomic_store(&g_sys_margin, 0); atomic_store(&g_sys_lv, GUARD_OK); guard_sys_tick();
    CHECK(atomic_load(&g_sys_lv) == GUARD_OK, "a margin of 0 turns the system side off");
    printf("t_guard_sys: %d checks, %d failed\n", checks, failed); return failed != 0;
} }

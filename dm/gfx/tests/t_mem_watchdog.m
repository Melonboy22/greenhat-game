// The memory watchdog (hle_nvn.c dm_mem_watchdog): over its cap it asks the graphics layer for a relief (mtl_mem_relief) and stops nothing while the system has memory to give; with the
// system short too (the guard's system side at its eviction level) it stops after three checks over the cap in a row; past the cap by more than 1.5 GB it stops at once. A stop goes to the
// front end (front_memory_stop), once. Each stop ends the watchdog for good, so each case is a run of its own: (none), "low", "runaway"
#include "../nvn/nvn_mtl.m"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed, stops; static unsigned long long stop_mb, stop_cap;
#define CHECK(label, c) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)
void front_memory_stop(unsigned long long used_mb, unsigned long long cap_mb) { stops++; stop_mb = used_mb; stop_cap = cap_mb; }
void dm_mem_watchdog(unsigned long long mb, long long cap);
static void sys(int low) { atomic_store(&g_sys_margin, 1024ull << 20); atomic_store(&g_sys_lv, low ? GUARD_EVICT : GUARD_OK); }
static int relief(void) { return atomic_exchange(&g_relief_req, 0); }

int main(int argc, char **argv) { @autoreleasepool {
    const char *mode = argc > 1 ? argv[1] : "";
    const long long cap = 13 * 1024;
    if (!strcmp(mode, "low")) {
        sys(1);
        dm_mem_watchdog(cap + 300, cap); CHECK("system short, first check over: a relief, no stop", relief() && !stops);
        dm_mem_watchdog(cap + 300, cap); CHECK("second check over: a relief, no stop", relief() && !stops);
        dm_mem_watchdog(cap + 300, cap); CHECK("third check over with the system short: the stop, with the sizes", stops == 1 && stop_mb == (unsigned long long)cap + 300 && stop_cap == (unsigned long long)cap);
        dm_mem_watchdog(cap + 300, cap); CHECK("after the stop nothing more", stops == 1 && !relief());
    } else if (!strcmp(mode, "runaway")) {
        sys(0);
        dm_mem_watchdog(cap + 1600, cap); CHECK("past the cap by more than 1.5 GB: the stop at once, the system not short", stops == 1 && stop_mb == (unsigned long long)cap + 1600);
    } else {
        sys(0);
        dm_mem_watchdog(cap - 100, cap); CHECK("under the cap: nothing", !stops && !relief());
        for (int i = 0; i < 10; i++) dm_mem_watchdog(cap + 400, cap);
        CHECK("over the cap ten checks in a row with the system not short: reliefs, no stop", !stops && relief());
        dm_mem_watchdog(cap - 50, cap); CHECK("back under: nothing asked", !stops && !relief());
        sys(1); dm_mem_watchdog(cap + 400, cap); dm_mem_watchdog(cap + 400, cap); dm_mem_watchdog(cap - 10, cap); dm_mem_watchdog(cap + 400, cap); dm_mem_watchdog(cap + 400, cap);
        CHECK("over, short, but never three checks in a row: no stop", !stops);
        dm_mem_watchdog(cap + 400, 0); CHECK("a cap of 0 turns it off", !stops);
        // The relief on the submit thread: guard_act takes the request and trims the ring to an eighth of its floor
        setenv("DM_NVN_GHOST_TRIM_MIN", "1024", 1); mtl_init(); sys(0);
        MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:16 height:16 mipmapped:NO]; d.storageMode = MTLStorageModePrivate;
        for (uint64_t i = 0; i < 1500; i++) { id<MTLTexture> t = [g_dev newTextureWithDescriptor:d]; res_add(t); tex_put(8000000 + i, t); }
        mtl_mem_relief(); guard_act(0);
        CHECK("guard_act carries out the relief: the ring down to an eighth of its floor (128)", g_ghost.n == 128 && !relief());
        mtl_drain(); defer_drain();
    }
    printf("t_mem_watchdog%s%s: %d checks, %d failed\n", *mode ? " " : "", mode, checks, failed);
    return failed != 0;
}}

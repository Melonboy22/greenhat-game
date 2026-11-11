// ghost_trim (nvn_mtl.m): the ring of finalized serials gives back entries, oldest first, only at the guard's stop level (force 1, down to DM_NVN_GHOST_TRIM_MIN) and for the memory
// watchdog (force 2, an eighth of it), never at the eviction level (force 0); only packaged textures not resolved for GHOST_TRIM_IDLE frames (ghost_restorable): a GPU-written texture
// and one used lately stay. DM_NVN_GHOST_TRIM_MIN=0 turns it off (a second run of this test)
#include "../nvn/nvn_mtl.m"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(label, c) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)
static MTLTextureDescriptor *g_d;
static id<MTLTexture> tex(void) { id<MTLTexture> t = [g_dev newTextureWithDescriptor:g_d]; res_add(t); return t; }
static void put_pkg(uint64_t serial, uint64_t used) { NvPkg *pk = [NvPkg new]; pk->tex = tex(); pk->used = used; tex_put(serial, pk); }   // a packaged texture, last resolved at frame used

int main(int argc, char **argv) { @autoreleasepool {
    int off = argc > 1 && !strcmp(argv[1], "--off");
    setenv("DM_NVN_GHOST_TRIM_MIN", off ? "0" : "100", 1);
    mtl_init();
    g_d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:64 height:64 mipmapped:NO]; g_d.storageMode = MTLStorageModePrivate;
    atomic_store(&g_cur_frame, 10000);
    enum { N = 1000 }; const uint64_t base = 7000000;
    for (uint64_t i = 0; i < N; i++) put_pkg(base + i, 0);   // never initialized: each goes into the ring, idle since frame 0
    CHECK("the finalized serials are in the ring", g_ghost.n == N);
    if (off) {
        CHECK("DM_NVN_GHOST_TRIM_MIN=0: nothing is trimmed", ghost_trim(0) == 0 && ghost_trim(1) == 0 && ghost_trim(2) == 0 && g_ghost.n == N);
    } else {
        CHECK("the eviction level (force 0) trims nothing", ghost_trim(0) == 0 && g_ghost.n == N);
        unsigned n = ghost_trim(1);
        CHECK("the stop level goes to the floor", n == N - 100 && g_ghost.n == 100);
        CHECK("the oldest no longer resolve, the newest 100 do", tex_get(base) == nil && tex_get(base + N - 101) == nil && tex_get(base + N - 100) != nil && tex_get(base + N - 1) != nil);
        n = ghost_trim(2); CHECK("the watchdog's relief goes to an eighth of the floor (64 at least)", g_ghost.n == 64 && n == 36);
        CHECK("at the floor nothing more goes", ghost_trim(2) == 0 && g_ghost.n == 64);
        // What stays whatever the level: a texture that is not packaged (a render target, a texture the GPU wrote: made again it would read cleared) and a packaged one used lately
        for (uint64_t i = 0; i < 200; i++) tex_put(base + 2000 + i, tex());
        for (uint64_t i = 0; i < 200; i++) put_pkg(base + 3000 + i, 10000 - 100);   // resolved 100 frames ago
        n = ghost_trim(2);
        CHECK("GPU-written and lately used textures stay at the deepest trim", n == 64 && g_ghost.n == 400 && tex_get(base + 2000) != nil && tex_get(base + 3000) != nil);
        atomic_store(&g_cur_frame, 10000 + GHOST_TRIM_IDLE);
        n = ghost_trim(2);
        CHECK("once idle for GHOST_TRIM_IDLE frames the packaged ones go too, the GPU-written ones never", g_ghost.n == 200 && tex_get(base + 3199) == nil && tex_get(base + 2000) != nil && tex_get(base + 2199) != nil);
    }
    mtl_drain(); defer_drain();
    printf("t_ghost_trim%s: %d checks, %d failed\n", off ? " (off)" : "", checks, failed);
    return failed != 0;
}}

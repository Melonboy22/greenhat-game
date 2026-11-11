// ghost_trim (nvn_mtl.m): under memory pressure the ring of finalized serials gives back its oldest half, down to DM_NVN_GHOST_TRIM_MIN entries; force goes to that floor; the
// newest entries stay and still resolve; the oldest resolve no more; DM_NVN_GHOST_TRIM_MIN=0 turns it off (checked in a second run of this test)
#include "../nvn/nvn_mtl.m"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(label, c) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)

int main(int argc, char **argv) { @autoreleasepool {
    int off = argc > 1 && !strcmp(argv[1], "--off");
    setenv("DM_NVN_GHOST_TRIM_MIN", off ? "0" : "100", 1);
    mtl_init();
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:64 height:64 mipmapped:NO]; d.storageMode = MTLStorageModePrivate;
    enum { N = 1000 }; const uint64_t base = 7000000;
    for (uint64_t i = 0; i < N; i++) { id<MTLTexture> t = [g_dev newTextureWithDescriptor:d]; res_add(t); tex_put(base + i, t); }   // never initialized: each goes into the ring
    CHECK("the finalized serials are in the ring", g_ghost.n == N);
    if (off) {
        CHECK("DM_NVN_GHOST_TRIM_MIN=0: nothing is trimmed", ghost_trim(0) == 0 && ghost_trim(1) == 0 && g_ghost.n == N);
    } else {
        unsigned n = ghost_trim(0);
        CHECK("the eviction level gives back the oldest half", n == N / 2 && g_ghost.n == N / 2);
        CHECK("the oldest no longer resolves", tex_get(base) == nil && tex_get(base + N / 2 - 1) == nil);
        CHECK("the newest still resolves", tex_get(base + N / 2) != nil && tex_get(base + N - 1) != nil);
        n = ghost_trim(0); CHECK("again: half of what is left", n == N / 4 && g_ghost.n == N / 4);
        n = ghost_trim(1); CHECK("the stop level goes to the floor", g_ghost.n == 100 && n == N / 4 - 100);
        CHECK("the floor keeps the newest 100", tex_get(base + N - 100) != nil && tex_get(base + N - 101) == nil);
        CHECK("at the floor nothing more goes", ghost_trim(1) == 0 && ghost_trim(0) == 0 && g_ghost.n == 100);
        // The ring goes on filling after a trim: new serials take the emptied slots, and the oldest of them go first when the ring is full again
        for (uint64_t i = 0; i < 50; i++) { id<MTLTexture> t = [g_dev newTextureWithDescriptor:d]; res_add(t); tex_put(base + N + i, t); }
        CHECK("new serials after a trim are in the ring", g_ghost.n == 150 && tex_get(base + N + 49) != nil);
        n = ghost_trim(1); CHECK("a later trim drops the older entries, not the new ones", n == 50 && tex_get(base + N + 49) != nil && tex_get(base + N - 100) == nil);
    }
    mtl_drain(); defer_drain();
    printf("t_ghost_trim%s: %d checks, %d failed\n", off ? " (off)" : "", checks, failed);
    return failed != 0;
}}

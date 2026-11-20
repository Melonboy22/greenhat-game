// The ghost table of finalized texture serials (nvn_mtl.m, kept by use since oot-plus took upstream 034e91a8): each entry's last lookup or put is kept in a list from least to most
// recently used; past the floor (DM_NVN_GHOST_N, 512) the least recently used goes once it is idle (GHOST_IDLE frames or GHOST_IDLE_SUBS submissions without a use), two a put and
// GHOST_TRIM a commit, and an entry in use stays however many there are. A texture the GPU wrote waits GHOST_IDLE_KEPT frames. Under memory pressure (ghost_trim with force 1 or 2)
// the idle entries the floor keeps go too, down to 64; at the eviction level (force 0) nothing more. A second run (--floor) checks DM_NVN_GHOST_N and DM_NVN_GHOST_IDLE
#include "../nvn/nvn_mtl.m"
#include "t_pool_ix_check.h"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(label, c) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)
static MTLTextureDescriptor *g_d;
static id<MTLTexture> tex(void) { id<MTLTexture> t = [g_dev newTextureWithDescriptor:g_d]; res_add(t); return t; }
static void put_pkg(uint64_t serial) { NvPkg *pk = [NvPkg new]; pk->tex = tex(); tex_put(serial, pk); }   // a packaged texture of a finalized serial
static void frames(uint64_t n) { atomic_fetch_add(&g_cur_frame, n); }
static unsigned commit_trim(void) { uint64_t before = g_ghost_drained; ghost_commit_trim(); return (unsigned)(g_ghost_drained - before); }
static void use_all(void) {   // a lookup of every ghost entry: all in use now
    pthread_mutex_lock(&g_smu); uint32_t nk = 0; uint64_t *ks = malloc((g_ghost.n + 1) * sizeof *ks);
    for (const ghost_use *u = g_ghost_lru; u; u = u->next) ks[nk++] = u->serial;
    pthread_mutex_unlock(&g_smu);
    for (uint32_t i = 0; i < nk; i++) (void)tex_get(ks[i]);
    free(ks);
}
static int list_ok(void) {   // the list names every ghost serial once, its links agree both ways, and its uses go from oldest to newest
    pthread_mutex_lock(&g_smu); uint32_t places = 0; const ghost_use *prev = NULL; int ok = 1;
    for (const ghost_use *u = g_ghost_lru; u && ok; prev = u, u = u->next) {
        if (++places > g_ghost_use.n || u->prev != prev || nvn_hm_get(&g_ghost_use, &u->serial) != u || !nvn_hm_get(&g_ghost, &u->serial)) ok = 0;
        else if (prev && (u->frame < prev->frame || u->sub < prev->sub)) ok = 0;
    }
    ok = ok && prev == g_ghost_mru && places == g_ghost.n && g_ghost_use.n == g_ghost.n;
    pthread_mutex_unlock(&g_smu); return ok;
}

int main(int argc, char **argv) { @autoreleasepool {
    int floor_run = argc > 1 && !strcmp(argv[1], "--floor");
    if (floor_run) { setenv("DM_NVN_GHOST_N", "100", 1); setenv("DM_NVN_GHOST_IDLE", "10", 1); }
    mtl_init();
    g_d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:16 height:16 mipmapped:NO]; g_d.storageMode = MTLStorageModePrivate;
    atomic_store(&g_cur_frame, 10000);
    const unsigned floor_ = ghost_floor(); const uint64_t idle = ghost_idle(), base = 7000000;
    CHECK("the floor and the idle time", floor_run ? floor_ == 100 && idle == 10 : floor_ == NGHOST && idle == GHOST_IDLE);
    if (floor_run) {
        for (uint64_t i = 0; i < 300; i++) put_pkg(base + i);
        frames(idle); while (commit_trim()) {}
        CHECK("DM_NVN_GHOST_N and DM_NVN_GHOST_IDLE: idle after 10 frames, down to 100", g_ghost.n == 100 && list_ok());
    } else {
        // Entries in use stay past the floor
        const unsigned N = floor_ + 1500;
        for (uint64_t i = 0; i < N; i++) put_pkg(base + i);
        CHECK("a working set larger than the floor stays while it is used", g_ghost.n == N && list_ok());
        CHECK("nothing in use goes at a commit", commit_trim() == 0 && g_ghost.n == N);
        CHECK("nor at the eviction level", ghost_trim(0) == 0 && g_ghost.n == N);
        // Used again: passed over, and the least recently used goes first once idle
        frames(idle - 1);
        for (uint64_t i = 0; i < 100; i++) CHECK("a lookup finds it", tex_get(base + i) != nil);   // the oldest hundred used again
        frames(1);
        unsigned n = commit_trim();
        CHECK("idle entries go GHOST_TRIM a commit, the least recently used first", n == GHOST_TRIM && tex_get(base + 100) == nil && tex_get(base + 100 + GHOST_TRIM) != nil && list_ok());
        CHECK("an entry used again is passed over", tex_get(base) != nil);   // (this lookup is a use too)
        while (commit_trim()) {}
        CHECK("the table drains back to its floor", g_ghost.n == floor_ && list_ok());
        // Two a put: above the floor, with the floor's entries idle
        use_all();
        for (uint64_t i = 0; i < 10; i++) put_pkg(base + 40000 + i);   // the floor's entries are not idle: nothing goes
        CHECK("puts over a floor not idle keep everything", g_ghost.n == floor_ + 10);
        frames(idle);
        put_pkg(base + 50000); CHECK("a put lets two idle entries go", g_ghost.n == floor_ + 9 && list_ok());
        while (commit_trim()) {}
        // Idle by submissions with the frame standing still: every entry used now, 40 more put, then GHOST_IDLE_SUBS submissions on
        use_all();
        for (uint64_t i = 0; i < 40; i++) put_pkg(base + 60000 + i);
        CHECK("all in use: nothing goes at a commit", g_ghost.n == floor_ + 40 && commit_trim() == 0);
        uint64_t fence0 = g_fence; g_fence += GHOST_IDLE_SUBS;   // GHOST_IDLE_SUBS submissions later (put back after: mtl_drain waits for the real fence)
        CHECK("idle by submissions alone", commit_trim() == GHOST_TRIM && list_ok());
        g_fence = fence0;
        while (commit_trim()) {}
        // A texture the GPU wrote waits GHOST_IDLE_KEPT frames
        while (commit_trim()) {}
        for (uint64_t i = 0; i < 64; i++) tex_put(base + 70000 + i, tex());   // not packaged: a texture the GPU wrote
        frames(idle);
        ghost_trim(2);
        CHECK("under pressure idle packaged entries go down to 64, the GPU-written ones stay until GHOST_IDLE_KEPT", g_ghost.n == 64 && tex_get(base + 70000) != nil && list_ok());
        frames(GHOST_IDLE_KEPT);
        CHECK("then they go too", ghost_trim(1) == 0 || g_ghost.n <= 64);
        for (uint64_t i = 0; i < 200; i++) put_pkg(base + 80000 + i);
        frames(GHOST_IDLE_KEPT);
        n = ghost_trim(1);
        CHECK("the stop level: down to 64", g_ghost.n == 64 && n > 0 && list_ok());
        // A purge with a storage takeover (ghost_purge) takes the entries with their places in the list
        id<MTLTexture> shared = tex();
        for (uint64_t i = 0; i < 5; i++) tex_put(base + 90000 + i, shared);
        unsigned had = g_ghost.n;
        pthread_mutex_lock(&g_smu); void *objs[1] = {(__bridge void *)shared}; ghost_purge(objs, 1); pthread_mutex_unlock(&g_smu);
        CHECK("a purge takes the entries with their places", g_ghost.n == had - 5 && tex_get(base + 90000) == nil && list_ok());
    }
    mtl_drain(); defer_drain();
    CHECK("the pool index matches both tables", pool_ix_mismatches() == 0);
    printf("t_ghost_trim%s: %d checks, %d failed\n", floor_run ? " (floor)" : "", checks, failed);
    return failed != 0;
}}

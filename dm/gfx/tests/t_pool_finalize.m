// A memory pool's Finalize (nvn_mtl.m mtl_alias_drop_pool, upstream nxnative 13c35e90 adapted): it ends every texture made on the pool's storage, so the serial entries of the pool's
// live texture objects go, and so does every live or finalized (ghost) entry that names one of those textures, a packaged texture of the pool or one's texture, or a view of one.
// Entries of another pool stay, and the textures leave the residency set once the work encoded before is done
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
static int resident(id<MTLTexture> t) { pthread_mutex_lock(&g_res_mu); int r = [g_res_objects containsObject:t]; pthread_mutex_unlock(&g_res_mu); return r; }
static void settle(void) { mtl_sub_begin(); mtl_wait(mtl_sub_commit(), 5000000000ull); mtl_drain(); defer_drain(); res_commit(); }

int main(void) { @autoreleasepool {
    mtl_init();
    g_d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:16 height:16 mipmapped:NO]; g_d.storageMode = MTLStorageModePrivate;
    static pool_t pa, pb;   // two pools (only their addresses are read)
    tex_t a1 = {.serial = 9100001, .pool = &pa}, a2 = {.serial = 9100002, .pool = &pa}, b1 = {.serial = 9200001, .pool = &pb};
    mtl_tex_init(&a1); mtl_tex_init(&a2); mtl_tex_init(&b1);
    pthread_mutex_lock(&g_smu); uintptr_t ka = (uintptr_t)&pa; CFSetRef sa = nvn_hm_get(&g_pool_tex, &ka); int indexed = sa && CFSetGetCount(sa) == 2; pthread_mutex_unlock(&g_smu);
    CHECK("each pool indexes its live texture serials", indexed);
    // a1: a live object holding a texture of its own; a finalized serial replayed holds the same texture (a ghost entry)
    id<MTLTexture> ta = tex(); serial_put(a1.serial, ta); tex_put(9100100, ta);
    // a2: a packaged texture of the pool (shared by storage, g_pkg_share); a finalized serial holds the package's texture itself (the GPU took it over: cpu_unc_drop)
    NvPkg *pk = [NvPkg new]; pk->tex = tex(); id<MTLTexture> tpk = pk->tex; serial_put(a2.serial, pk); pkg_share_put(&a2, pk); tex_put(9100200, pk->tex);
    // b1: another pool's, and a finalized serial of it
    id<MTLTexture> tb = tex(); serial_put(b1.serial, tb); tex_put(9200100, tb);
    pk = nil;
    // An sRGB / linear view of the pool's texture under a finalized serial
    id<MTLTexture> view = [ta newTextureViewWithPixelFormat:MTLPixelFormatRGBA8Unorm_sRGB]; tex_put(9100300, view);
    mtl_alias_drop_pool(&pa);
    CHECK("the pool's live objects lose their entries", serial_get(a1.serial) == nil && serial_get(a2.serial) == nil);
    CHECK("finalized serials naming its textures wait for the next commit (one walk for every pool finalized before it)", tex_get(9100100) == ta);
    mtl_pool_gone_flush();   // as mtl_sub_commit does
    CHECK("finalized serials naming its textures, its package's texture or a view go too", tex_get(9100100) == nil && tex_get(9100200) == nil && tex_get(9100300) == nil);
    CHECK("another pool's entries stay", serial_get(b1.serial) == tb && tex_get(9200100) == tb);
    pthread_mutex_lock(&g_smu); indexed = nvn_hm_get(&g_pool_tex, &ka) == NULL && nvn_hm_get(&g_tex_pool, &a1.serial) == NULL; int live_kept = nvn_hm_get(&g_tex_live, &a1.serial) != NULL; pthread_mutex_unlock(&g_smu);
    CHECK("the pool leaves the index; its objects stay live until their own release", indexed && live_kept);
    CHECK("the entries that went are counted", g_pool_fin_entries == 5);
    view = nil;
    settle();
    CHECK("the pool's textures leave the residency set once the work before is done", !resident(ta) && !resident(tpk) && resident(tb));
    mtl_tex_release(&a1); mtl_tex_release(&a2);
    CHECK("the objects' own release later finds nothing to end", serial_get(a1.serial) == nil && tex_get(a1.serial) == nil);
    mtl_tex_release(&b1);
    pthread_mutex_lock(&g_smu); uintptr_t kb = (uintptr_t)&pb; int gone = nvn_hm_get(&g_pool_tex, &kb) == NULL && g_tex_pool.n == 0; pthread_mutex_unlock(&g_smu);
    CHECK("a texture's release takes it out of its pool's index", gone);
    settle();
    CHECK("the pool index matches both tables", pool_ix_mismatches() == 0);
    {   // The cost of the walk over the serial entries at a pool's finalize, at Ocarina of Time's size: about 5,000 entries, half of them texture views, 300 finalizes (an area
        // change). It asked every entry respondsToSelector:@selector(parentTexture) first: 0.6 s of the game's unload thread at the walk into Castle Town (2026-11-20)
        enum { NE = 5000, NF = 300 }; NSMutableArray *keep = [NSMutableArray array]; id<MTLTexture> base = tex();
        for (int i = 0; i < NE; i++) { id o = (i & 1) ? [base newTextureViewWithPixelFormat:MTLPixelFormatRGBA8Unorm] : tex(); [keep addObject:o]; serial_put((1ull << 61) + (uint64_t)i, o); }
        CFMutableSetRef g = CFSetCreateMutable(NULL, 0, NULL); id<MTLTexture> other = tex(); CFSetAddValue(g, (__bridge const void *)other);
        uint32_t hit = 0; uint64_t t0 = bp_now();
        pthread_mutex_lock(&g_smu); for (int k = 0; k < NF; k++) gone_pending_add_locked(g); hit = gone_flush_locked(); pthread_mutex_unlock(&g_smu);   // as NF finalizes and a commit
        double ms = (bp_now() - t0) / 1e6;
        uint64_t t1 = bp_now(); pthread_mutex_lock(&g_smu); for (int k = 0; k < NF; k++) (void)drop_entries_naming_locked(g); pthread_mutex_unlock(&g_smu);
        printf("%d finalizes over %d serial entries: %.2f ms with one walk at the commit, %.1f ms walking at each\n", NF, NE, ms, (bp_now() - t1) / 1e6);
        CHECK("an entry is dropped only when its texture or the texture it views went", hit == 0);
        CFSetAddValue(g, (__bridge const void *)base);
        pthread_mutex_lock(&g_smu); hit = drop_entries_naming_locked(g); pthread_mutex_unlock(&g_smu);
        CHECK("the views of a texture that went go with it", hit == NE / 2);
        CHECK("an area change's finalizes and the commit after them walk the entries once (under 5 ms)", ms < 5);
        CFRelease(g); for (int i = 0; i < NE; i++) serial_del((1ull << 61) + (uint64_t)i); settle();
    }
    CHECK("the pool address index stays in order", pidx_mismatches() == 0);
    printf("t_pool_finalize: %d checks, %d failed\n", checks, failed);
    return failed != 0;
}}

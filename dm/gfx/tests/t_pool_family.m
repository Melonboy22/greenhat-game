// Render targets of a GPU-only pool whose offsets have held more than one size (a resolution family; Ocarina of Time's render-target pools, which move their targets every frame):
// they go into the pool's own heap (pool_heap_texture), every size at an offset at the same place, one memory as on NVN, written uncompressed as a family's members are. Before
// (oot-plus until 2026-11-18) image_texture took them first and gave each offset a heap of its own beside the pool's heap: about 490 heaps, 0.4-2.5 GB, on a 16 GB M5 docked.
// A virtual pool (no pool heap) and DM_NVN_POOL_HEAP=0 keep the family heaps; a texture of no family keeps its compression. Modes: (none), "off" (DM_NVN_POOL_HEAP=0)
#include "../nvn/nvn_mtl.m"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(c, label) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)
static tex_t target(pool_t *pool, uint64_t serial, uint64_t off, unsigned w, unsigned h) {
    tex_t t = {.magic = MAGIC('T','E','X',0), .serial = serial, .pool = pool, .mem = pool->mem + off, .off = (int64_t)off};
    t.d = (nvn_texdesc){.target = NVN_TEXTURE_TARGET_2D, .format = NVN_FORMAT_RGBA16F, .flags = NVN_TEXTURE_FLAGS_COMPRESSIBLE, .width = w, .height = h, .depth = 1, .levels = 1, .samples = 1};
    nvn_tex_layout(&t.d, &t.L); return t;
}
static NvImageHeap *owner_of(id<MTLTexture> t) { return t ? objc_getAssociatedObject(t, &g_image_heap_owner_key) : nil; }

int main(int argc, char **argv) { @autoreleasepool {
    int off = argc > 1 && !strcmp(argv[1], "off");
    if (off) setenv("DM_NVN_POOL_HEAP", "0", 1);
    mtl_init(); mtl_sub_begin();
    enum { POOL = 256 << 20, SLOT = 16 << 20, N = 12 };
    void *mem = NULL; if (posix_memalign(&mem, 16384, POOL)) return 1; memset(mem, 0, POOL);
    pool_t pool = {.magic = MAGIC('P','O','O','L'), .flags = NVN_MEMORY_POOL_FLAGS_CPU_NO_ACCESS | NVN_MEMORY_POOL_FLAGS_GPU_CACHED | NVN_MEMORY_POOL_FLAGS_COMPRESSIBLE, .mem = mem, .size = POOL};
    // A target of no family first: the pool's heap (made for it), compressed as usual
    tex_t lone = target(&pool, 69000, (uint64_t)N * SLOT, 640, 360); mtl_tex_init(&lone);
    id<MTLTexture> tl = tex_mtl(&lone); NvImageHeap *hl = owner_of(tl);
    if (!off) CHECK(tl && hl && hl->pool_heap && tl.allowGPUOptimizedContents, "a target of no family goes into the pool's heap, compressed");
    unsigned heaps0 = g_image_heap_n; uint64_t fam0 = atomic_load(&g_family_heap_live);
    // Each offset: two texture objects of two sizes, initialized before either is made (one frame's layout, then another's)
    static tex_t a[N], b[N]; int in_pool = 0, in_family = 0, uncompressed = 0, same_place = 0;
    for (int i = 0; i < N; i++) {
        a[i] = target(&pool, 70000 + i, (uint64_t)i * SLOT, 1715, 965); b[i] = target(&pool, 71000 + i, (uint64_t)i * SLOT, 2560, 1440);
        mtl_tex_init(&a[i]); mtl_tex_init(&b[i]);
    }
    for (int i = 0; i < N; i++) {
        id<MTLTexture> ta = tex_mtl(&a[i]), tb = tex_mtl(&b[i]); NvImageHeap *ha = owner_of(ta), *hb = owner_of(tb);
        if (ha && ha->pool_heap) in_pool++; else if (ha) in_family++;
        uncompressed += ta && !ta.allowGPUOptimizedContents;
        same_place += ta && tb && ta.heap && ta.heap == tb.heap && ta.heapOffset == tb.heapOffset && ha == hb;
    }
    if (!off) {
        CHECK(in_pool == N && !in_family, "every family member goes into the pool's heap");
        CHECK(g_image_heap_n == heaps0 && atomic_load(&g_family_heap_live) == fam0, "no heap is made beside the pool's");
        CHECK(same_place == N, "both sizes at an offset lie at the same place in the pool's heap: one memory");
        CHECK(uncompressed == N, "a family's members are written uncompressed (DM_NVN_FAMILY_NOCOMPRESS)");
        CHECK(atomic_load(&g_pool_heap_live) >= (uint64_t)POOL, "the pool's heap is counted alive");
    } else {
        CHECK(!in_pool && in_family == N, "with the pool heaps off, families keep heaps of their own");
        CHECK(atomic_load(&g_family_heap_live) > fam0, "those heaps are counted alive as families'");
    }
    // A virtual pool has no pool heap: its families keep heaps of their own (Luigi's Mansion 3's resolution families)
    void *vmem = NULL; if (posix_memalign(&vmem, 16384, 64 << 20)) return 1; memset(vmem, 0, 64 << 20);
    pool_t vpool = {.magic = MAGIC('P','O','O','L'), .flags = NVN_MEMORY_POOL_FLAGS_VIRTUAL | NVN_MEMORY_POOL_FLAGS_GPU_CACHED | NVN_MEMORY_POOL_FLAGS_COMPRESSIBLE, .mem = vmem, .size = 64 << 20};
    tex_t va = target(&vpool, 72000, 0, 640, 360), vb = target(&vpool, 72001, 0, 1280, 720); mtl_tex_init(&va); mtl_tex_init(&vb);
    id<MTLTexture> tva = tex_mtl(&va), tvb = tex_mtl(&vb); NvImageHeap *hva = owner_of(tva);
    CHECK(tva && hva && !hva->pool_heap && tvb && tvb.heap == tva.heap, "a virtual pool's family shares a family heap, as before");
    mtl_sub_commit(); mtl_drain();
    printf("t_pool_family%s: %d checks, %d failed\n", off ? " (off)" : "", checks, failed);
    return failed != 0;
}}

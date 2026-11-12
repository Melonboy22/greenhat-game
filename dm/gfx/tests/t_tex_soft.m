// tex_soft (nvn_mtl.m): a large block-compressed packaged texture is made without its finest level, its host level n holding the game's level n + 1; textures too small, of
// another format or (with tex_soft_arrays off) 2D arrays stay whole; levels the game names move down one only on a texture made soft (tex_soft_level_mt); and soft_harden makes
// the texture whole again with every level. The switches are set here, whatever the profile says
#include "../nvn/nvn_mtl.m"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(label, c) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)
static void finish(void) { CHECK("submission completes", mtl_wait(mtl_sub_commit(), 5000000000ull)); CHECK("GPU has no submission error", !mtl_last_commit_error()); }

enum { W = 512, H = 512, LEVELS = 4 };
static size_t bc1_pitch(unsigned w) { return (size_t)((w + 3) / 4) * 8; }
static size_t bc1_rows(unsigned h) { return (h + 3) / 4; }

// Every host level of image, read back, against the game's levels from first_game_level on
static int levels_match(id<MTLTexture> image, const uint8_t *const *expected, unsigned first_game_level) {
    int ok = 1;
    for (unsigned l = 0; l < image.mipmapLevelCount; l++) {
        unsigned gl = l + first_game_level, w = MAX((unsigned)W >> gl, 1u), h = MAX((unsigned)H >> gl, 1u);
        size_t pitch = bc1_pitch(w), n = pitch * bc1_rows(h);
        id<MTLBuffer> rb = [g_dev newBufferWithLength:n options:MTLResourceStorageModeShared]; memset(rb.contents, 0xcd, n);
        id<MTLCommandBuffer> cb = q_cb(); id<MTLBlitCommandEncoder> ce = [cb blitCommandEncoder];
        [ce copyFromTexture:image sourceSlice:0 sourceLevel:l sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(w, h, 1) toBuffer:rb destinationOffset:0 destinationBytesPerRow:pitch destinationBytesPerImage:n];
        [ce endEncoding]; [cb commit]; [cb waitUntilCompleted];
        if (cb.status != MTLCommandBufferStatusCompleted || memcmp(rb.contents, expected[gl], n)) ok = 0;
    }
    return ok;
}

int main(void) { @autoreleasepool {
    setenv("DM_NVN_TEX_SOFT", "1", 1); setenv("DM_NVN_TEX_SOFT_ARRAYS", "0", 1); setenv("DM_NVN_TEX_SOFT_LEVELS", "1", 1);
    mtl_init();

    // A 512x512 RGBA_DXT1 (BC1) texture of 4 levels from the game's files (a packaged layout), in a CPU-visible pool
    tex_t t = {.magic = MAGIC('T', 'E', 'X', 0), .has_layout = 1, .serial = 99700};
    t.d = (nvn_texdesc){.target = 1, .format = NVN_FORMAT_RGBA_DXT1, .width = W, .height = H, .depth = 1, .levels = LEVELS, .samples = 1}; nvn_tex_layout(&t.d, &t.L);
    size_t poolsize = (t.L.size + getpagesize() - 1) & ~(size_t)(getpagesize() - 1); void *mem = NULL; if (posix_memalign(&mem, getpagesize(), poolsize)) abort(); memset(mem, 0, poolsize);
    pool_t pool = {.magic = MAGIC('P', 'O', 'O', 'L'), .mem = mem, .size = poolsize, .flags = NVN_MEMORY_POOL_FLAGS_CPU_UNCACHED | NVN_MEMORY_POOL_FLAGS_GPU_CACHED}; t.pool = &pool; t.mem = mem;
    mtl_pool_add(mem, poolsize); nvn_dirty_add_range(mem, poolsize);
    uint8_t *expected[LEVELS];
    dm_guest_write_prepare(mem, poolsize);
    for (unsigned l = 0; l < LEVELS; l++) {
        unsigned w = MAX((unsigned)W >> l, 1u), h = MAX((unsigned)H >> l, 1u); size_t pitch = bc1_pitch(w), n = pitch * bc1_rows(h);
        expected[l] = malloc(n); for (size_t i = 0; i < n; i++) expected[l][i] = (uint8_t)(i * 131u + l * 7919u + (i >> 9));
        CHECK("reference swizzle succeeds", !nvn_swizzle(&t.d, l, 0, expected[l], pitch, t.mem));
    }

    CHECK("a large BC1 texture from the game's files is soft", tex_soft(&t) && tex_soft_n(&t) == 1);
    tex_t small = t; small.d.width = 256; small.d.height = 128; CHECK("one under 512 on its long side stays whole", !tex_soft(&small));
    tex_t rgba = t; rgba.d.format = NVN_FORMAT_RGBA8; CHECK("an uncompressed one stays whole", !tex_soft(&rgba));
    tex_t arr = t; arr.d.target = 4; CHECK("a 2D array stays whole with tex_soft_arrays off", !tex_soft(&arr));
    tex_t fill = t; fill.has_layout = 0; CHECK("one with no packaged layout stays whole", !tex_soft(&fill));
    tex_t rt = t; rt.d.flags = NVN_TEXTURE_FLAGS_COMPRESSIBLE; CHECK("a compressible one (a render target's storage) stays whole", !tex_soft(&rt));
    tex_t img = t; img.d.flags = NVN_TEXTURE_FLAGS_IMAGE; CHECK("an image (compute stores) stays whole", !tex_soft(&img));

    mtl_sub_begin(); id<MTLTexture> image = tex_mtl(&t); finish();
    CHECK("the soft texture resolves", image != nil);
    CHECK("its host texture is the game's level 1: half the size, one level less", image.width == W / 2 && image.height == H / 2 && image.mipmapLevelCount == LEVELS - 1);
    CHECK("its host levels hold the game's levels 1 to 3", image && levels_match(image, (const uint8_t *const *)expected, 1));

    unsigned lv = 0; CHECK("the game's level 0 has no host level", !tex_soft_level_mt(&t, image, &lv));
    lv = 2; CHECK("the game's level 2 is host level 1", tex_soft_level_mt(&t, image, &lv) && lv == 1);
    MTLTextureDescriptor *fd = tex_desc(&t, 0); id<MTLTexture> full = [g_dev newTextureWithDescriptor:fd];
    lv = 2; CHECK("a host texture of every level (not made soft) keeps the game's level numbers", full && tex_soft_level_mt(&t, full, &lv) && lv == 2);
    CHECK("the storage of a soft texture is not written back from its host levels", !tex_storage_dst(&t));

    // The game copies from it: soft_harden makes it whole, from its storage, which still holds the finest level
    mtl_sub_begin(); soft_harden(&t); id<MTLTexture> whole = tex_mtl(&t); finish();
    CHECK("after soft_harden the texture is not soft", !tex_soft(&t) && tex_soft_n(&t) == 0);
    CHECK("its host texture has every level at full size", whole && whole != image && whole.width == W && whole.height == H && whole.mipmapLevelCount == LEVELS);
    CHECK("its host levels hold the game's levels 0 to 3", whole && levels_match(whole, (const uint8_t *const *)expected, 0));
    lv = 2; CHECK("level numbers are the game's again", tex_soft_level_mt(&t, whole, &lv) && lv == 2);

    // The game copies into a soft texture (a texture streamed in by buffer→texture copies): copy_b2t makes it whole first, and the copy lands in its level 0. Before, a copy into
    // level 0 was skipped and the texture kept what it had (Kakariko's ground showed another material)
    void *mem2 = NULL; if (posix_memalign(&mem2, getpagesize(), poolsize)) abort(); memset(mem2, 0, poolsize);
    pool_t pool2 = {.magic = MAGIC('P', 'O', 'O', 'L'), .mem = mem2, .size = poolsize, .flags = NVN_MEMORY_POOL_FLAGS_CPU_UNCACHED | NVN_MEMORY_POOL_FLAGS_GPU_CACHED};
    mtl_pool_add(mem2, poolsize); nvn_dirty_add_range(mem2, poolsize);
    tex_t s = t; s.serial = 99701; s.pool = &pool2; s.mem = mem2;
    dm_guest_write_prepare(mem2, poolsize);
    for (unsigned l = 0; l < LEVELS; l++) { unsigned w = MAX((unsigned)W >> l, 1u); CHECK("reference swizzle succeeds (second texture)", !nvn_swizzle(&s.d, l, 0, expected[l], bc1_pitch(w), s.mem)); }
    CHECK("the second texture is soft before the copy", tex_soft(&s));
    mtl_sub_begin(); id<MTLTexture> before = tex_mtl(&s); finish();
    CHECK("its host texture is half size before the copy", before && before.width == W / 2);
    size_t n0 = bc1_pitch(W) * bc1_rows(H); void *src = NULL; if (posix_memalign(&src, getpagesize(), (n0 + getpagesize() - 1) & ~(size_t)(getpagesize() - 1))) abort();
    uint8_t *streamed = src; for (size_t i = 0; i < n0; i++) streamed[i] = (uint8_t)(i * 7u + 13u);   // what the game streams into level 0, unlike what the storage held
    mtl_pool_add(src, (n0 + getpagesize() - 1) & ~(size_t)(getpagesize() - 1));
    p_copy_b2t c = {.src = (uint64_t)(uintptr_t)src, .tex = &s, .r = {0, 0, 0, W, H, 1}};
    mtl_sub_begin(); copy_b2t(&c, 0); finish();
    id<MTLTexture> after = tex_mtl(&s);
    CHECK("a copy into level 0 makes the texture whole", !tex_soft(&s) && after && after.width == W && after.mipmapLevelCount == LEVELS);
    const uint8_t *exp2[LEVELS] = {streamed, expected[1], expected[2], expected[3]};
    CHECK("level 0 holds the copied bytes, the other levels the storage's", after && levels_match(after, exp2, 0));
    mtl_tex_release(&s); mtl_drain(); mtl_alias_drop_pool(&pool2); nvn_dirty_remove_range(mem2); mtl_pool_del(mem2); mtl_pool_del(src); mtl_drain(); free(mem2); free(src);

    mtl_tex_release(&t); mtl_drain(); mtl_alias_drop_pool(&pool); nvn_dirty_remove_range(mem); mtl_pool_del(mem); mtl_drain(); free(mem);
    for (unsigned l = 0; l < LEVELS; l++) free(expected[l]);
    printf("t_tex_soft: %d checks, %d failed\n", checks, failed);
    return failed != 0;
}}

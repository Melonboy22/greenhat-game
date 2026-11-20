// Shared heaps for the game's textures (nvn_mtl.m slab_texture): the textures an area change loads go into a few heaps, so a residency commit adds a few allocations instead of one
// per texture (oot-plus b985672b: 500-1,900 allocations, 71-410 ms of commits in one frame). Small textures share heaps, large ones stay on their own, every texture is usable,
// the residency set grows by the heaps alone, a heap leaves it once its last texture is freed, and DM_NVN_TEX_SLAB=0 is left to the switch reader
#include "../nvn/nvn_mtl.m"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(label, c) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)
static MTLTextureDescriptor *desc(MTLPixelFormat pf, NSUInteger w, NSUInteger h, int mips) {
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pf width:w height:h mipmapped:mips ? YES : NO];
    d.storageMode = MTLStorageModePrivate; d.usage = MTLTextureUsageShaderRead; return d;
}
static NSUInteger res_count(void) { pthread_mutex_lock(&g_res_mu); NSUInteger n = g_res_objects.count; pthread_mutex_unlock(&g_res_mu); return n; }
int main(void) { @autoreleasepool {
    mtl_init();
    enum { N = 600 };
    NSUInteger before = res_count();
    NSMutableArray<id<MTLTexture>> *small = [NSMutableArray array];
    NSMutableSet *heaps = [NSMutableSet set];
    @autoreleasepool {
        for (int i = 0; i < N; i++) {   // the mix of an area change: 64-512 px, compressed and plain, with levels
            NSUInteger w = 64u << (i % 4);
            id<MTLTexture> t = slab_texture(desc(i % 3 ? MTLPixelFormatBC1_RGBA : MTLPixelFormatRGBA8Unorm, w, w, i % 2));
            if (!t) break;
            res_add(t); [small addObject:t]; if (t.heap) [heaps addObject:t.heap];
        }
        res_commit();
    }
    CHECK("every small texture is made", small.count == N);
    CHECK("every small texture is placed in a shared heap", atomic_load(&g_slab_tex) == N && atomic_load(&g_slab_solo) == 0);
    CHECK("600 small textures share a few heaps", heaps.count >= 1 && heaps.count <= 8);
    CHECK("the residency set grows by the heaps alone", res_count() - before == heaps.count);
    // a large texture (over SLAB_TEX_MAX) is one of its own
    id<MTLTexture> big = slab_texture(desc(MTLPixelFormatRGBA8Unorm, 4096, 4096, 0));
    CHECK("a 64 MB texture is made on its own", big && !big.heap && atomic_load(&g_slab_solo) == 1);
    big = nil;
    // usable: a copy into a placed texture and back reads the bytes
    {
        id<MTLTexture> t = small[5]; uint32_t w = (uint32_t)t.width;
        id<MTLBuffer> src = [g_dev newBufferWithLength:(NSUInteger)w * w * 4 options:MTLResourceStorageModeShared], dst = [g_dev newBufferWithLength:(NSUInteger)w * w * 4 options:MTLResourceStorageModeShared];
        id<MTLTexture> plain = t.pixelFormat == MTLPixelFormatRGBA8Unorm ? t : nil;
        for (NSUInteger i = 0; !plain && i < small.count; i++) if (small[i].pixelFormat == MTLPixelFormatRGBA8Unorm) plain = small[i];
        w = (uint32_t)plain.width; src = [g_dev newBufferWithLength:(NSUInteger)w * w * 4 options:MTLResourceStorageModeShared]; dst = [g_dev newBufferWithLength:(NSUInteger)w * w * 4 options:MTLResourceStorageModeShared];
        for (uint32_t i = 0; i < w * w; i++) ((uint32_t *)src.contents)[i] = 0x01020304u + i;
        id<MTLCommandQueue> q = [g_dev newCommandQueue]; id<MTLCommandBuffer> cb = [q commandBuffer]; id<MTLBlitCommandEncoder> b = [cb blitCommandEncoder];
        [b copyFromBuffer:src sourceOffset:0 sourceBytesPerRow:w * 4 sourceBytesPerImage:w * w * 4 sourceSize:MTLSizeMake(w, w, 1) toTexture:plain destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0, 0, 0)];
        [b copyFromTexture:plain sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(w, w, 1) toBuffer:dst destinationOffset:0 destinationBytesPerRow:w * 4 destinationBytesPerImage:w * w * 4];
        [b endEncoding]; [cb commit]; [cb waitUntilCompleted];
        CHECK("a placed texture holds what is copied into it", plain && cb.status == MTLCommandBufferStatusCompleted && !memcmp(src.contents, dst.contents, (size_t)w * w * 4));
    }
    // freeing: the heaps leave the residency set once their textures are gone (the newest one is kept)
    uint64_t live = atomic_load(&g_slab_live);
    [small removeAllObjects]; heaps = nil;
    @autoreleasepool { res_commit(); }
    CHECK("the older heaps are freed with their textures, the newest kept", atomic_load(&g_slab_live) == 1 && live >= 1);
    CHECK("the residency set holds only the newest heap", res_count() - before == 1);
    // space comes back: a new round of textures reuses the kept heap before making one
    uint64_t made = atomic_load(&g_slab_made);
    @autoreleasepool { id<MTLTexture> t = slab_texture(desc(MTLPixelFormatRGBA8Unorm, 256, 256, 1)); CHECK("a new texture after the frees goes into the kept heap", t && t.heap && atomic_load(&g_slab_made) == made); }
    printf("t_tex_slab: %d checks, %d failed\n", checks, failed);
    return failed ? 1 : 0;
} }

// gmem_nobig and gmem_skip (nvn_mtl.m mtl_pool_noraw): the raw global memory table does not wire a large pool whole, only the chunks lookups made resident; a compressible pool stays
// out of the table (not resident) until a binding makes it resident, which has the table built again. The switches are set here, whatever the profile says
#include "../nvn/nvn_mtl.m"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(label, c) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)
static uint64_t res_shared_bytes(void) { uint64_t n = 0; pthread_mutex_lock(&g_mu); for (int i = 0; i < g_npool; i++) if (g_pools[i].res) n += g_pools[i].buf.length; pthread_mutex_unlock(&g_mu); return n; }

int main(void) { @autoreleasepool {
    setenv("DM_NVN_GMEM_NOBIG", "1", 1); setenv("DM_NVN_GMEM_SKIP", "1", 1);
    mtl_init();
    const uint64_t GB = 1ull << 30, MB = 1ull << 20;
    // A large pool (BIG_MIN and more) with an address given out in it
    uint8_t *mem = mmap(NULL, GB, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0); if (mem == MAP_FAILED) abort();
    uint64_t base = (uint64_t)(uintptr_t)mem;
    mtl_pool_add(mem, GB); mtl_pool_noraw(mem, GB, 0);
    CHECK("the large pool is marked", g_nbig == 1 && g_big[0].noraw);
    void *mb = NULL; uint64_t mo = 0, gpu = 0;
    CHECK("a binding's lookup finds its chunk", mtl_gpu_addr(base + 100 * MB, 4096, &mb, &mo, &gpu));
    mtl_pool_addressed((void *)(uintptr_t)(base + 900 * MB), 4096);
    (void)gmem_map();
    CHECK("the table gives the large pool no whole-pool entry", g_big[0].full == 0);
    CHECK("only the chunk the lookup made is resident: far less than the pool", res_shared_bytes() > 0 && res_shared_bytes() <= 4 * BIG_S);
    // A compressible pool (render-target storage) with an address given out
    uint8_t *rt = mmap(NULL, 64 * MB, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0); if (rt == MAP_FAILED) abort();
    int p0 = g_npool; mtl_pool_add(rt, 64 * MB); mtl_pool_noraw(rt, 64 * MB, NVN_MEMORY_POOL_FLAGS_COMPRESSIBLE | NVN_MEMORY_POOL_FLAGS_CPU_NO_ACCESS);
    CHECK("the compressible pool is one entry, marked", g_npool == p0 + 1 && g_pools[p0].noraw);
    mtl_pool_addressed(rt, 4096);
    uint64_t before = res_shared_bytes(); (void)gmem_map();
    CHECK("the table leaves it out: not resident", !g_pools[p0].res && res_shared_bytes() == before);
    // A plain pool with an address given out is listed and resident, as before
    uint8_t *pl = mmap(NULL, 16 * MB, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0); if (pl == MAP_FAILED) abort();
    int p1 = g_npool; mtl_pool_add(pl, 16 * MB); mtl_pool_noraw(pl, 16 * MB, NVN_MEMORY_POOL_FLAGS_CPU_CACHED | NVN_MEMORY_POOL_FLAGS_GPU_CACHED);
    mtl_pool_addressed(pl, 4096); (void)gmem_map();
    CHECK("a plain pool is listed and resident as before", !g_pools[p1].noraw && g_pools[p1].res);
    // A binding reaches the compressible pool: resident, and the table is built again with it
    uint64_t gen = atomic_load(&g_pool_gen);
    CHECK("a binding's lookup in the compressible pool", mtl_gpu_addr((uint64_t)(uintptr_t)rt + 4096, 4096, &mb, &mo, &gpu));
    CHECK("it is resident now, and the table's generation moved", g_pools[p0].res && atomic_load(&g_pool_gen) != gen);
    id<MTLBuffer> t1 = gmem_map(), t2 = gmem_map();
    CHECK("the table is built again once, then kept", t1 != nil && t1 == t2);
    printf("t_gmem_noraw: %d checks, %d failed\n", checks, failed);
    return failed != 0;
}}

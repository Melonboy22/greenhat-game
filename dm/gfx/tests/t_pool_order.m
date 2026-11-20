// The memory pools' address index (nvn_mtl.m g_pidx): kept in order as pools come and go (pidx_insert, pidx_replace_with_last), instead of a full sort at the next lookup after
// each change. Hundreds of pools added and finalized in a shuffled order, with lookups between the changes, as an area change in Ocarina of Time does: every lookup finds the pool
// that holds its address, the index stays a permutation in order of start address, and no change after the first sort sorts again
#include "../nvn/nvn_mtl.m"
#include "t_pool_ix_check.h"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(label, c) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)
enum { N = 400, PG = 1 << 16 };
static uint8_t *g_mem;
static int pool_at(int i) {   // pool_find of an address inside pool i, as its index or -1
    pthread_mutex_lock(&g_mu); int q = pool_find((uint64_t)(uintptr_t)(g_mem + (size_t)i * PG + 100), 16); pthread_mutex_unlock(&g_mu); return q;
}
static int holds(int q, int i) { pthread_mutex_lock(&g_mu); int r = q >= 0 && g_pools[q].key == g_mem + (size_t)i * PG; pthread_mutex_unlock(&g_mu); return r; }
int main(void) { @autoreleasepool {
    mtl_init();
    if (posix_memalign((void **)&g_mem, (size_t)getpagesize(), (size_t)N * PG)) return 2;
    memset(g_mem, 0, (size_t)N * PG);
    int order[N], live[N] = {0}; for (int i = 0; i < N; i++) order[i] = i;
    srand(7); for (int i = N - 1; i > 0; i--) { int j = rand() % (i + 1), t = order[i]; order[i] = order[j]; order[j] = t; }
    for (int k = 0; k < N; k++) { mtl_pool_add(g_mem + (size_t)order[k] * PG, PG); live[order[k]] = 1; if (k == 0) (void)pool_at(order[0]); }
    int wrong = 0; for (int i = 0; i < N; i++) wrong += !holds(pool_at(i), i);
    CHECK("every pool added in a shuffled order is found by an address inside it", wrong == 0);
    CHECK("the index is a permutation in order of start address", pidx_mismatches() == 0);
    CHECK("and stayed valid through the adds (no sort after the first)", g_pidx_ok);
    // finalize half of them in another shuffled order, a lookup after each, and add some back
    srand(11); for (int i = N - 1; i > 0; i--) { int j = rand() % (i + 1), t = order[i]; order[i] = order[j]; order[j] = t; }
    int gone_wrong = 0, keep_wrong = 0;
    for (int k = 0; k < N / 2; k++) {
        int i = order[k]; mtl_pool_del(g_mem + (size_t)i * PG); live[i] = 0;
        gone_wrong += pool_at(i) >= 0;
        int other = order[N - 1 - k]; keep_wrong += !holds(pool_at(other), other);
        if (k % 10 == 0) { mtl_pool_add(g_mem + (size_t)i * PG, PG); live[i] = 1; keep_wrong += !holds(pool_at(i), i); }
    }
    CHECK("a finalized pool is not found", gone_wrong == 0);
    CHECK("the pools still there are found after each change", keep_wrong == 0);
    CHECK("the index is still a permutation in order after the changes", pidx_mismatches() == 0 && g_pidx_ok);
    int all = 0; for (int i = 0; i < N; i++) all += live[i] ? !holds(pool_at(i), i) : pool_at(i) >= 0;
    CHECK("at the end every live pool is found and every finalized one is not", all == 0);
    for (int i = 0; i < N; i++) if (live[i]) mtl_pool_del(g_mem + (size_t)i * PG);
    CHECK("no pool is left in the index", pidx_mismatches() == 0);
    printf("t_pool_order: %d checks, %d failed\n", checks, failed);
    return failed != 0;
} }

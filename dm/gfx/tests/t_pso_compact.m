// Which run files of the pipeline archive a start's compaction takes (nvn_mtl.m arch_compact_pick). A compaction keeps only the bases the prewarm takes from the files it replaces,
// so it lost the bases play had compiled: Ocarina of Time docked compiled 1,681 in a session and the next start kept 407 of them. A file with a complete index costs a lookup
// nothing, so by default only files without one are compacted; DM_PSO_COMPACT=1 takes every run file, as before; DM_PSO_COMPACT=0 none. Modes: (none), "all", "never"
#include "../nvn/nvn_mtl.m"
void *front_metal_layer(void) { return NULL; }
module_t *module_of(const void *p) { (void)p; return NULL; }
module_t *g_mod; int g_nmod;
void svc_thread_dump(void) {}
uint64_t now_ns(void) { return bp_now(); }
static int checks, failed;
#define CHECK(c, label) do { checks++; if (!(c)) { failed++; fprintf(stderr, "FAIL: %s (line %d)\n", label, __LINE__); } } while (0)
static void reset(void) { free(g_compact_state); g_compact_state = NULL; g_compact_files = nil; g_compact_enabled = 0; }
static unsigned picked(NSUInteger n) { unsigned k = 0; for (NSUInteger i = 0; g_compact_state && i < n; i++) k += g_compact_state[i]; return k; }

int main(int argc, char **argv) { @autoreleasepool {
    const char *mode = argc > 1 ? argv[1] : "";
    if (!strcmp(mode, "all")) setenv("DM_PSO_COMPACT", "1", 1);
    if (!strcmp(mode, "never")) setenv("DM_PSO_COMPACT", "0", 1);
    char tmpl[] = "/tmp/t_pso_compact.XXXXXX"; const char *dir = mkdtemp(tmpl); if (!dir) return 1;
    g_arch_dir = @(dir);   // where arch_compact_allowed looks for the marker of a compaction that did not finish (none here)
    enum { N = 20 };   // 20 small run files (tier 0: under PSO_ARCH_COMPACT pipelines each), more than PSO_ARCH_COMPACT of them
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (int i = 0; i < N; i++) [paths addObject:[g_arch_dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%05d-5.mtl4a", i]]];
    unsigned char all_indexed[N + 1], half[N + 1], none_indexed[N + 1];
    for (int i = 0; i < N; i++) { all_indexed[i] = 1; half[i] = i < 10; none_indexed[i] = 0; }   // half: the first ten have a complete index, the last ten none

    arch_compact_pick(paths, all_indexed);
    if (!strcmp(mode, "all")) CHECK(g_compact_enabled && picked(N) == N, "DM_PSO_COMPACT=1: every run file is compacted, indexed or not, as before");
    else CHECK(!g_compact_enabled && !picked(N), "files with a complete index are never compacted (nor with DM_PSO_COMPACT=0)");
    reset();

    arch_compact_pick(paths, half);
    if (!strcmp(mode, "never")) CHECK(!g_compact_enabled && !picked(N), "DM_PSO_COMPACT=0: no compaction");
    else if (!strcmp(mode, "all")) CHECK(g_compact_enabled && picked(N) == N, "DM_PSO_COMPACT=1: all twenty");
    else {
        CHECK(g_compact_enabled && picked(N) == 10, "the ten files without an index, more than PSO_ARCH_COMPACT, are compacted");
        int indexed_kept = 1; for (int i = 0; i < 10; i++) indexed_kept &= !g_compact_state[i];
        CHECK(indexed_kept, "the ten with a complete index are left as they are: the bases play compiled stay");
    }
    reset();

    unsigned char few[N + 1]; for (int i = 0; i < N; i++) few[i] = i >= PSO_ARCH_COMPACT;   // only PSO_ARCH_COMPACT files without an index: no tier is over the count
    arch_compact_pick(paths, few);
    if (!strcmp(mode, "all")) CHECK(g_compact_enabled, "DM_PSO_COMPACT=1 counts every file");
    else CHECK(!g_compact_enabled, "PSO_ARCH_COMPACT files without an index or fewer: no compaction");
    reset();

    arch_compact_pick(paths, none_indexed);
    if (!strcmp(mode, "never")) CHECK(!g_compact_enabled, "DM_PSO_COMPACT=0: none, whatever the files");
    else CHECK(g_compact_enabled && picked(N) == N, "files without an index are compacted as before");
    reset();

    arch_compact_pick(paths, NULL);   // no index information at all (no memory for it): every file counts, as before
    if (!strcmp(mode, "never")) CHECK(!g_compact_enabled, "DM_PSO_COMPACT=0 with no index information: none");
    else CHECK(g_compact_enabled && picked(N) == N, "no index information: every run file counts, as before");
    reset();

    rmdir(dir);
    printf("t_pso_compact%s%s: %d checks, %d failed\n", *mode ? " " : "", mode, checks, failed);
    return failed != 0;
}}

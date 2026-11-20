// Included after nvn_mtl.m by tests of the sharing table (g_alias), the image descriptions (g_image_desc) and the packaged textures by storage (g_pkg_share): the per-pool index (pool_ix) holds exactly the keys and serials a
// full walk of both tables finds, each under its own pool, and no empty list stays behind. Returns the number of mismatches (0 = consistent)
static int pool_ix_mismatches(void) {
    int bad = 0; uint32_t nak = 0, nser = 0;
    pthread_mutex_lock(&g_smu);
    for (uint32_t i = 0; i < g_alias.cap; i++) if (g_alias.vals[i]) {
        alias_key k; memcpy(&k, g_alias.keys + (size_t)i * g_alias.klen, sizeof k); nak++;
        const pool_ix *x = pix_get(k.pool, 0); int found = 0;
        for (uint32_t j = 0; x && j < x->nak && !found; j++) found = !memcmp(&x->ak[j], &k, sizeof k);
        bad += !found;
    }
    for (uint32_t i = 0; i < g_image_desc.cap; i++) if (g_image_desc.vals[i]) {
        uint64_t s; memcpy(&s, g_image_desc.keys + (size_t)i * 8, 8); nser++;
        const pool_ix *x = pix_get((uint64_t)(uintptr_t)((const tex_t *)g_image_desc.vals[i])->pool, 0); int found = 0;
        for (uint32_t j = 0; x && j < x->nser && !found; j++) found = x->ser[j] == s;
        bad += !found;
    }
    uint32_t npk = 0;
    for (uint32_t i = 0; i < g_pkg_share.cap; i++) if (g_pkg_share.vals[i]) {
        alias_key k; memcpy(&k, g_pkg_share.keys + (size_t)i * g_pkg_share.klen, sizeof k); npk++;
        const pool_ix *x = pix_get(k.pool, 0); int found = 0;
        for (uint32_t j = 0; x && j < x->npk && !found; j++) found = !memcmp(&x->pk[j], &k, sizeof k);
        bad += !found;
    }
    uint32_t iak = 0, iser = 0, ipk = 0;
    for (uint32_t i = 0; i < g_pool_ix.cap; i++) if (g_pool_ix.vals[i]) {
        const pool_ix *x = g_pool_ix.vals[i]; iak += x->nak; iser += x->nser; ipk += x->npk; bad += !x->nak && !x->nser && !x->npk;
    }
    bad += iak != nak; bad += iser != nser; bad += ipk != npk;
    pthread_mutex_unlock(&g_smu);
    return bad;
}
// The address index of the memory pools (g_pidx) when valid: every pool once, in order of start address. Returns the number of faults (0 = consistent). Caller does not hold g_mu
static int pidx_mismatches(void) {
    int bad = 0; pthread_mutex_lock(&g_mu);
    if (g_pidx_ok) {
        char *seen = calloc((size_t)g_npool + 1, 1);
        for (int k = 0; k < g_npool; k++) { int v = g_pidx[k]; if (v < 0 || v >= g_npool || seen[v]) bad++; else seen[v] = 1;
            if (k && v >= 0 && v < g_npool && g_pidx[k - 1] >= 0 && g_pidx[k - 1] < g_npool && g_pools[g_pidx[k - 1]].lo > g_pools[v].lo) bad++; }
        free(seen);
    }
    pthread_mutex_unlock(&g_mu); return bad;
}

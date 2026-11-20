// Included after nvn_mtl.m by tests of the sharing table (g_alias) and the image descriptions (g_image_desc): the per-pool index (pool_ix) holds exactly the keys and serials a
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
    uint32_t iak = 0, iser = 0;
    for (uint32_t i = 0; i < g_pool_ix.cap; i++) if (g_pool_ix.vals[i]) {
        const pool_ix *x = g_pool_ix.vals[i]; iak += x->nak; iser += x->nser; bad += !x->nak && !x->nser;
    }
    bad += iak != nak; bad += iser != nser;
    pthread_mutex_unlock(&g_smu);
    return bad;
}

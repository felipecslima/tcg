/** Similaridade de strings pra desempate por nome (só útil em cartas inglesas). */
/** Distância de Levenshtein (iterativa, O(n*m)). */
export function levenshtein(a, b) {
    if (a === b)
        return 0;
    if (!a.length)
        return b.length;
    if (!b.length)
        return a.length;
    let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
    let cur = new Array(b.length + 1);
    for (let i = 1; i <= a.length; i++) {
        cur[0] = i;
        for (let j = 1; j <= b.length; j++) {
            const cost = a[i - 1] === b[j - 1] ? 0 : 1;
            cur[j] = Math.min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost);
        }
        [prev, cur] = [cur, prev];
    }
    return prev[b.length];
}
/** Razão de similaridade 0..1 (1 = idêntico) a partir da distância. */
export function similarityRatio(a, b) {
    const maxLen = Math.max(a.length, b.length);
    if (maxLen === 0)
        return 1;
    return 1 - levenshtein(a, b) / maxLen;
}

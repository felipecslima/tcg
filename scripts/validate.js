/**
 * Harness de validação do motor de matching contra dados REAIS da
 * pokemontcg.io. Prova as teses do MVP núcleo:
 *   - número+set identifica a carta (idioma-agnóstico)
 *   - cartas PT (nome ilegível/divergente) ainda casam pelo número
 *   - ruído de OCR no número é tolerado
 *   - lixo cai na pilha de pendências em vez de travar o fluxo
 *
 * Rodar:  npm run validate
 */
import { fetchSetCards, SetIndex } from '../src/matching/index.js';
const SET = 'base1'; // Base Set (clássico, estável, bom pra provar o conceito)
async function main() {
    console.log(`Buscando cartas do set "${SET}"...`);
    const cards = await fetchSetCards(SET);
    const index = SetIndex.from(cards);
    console.log(`Índice montado: ${index.size} cartas.\n`);
    const cases = [
        {
            title: 'EN perfeito (número + nome)',
            input: { setId: SET, number: '4', name: 'Charizard' },
            expectStatus: 'matched',
            expectId: 'base1-4',
        },
        {
            title: 'PT — só o número legível (nome ausente)',
            input: { setId: SET, number: '4' },
            expectStatus: 'matched',
            expectId: 'base1-4',
        },
        {
            title: 'PT — número + nome em português divergente do inglês',
            input: { setId: SET, number: '15', name: 'Cascudo' /* nome fictício não-inglês */ },
            expectStatus: 'matched', // número manda; nome diverge mas não derruba
        },
        {
            title: 'OCR ruído no número ("O04" -> 4)',
            input: { setId: SET, number: 'O04', name: 'Charizard' },
            expectStatus: 'matched',
            expectId: 'base1-4',
        },
        {
            title: 'Número com denominador impresso ("4/102")',
            input: { setId: SET, number: '4/102' },
            expectStatus: 'matched',
            expectId: 'base1-4',
        },
        {
            title: 'Sem número — fuzzy só por nome (EN, com typo de OCR)',
            input: { setId: SET, name: 'Charizrd' },
            expectStatus: 'matched',
            expectId: 'base1-4',
        },
        {
            title: 'Número inexistente no set + sem nome -> pendência',
            input: { setId: SET, number: '999' },
            expectStatus: 'unmatched',
        },
        {
            title: 'Lixo total -> pendência',
            input: { setId: SET, name: 'zzzzzzz', number: '' },
            expectStatus: 'unmatched',
        },
    ];
    let pass = 0;
    for (const c of cases) {
        const r = index.match(c.input);
        const statusOk = r.status === c.expectStatus;
        const idOk = !c.expectId || r.card?.id === c.expectId;
        const ok = statusOk && idOk;
        if (ok)
            pass++;
        const badge = ok ? 'PASS' : 'FAIL';
        const got = r.card ? `${r.card.id} (${r.card.name})` : '—';
        console.log(`[${badge}] ${c.title}`);
        console.log(`        esperado: ${c.expectStatus}${c.expectId ? ' / ' + c.expectId : ''}` +
            ` | obtido: ${r.status} / ${got} conf=${r.confidence.toFixed(2)}`);
        console.log(`        motivo: ${r.reason}`);
        if (!ok)
            console.log(`        >>> DIVERGÊNCIA`);
        console.log();
    }
    console.log(`Resultado: ${pass}/${cases.length} casos ok.`);
    if (pass !== cases.length)
        process.exitCode = 1;
}
main().catch((e) => {
    console.error('Erro na validação:', e);
    process.exitCode = 1;
});

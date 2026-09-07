/**
 * Scanner do protótipo: câmera/imagem → OCR do número → matching contra o set.
 * Orquestra os módulos puros (matching/*, scanner/*). Política de aceite:
 *   - lê N/M com denominador == printedTotal  -> AUTO (fila do lote)
 *   - lê número que existe no set mas sem denom -> pendência com sugestão
 *   - resto -> pendência (resolver manual pela lista pré-filtrada)
 */
import { fetchSets, fetchSetCards, SetIndex } from './matching/index.js';
import { validNumberSet, pickBestNumber } from './scanner/extractNumber.js';
import { startCamera, makeOcrVariants } from './scanner/camera.js';
import { ocrText } from './scanner/ocr.js';
const $ = (id) => document.getElementById(id);
const setSel = $('set');
const modeSel = $('mode');
const video = $('video');
const imgPreview = $('imgPreview');
const guide = $('guide');
const statusEl = $('status');
const debugEl = $('debug');
const filaEl = $('fila');
const pendEl = $('pend');
const camBtn = $('camBtn');
const fileInput = $('file');
const scanOnceBtn = $('scanOnce');
const fileWrap = $('fileWrap');
let index = null;
let cards = [];
let valid = new Set();
let printedTotal = 0;
let scanning = false;
let loopTimer = null;
let stream = null;
const fila = new Map();
const pend = [];
function setStatus(s) { statusEl.textContent = s; }
function beep(ok) {
    try {
        const ac = new AudioContext();
        const o = ac.createOscillator();
        const g = ac.createGain();
        o.frequency.value = ok ? 880 : 300;
        o.connect(g);
        g.connect(ac.destination);
        g.gain.value = 0.05;
        o.start();
        o.stop(ac.currentTime + 0.08);
    }
    catch { /* sem áudio */ }
    navigator.vibrate?.(ok ? 30 : [20, 40, 20]);
}
// ---------- carga do set ----------
async function loadSets() {
    const sets = await fetchSets();
    setSel.innerHTML = '';
    for (const s of sets) {
        const o = document.createElement('option');
        o.value = s.id;
        o.textContent = `${s.name} (${s.printedTotal})`;
        setSel.appendChild(o);
    }
    if (sets.find((s) => s.id === 'base1'))
        setSel.value = 'base1';
    await loadIndex();
}
async function loadIndex() {
    setStatus(`Indexando ${setSel.value}…`);
    cards = await fetchSetCards(setSel.value);
    index = SetIndex.from(cards);
    valid = validNumberSet(cards);
    printedTotal = cards[0]?.printedTotal ?? 0;
    setStatus(`Set ${setSel.value} pronto (${index.size} cartas). ${modeSel.value === 'camera' ? 'Inicie a câmera.' : 'Escolha uma imagem.'}`);
}
// ---------- pipeline de scan ----------
async function scanSource(src) {
    if (!index)
        return;
    const variants = makeOcrVariants(src);
    const results = [];
    for (const v of variants) {
        const text = await ocrText(v.canvas);
        results.push({ source: v.source, rawText: text });
    }
    const ex = pickBestNumber(results, valid, printedTotal);
    debugEl.textContent = ex.best
        ? `leu "${ex.best.number}${ex.best.denominator ? '/' + ex.best.denominator : ''}" via ${ex.best.source} · validado=${ex.validatedInSet} denom=${ex.denomMatches}`
        : `nada legível (${results.filter((r) => r.rawText.trim()).length} leituras cruas)`;
    if (ex.denomMatches && ex.best) {
        const m = index.match({ setId: setSel.value, number: ex.best.number });
        if (m.card) {
            addToFila(m.card);
            return;
        }
    }
    // Não confiável -> pendência. NÃO mostramos "sugestão": numa leitura de baixa
    // confiança ela costuma estar errada e induz a tap errado. Resolve-se manual
    // pela lista já pré-filtrada do set.
    addPend(ex.best?.rawText ?? '(sem leitura)');
}
let lastAddedAt = 0;
let lastAddedId = '';
function addToFila(card) {
    const now = Date.now();
    // dedupe: mesma carta em janela curta conta como o mesmo frame
    if (card.id === lastAddedId && now - lastAddedAt < 2500)
        return;
    lastAddedId = card.id;
    lastAddedAt = now;
    const e = fila.get(card.id);
    if (e)
        e.qty++;
    else
        fila.set(card.id, { card, qty: 1 });
    beep(true);
    renderFila();
}
function addPend(raw) {
    pend.push({ id: 'p' + Date.now() + Math.random().toString(36).slice(2, 5), raw });
    beep(false);
    renderPend();
}
// ---------- render ----------
function renderFila() {
    const total = [...fila.values()].reduce((a, e) => a + e.qty, 0);
    filaEl.innerHTML = `<h2>Fila do lote (${total})</h2>`;
    for (const e of fila.values()) {
        const div = document.createElement('div');
        div.className = 'item';
        div.innerHTML = `${e.card.imageSmall ? `<img src="${e.card.imageSmall}" alt="">` : ''}
      <div><span class="badge auto">AUTO</span> <strong>${e.card.name}</strong> #${e.card.number}
      <br><span class="muted">${e.card.id}</span></div>
      <span class="qty">×${e.qty}</span>`;
        filaEl.appendChild(div);
    }
}
function renderPend() {
    pendEl.innerHTML = `<h2>Pendências (${pend.length})</h2>`;
    pend.forEach((p) => {
        const div = document.createElement('div');
        div.className = 'item pendrow';
        div.innerHTML = `<div><span class="badge pend">?</span> leitura: <code>${p.raw}</code>
      <br><input placeholder="nº correto" data-id="${p.id}" /></div>`;
        pendEl.appendChild(div);
    });
    pendEl.querySelectorAll('input').forEach((inp) => inp.addEventListener('keydown', (e) => {
        if (e.key !== 'Enter' || !index)
            return;
        const el = e.target;
        const m = index.match({ setId: setSel.value, number: el.value });
        if (m.card) {
            addToFila(m.card);
            const i = pend.findIndex((x) => x.id === el.dataset.id);
            if (i >= 0)
                pend.splice(i, 1);
            renderPend();
        }
        else {
            el.style.borderColor = '#dc2626';
        }
    }));
}
// ---------- modos ----------
function stopCamera() {
    if (loopTimer) {
        clearInterval(loopTimer);
        loopTimer = null;
    }
    scanning = false;
    stream?.getTracks().forEach((t) => t.stop());
    stream = null;
    camBtn.textContent = 'Iniciar câmera';
}
async function toggleCamera() {
    if (scanning) {
        stopCamera();
        setStatus('Câmera parada.');
        return;
    }
    setStatus('Pedindo acesso à câmera…');
    try {
        stream = await startCamera(video);
    }
    catch (e) {
        setStatus('Sem acesso à câmera: ' + String(e));
        return;
    }
    scanning = true;
    camBtn.textContent = 'Parar câmera';
    setStatus('Escaneando… aponte o número da carta pra dentro do quadro.');
    loopTimer = window.setInterval(async () => {
        if (!scanning || video.videoWidth === 0)
            return;
        await scanSource(video);
    }, 900);
}
function applyMode() {
    const cam = modeSel.value === 'camera';
    video.hidden = !cam;
    guide.hidden = !cam;
    imgPreview.hidden = cam;
    camBtn.hidden = !cam;
    fileWrap.hidden = cam;
    scanOnceBtn.hidden = cam;
    if (!cam)
        stopCamera();
    loadIndex();
}
fileInput.addEventListener('change', () => {
    const f = fileInput.files?.[0];
    if (!f)
        return;
    imgPreview.src = URL.createObjectURL(f);
    imgPreview.hidden = false;
});
scanOnceBtn.addEventListener('click', async () => {
    if (!imgPreview.src) {
        setStatus('Escolha uma imagem primeiro.');
        return;
    }
    setStatus('Escaneando imagem…');
    await imgPreview.decode().catch(() => { });
    await scanSource(imgPreview);
    setStatus('Pronto.');
});
camBtn.addEventListener('click', toggleCamera);
modeSel.addEventListener('change', applyMode);
setSel.addEventListener('change', () => {
    // trocar de set começa um novo lote
    fila.clear();
    pend.length = 0;
    renderFila();
    renderPend();
    loadIndex();
});
applyMode();
loadSets().catch((e) => setStatus('Erro: ' + String(e)));

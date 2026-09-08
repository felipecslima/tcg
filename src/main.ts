/**
 * Scanner web: câmera → motor de visão (detecção + retificação + descritor
 * + busca global + votação temporal) → fila do lote. Sem pré-filtro de set.
 * OCR do número entra só como desempate, sob demanda do motor.
 */
import { CardIndex, imageUrl, type IndexJSON, type IndexCard, type SearchHit } from './vision/catalog.js';
import { Recognizer, recognizeOnce, type RecogResult, type NumberReading } from './vision/recognizer.js';
import type { RGBA, Rect, Quad } from './vision/image.js';
import { CARD_W, CARD_H } from './vision/descriptor.js';
import { startCamera, makeNumberVariants } from './scanner/camera.js';
import { ocrText } from './scanner/ocr.js';
import {parseCollectorNumber, type ParsedNumber } from './scanner/numberParse.js';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const modeSel = $<HTMLSelectElement>('mode');
const seriesSel = $<HTMLSelectElement>('series');
const video = $<HTMLVideoElement>('video');
const imgPreview = $<HTMLImageElement>('imgPreview');
const overlay = $<HTMLCanvasElement>('overlay');
const statusEl = $<HTMLDivElement>('status');
const debugEl = $<HTMLDivElement>('debug');
const resultEl = $<HTMLDivElement>('result');
const filaEl = $<HTMLDivElement>('fila');
const camBtn = $<HTMLButtonElement>('camBtn');
const fileInput = $<HTMLInputElement>('file');
const fileWrap = $<HTMLLabelElement>('fileWrap');
const scanOnceBtn = $<HTMLButtonElement>('scanOnce');
const manualInp = $<HTMLInputElement>('manual');
const manualHits = $<HTMLDivElement>('manualHits');

let index: CardIndex | null = null;
let recognizer: Recognizer | null = null;
let stream: MediaStream | null = null;
let loopTimer: number | null = null;
let busy = false;
const work = document.createElement('canvas');
const wctx = work.getContext('2d', { willReadFrequently: true })!;

interface FilaEntry { card: IndexCard; qty: number }
const fila = new Map<string, FilaEntry>();

function setStatus(html: string) { statusEl.innerHTML = html; }

function beep(ok: boolean) {
  try {
    const ac = new AudioContext();
    const o = ac.createOscillator(), g = ac.createGain();
    o.frequency.value = ok ? 880 : 300;
    o.connect(g); g.connect(ac.destination);
    g.gain.value = 0.05;
    o.start(); o.stop(ac.currentTime + 0.09);
  } catch { /* sem áudio */ }
  navigator.vibrate?.(ok ? 40 : [20, 40, 20]);
}

// ---------- índice ----------
async function loadIndex() {
  const res = await fetch('/index/tcgdex-pt.json');
  if (!res.ok) throw new Error('índice não encontrado — rode `npm run index:build`');
  index = CardIndex.fromJSON((await res.json()) as IndexJSON);
  const bySeries = new Map<string, number>();
  for (const s of index.sets) bySeries.set(s.series, (bySeries.get(s.series) ?? 0) + s.count);
  for (const [series, n] of bySeries) {
    const o = document.createElement('option');
    o.value = series; o.textContent = `Série ${series} (${n})`;
    seriesSel.appendChild(o);
  }
  setStatus(`Índice pronto: <strong>${index.size}</strong> cartas em ${index.sets.length} sets (${index.source}).`);
}

function currentSetIds(): Set<string> | undefined {
  if (!index || !seriesSel.value) return undefined;
  return new Set(index.sets.filter((s) => s.series === seriesSel.value).map((s) => s.id));
}

// ---------- OCR do número (gate de verificação do Recognizer) ----------
// Mesmo protocolo de scripts/e2e-validate.ts (readNumberNode): lê o rodapé da
// carta retificada em alta resolução, caixa a caixa, e devolve TODOS os textos
// crus — o Recognizer compara com o número impresso esperado da candidata e
// das gêmeas (reprints). Para na primeira caixa que produz uma fração.
async function readNumber(rect: RGBA): Promise<NumberReading | null> {
  const c = document.createElement('canvas');
  c.width = rect.width; c.height = rect.height;
  const px = new Uint8ClampedArray(rect.data.length);
  px.set(rect.data);
  c.getContext('2d')!.putImageData(new ImageData(px, rect.width, rect.height), 0, 0);
  const texts: string[] = [];
  let fraction: ParsedNumber | null = null, lone: ParsedNumber | null = null, lastBox = '';
  for (const v of makeNumberVariants(c)) {
    if (fraction && v.box !== lastBox) break;
    lastBox = v.box;
    const txt = (await ocrText(v.canvas)).replace(/\s+/g, ' ').trim();
    if (!txt) continue;
    texts.push(txt);
    const p = parseCollectorNumber(txt);
    if (p?.denominator) fraction ??= p; else if (p) lone ??= p;
  }
  const p = fraction ?? lone;
  if (!p && !texts.length) return null;
  return { number: p?.number ?? '', denominator: p?.denominator, texts };
}

// ---------- captura ----------
function grabFrame(src: HTMLVideoElement | HTMLImageElement, maxDim: number): RGBA {
  const sw = src instanceof HTMLVideoElement ? src.videoWidth : src.naturalWidth;
  const sh = src instanceof HTMLVideoElement ? src.videoHeight : src.naturalHeight;
  const k = Math.min(1, maxDim / Math.max(sw, sh));
  work.width = Math.round(sw * k); work.height = Math.round(sh * k);
  wctx.drawImage(src, 0, 0, work.width, work.height);
  const img = wctx.getImageData(0, 0, work.width, work.height);
  return { data: img.data, width: img.width, height: img.height };
}

function cameraGuide(w: number, h: number): Rect {
  let gh = h * 0.82, gw = gh * (CARD_W / CARD_H);
  if (gw > w * 0.9) { gw = w * 0.9; gh = gw * (CARD_H / CARD_W); }
  return { x: (w - gw) / 2, y: (h - gh) / 2, w: gw, h: gh };
}

// ---------- overlay ----------
function drawOverlay(frameW: number, frameH: number, guide: Rect | null, corners: Quad | null, state: string) {
  const dpr = window.devicePixelRatio || 1;
  const cssW = overlay.clientWidth, cssH = overlay.clientHeight;
  overlay.width = Math.round(cssW * dpr); overlay.height = Math.round(cssH * dpr);
  const ctx = overlay.getContext('2d')!;
  ctx.clearRect(0, 0, overlay.width, overlay.height);
  const k = (cssW * dpr) / frameW, ky = (cssH * dpr) / frameH;
  ctx.lineWidth = 3 * dpr;
  if (guide) {
    ctx.setLineDash([10 * dpr, 8 * dpr]);
    ctx.strokeStyle = 'rgba(34,211,238,0.9)';
    ctx.strokeRect(guide.x * k, guide.y * ky, guide.w * k, guide.h * ky);
    ctx.setLineDash([]);
  }
  if (corners) {
    ctx.strokeStyle = state === 'confirmed' ? '#16a34a' : state === 'candidate' ? '#f59e0b' : 'rgba(255,255,255,0.6)';
    ctx.beginPath();
    corners.forEach((p, i) => (i ? ctx.lineTo(p.x * k, p.y * ky) : ctx.moveTo(p.x * k, p.y * ky)));
    ctx.closePath(); ctx.stroke();
  }
}

// ---------- render ----------
function candHtml(h: SearchHit, top: boolean, extra = '') {
  return `<div class="cand ${top ? 'top' : ''}" data-id="${h.card.id}" title="${h.card.name} · ${h.card.setName} #${h.card.number}">
    <img src="${imageUrl(h.card)}" alt="" loading="lazy"><span>${h.dist.toFixed(0)}${extra}</span></div>`;
}

function renderResult(r: RecogResult | null, single?: ReturnType<typeof recognizeOnce>) {
  const hits = r?.hits ?? single?.hits ?? [];
  const best = hits[0];
  const state = r?.state ?? (single ? { confident: 'confirmed', ambiguous: 'candidate', unknown: 'unknown' }[single.verdict] : 'idle');
  if (!best) { resultEl.innerHTML = '<span class="muted">Nenhuma carta.</span>'; return; }
  const lead = r?.votes[0];
  const shown = lead ? { card: lead.card, dist: best.card.id === lead.card.id ? best.dist : NaN } : best;
  const score = lead ? Math.min(1, lead.score / 2) : single?.verdict === 'confident' ? 1 : 0.4;
  resultEl.innerHTML = `
    <img src="${imageUrl(shown.card, 'high')}" alt="">
    <div style="flex:1">
      <span class="state ${state}">${state}</span>
      <div class="big">${shown.card.name}</div>
      <div class="muted">${shown.card.setName} · #${shown.card.number}/${shown.card.printedTotal} · <code>${shown.card.id}</code></div>
      <div class="bar"><i style="width:${(score * 100).toFixed(0)}%"></i></div>
      <div class="cands">${hits.slice(0, 5).map((h, i) => candHtml(h, i === 0)).join('')}</div>
      <div class="muted">${r?.reason ?? (single ? `veredito: ${single.verdict}, margem ${single.margin.toFixed(0)}` : '')}</div>
    </div>`;
  resultEl.querySelectorAll<HTMLElement>('.cand').forEach((el) =>
    el.addEventListener('click', () => { const c = index?.get(el.dataset.id!); if (c) addToFila(c); }));
}

function addToFila(card: IndexCard) {
  const e = fila.get(card.id);
  if (e) e.qty++; else fila.set(card.id, { card, qty: 1 });
  beep(true);
  renderFila();
}

function renderFila() {
  const total = [...fila.values()].reduce((a, e) => a + e.qty, 0);
  filaEl.innerHTML = `<h2>Fila do lote (${total})</h2>`;
  for (const e of [...fila.values()].reverse()) {
    const div = document.createElement('div');
    div.className = 'item';
    div.innerHTML = `<img src="${imageUrl(e.card)}" alt="">
      <div><strong>${e.card.name}</strong> #${e.card.number}<br><span class="muted">${e.card.setName}</span></div>
      <span class="qty">×${e.qty}</span>`;
    filaEl.appendChild(div);
  }
}

// ---------- câmera ----------
function stopCamera() {
  if (loopTimer) { clearInterval(loopTimer); loopTimer = null; }
  stream?.getTracks().forEach((t) => t.stop());
  stream = null; recognizer = null;
  camBtn.textContent = 'Iniciar câmera';
}

async function toggleCamera() {
  if (stream) { stopCamera(); setStatus('Câmera parada.'); return; }
  if (!index) { setStatus('Índice ainda carregando…'); return; }
  setStatus('Pedindo acesso à câmera…');
  try { stream = await startCamera(video); } catch (e) { setStatus('Sem acesso à câmera: ' + String(e)); return; }
  video.hidden = false;
  camBtn.textContent = 'Parar câmera';
  recognizer = new Recognizer(index, {
    setIds: currentSetIds(),
    readNumber,
    onConfirmed: (hit) => addToFila(hit.card),
  });
  setStatus('Alinhe a carta no quadro.');
  loopTimer = window.setInterval(() => {
    if (busy || !recognizer || video.videoWidth === 0) return;
    busy = true;
    try {
      const t0 = performance.now();
      const frame = grabFrame(video, 960);
      const guide = cameraGuide(frame.width, frame.height);
      const r = recognizer.feed(frame, guide);
      const ms = performance.now() - t0;
      drawOverlay(frame.width, frame.height, guide, r.detection.usedFallback ? null : r.detection.corners, r.state);
      renderResult(r);
      setStatus(`<span class="state ${r.state}">${r.state}</span> ${r.reason}`);
      debugEl.textContent = `${ms.toFixed(0)} ms/frame · borda=${r.detection.edgeStrength.toFixed(0)} conf=${r.detection.confidence.toFixed(2)} · votos: ${r.votes.slice(0, 3).map((v) => `${v.card.name}=${v.score.toFixed(2)}`).join(', ')}`;
    } finally { busy = false; }
  }, 140);
}

// ---------- foto ----------
async function scanPhoto() {
  if (!index || !imgPreview.src) { setStatus('Escolha uma imagem.'); return; }
  await imgPreview.decode().catch(() => {});
  const t0 = performance.now();
  const frame = grabFrame(imgPreview, 1400);
  const r = recognizeOnce(index, frame, undefined, { setIds: currentSetIds() });
  drawOverlay(frame.width, frame.height, null, r.detection.corners, r.verdict === 'confident' ? 'confirmed' : 'candidate');
  renderResult(null, r);
  setStatus(`<span class="state ${r.verdict === 'confident' ? 'confirmed' : r.verdict === 'unknown' ? 'unknown' : 'candidate'}">${r.verdict}</span> ${(performance.now() - t0).toFixed(0)} ms · dist=${r.hits[0]?.dist.toFixed(0) ?? '—'} margem=${r.margin.toFixed(0)} · borda=${r.detection.edgeStrength.toFixed(0)} conf=${r.detection.confidence.toFixed(2)}${r.detection.usedFallback ? ' (guia)' : ''}`);
  if (r.verdict === 'confident') addToFila(r.hits[0].card);
  else beep(false);
}

// ---------- busca manual ----------
manualInp.addEventListener('input', () => {
  const q = manualInp.value.trim().toLowerCase();
  manualHits.innerHTML = '';
  if (!index || q.length < 2) return;
  const hits = index.cards.filter((c) => c.name.toLowerCase().includes(q) || c.number.replace(/^0+/, '') === q.replace(/^0+/, '')).slice(0, 8);
  for (const c of hits) {
    const div = document.createElement('div');
    div.className = 'hit';
    div.innerHTML = `<img src="${imageUrl(c)}" alt=""><div>${c.name} #${c.number}<br><span class="muted">${c.setName}</span></div>`;
    div.addEventListener('click', () => { addToFila(c); manualInp.value = ''; manualHits.innerHTML = ''; });
    manualHits.appendChild(div);
  }
});

// ---------- modos ----------
function applyMode() {
  const cam = modeSel.value === 'camera';
  video.hidden = !cam || !stream;
  imgPreview.hidden = cam;
  camBtn.hidden = !cam;
  fileWrap.hidden = cam;
  scanOnceBtn.hidden = cam;
  if (!cam) stopCamera();
  overlay.getContext('2d')!.clearRect(0, 0, overlay.width, overlay.height);
}

fileInput.addEventListener('change', () => {
  const f = fileInput.files?.[0];
  if (!f) return;
  imgPreview.src = URL.createObjectURL(f);
  imgPreview.hidden = false;
});
scanOnceBtn.addEventListener('click', scanPhoto);
camBtn.addEventListener('click', toggleCamera);
modeSel.addEventListener('change', applyMode);
seriesSel.addEventListener('change', () => { if (recognizer) { recognizer.opts.setIds = currentSetIds(); recognizer.reset(); } });

applyMode();
loadIndex().catch((e) => setStatus('Erro: ' + String(e)));

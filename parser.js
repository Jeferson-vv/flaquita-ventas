/* parser.js: convierte lo que se dice o escribe en items de venta.
   No usa el DOM, así que se puede probar en Node. Los nombres que devuelve
   deben coincidir exactamente con productos.nombre en Supabase (ver seed.sql). */
(function (root) {
  'use strict';

  const W = { un: 1, una: 1, uno: 1, dos: 2, tres: 3, cuatro: 4, cinco: 5, seis: 6, siete: 7,
    ocho: 8, nueve: 9, diez: 10, once: 11, doce: 12, quince: 15, diecisiete: 17, veinte: 20 };
  const has = (o, k) => Object.prototype.hasOwnProperty.call(o, k);

  function norm(s) {
    s = String(s).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
    s = s.replace(/\bdiez y siete\b/g, '17');
    return s.replace(/\b[a-z]+\b/g, w => (has(W, w) ? String(W[w]) : w));
  }

  // Convierte expresiones de tamaño en tokens sz*. "1 litro" -> sz1, "medio litro" -> sz05, etc.
  function preprocess(t) {
    return t
      .replace(/[-–—_"'¿?¡!:;()]/g, ' ')
      .replace(/\bsoles?\b/g, '')
      .replace(/(?<!\d)\.|\.(?!\d)/g, ' ')
      .replace(/\b(\d+)\s*(l|lt|lts|lit)\b/g, '$1 litros')
      .replace(/\b(medio|media)\s+jarra\b/g, ' jh ')
      .replace(/\bjarras?\b/g, ' jf ')
      .replace(/\b2 (litros? )?(y medio|1\/2)( litros?)?\b|\b2[.,]5\b/g, ' sz25 ')
      .replace(/\b1 (litros? )?(y medio|1\/2)( litros?)?\b|\b1[.,]5\b|\b1[.,]30?\b|\b1 litro (y )?(30|treinta)\b|\blitro (y )?(30|treinta)\b|\b1 (30|treinta)\b/g, ' sz15 ')
      .replace(/\b(medio|media)\s+litro\b|\b1\/2( litro)?\b|\b500\s*(ml)?\b/g, ' sz05 ')
      .replace(/\b400\s*(ml|mililitros)?\b/g, ' sz400 ')
      .replace(/\b625\s*(ml|mililitros)?\b/g, ' sz625 ')
      .replace(/\bpersonal\b/g, ' szp ')
      .replace(/\b3 litros?\b/g, ' sz3 ')
      .replace(/\b2 litros?\b/g, ' sz2 ')
      .replace(/\b(1 litros?|litros?)\b/g, ' sz1 ');
  }

  const FILL = /^(cervezas?|botellas?|vasos?|unidades?|porciones?|platos?|helad[ao]s?)$/;
  const BEER = { heineken: 'Heineken', arequip: 'Arequipeña', pilsen: 'Pilsen', trigo: 'Trigo', negra: 'Negra' };
  const SODA_SIZE = { sz400: '400 ml', sz625: '625 ml', sz05: '½ litro', sz1: '1 litro', sz15: '1½ litros', sz25: '2½ litros', sz3: '3 litros' };
  const ESC_SIZE = { szp: 'personal (vidrio)', sz05: '½ litro', sz1: '1 litro (vidrio)', sz15: '1½ litros', sz2: '2 litros' };
  const CH_BY_PRICE = { 20: 'Chicharrón Taypa', 17: 'Chicharrón plato normal', 15: 'Chicharrón 1 porción', 10: 'Chicharrón ½ porción' };

  function kindOf(w) {
    if (/^chicharr/.test(w)) return { k: 'ch' };
    if (w === 'taypa' || w === 'plato' || w === 'combinado') return { k: 'ch', mod: w };
    if (w === 'porcion') return { k: 'mod', mod: 'porcion' };
    if (w === 'media' || w === 'medio') return { k: 'mod', mod: 'media' };
    if (w === 'sarza' || w === 'sarzas') return { k: 'sarza' };
    if (w === 'jf' || w === 'jh') return { k: 'cm', jar: w };
    if (w === 'chicha') return { k: 'cm' };
    if (w === 'coca' || w === 'cola') return { k: 'so', brand: 'Coca' };
    if (w === 'inca' || w === 'kola') return { k: 'so', brand: 'Inca' };
    if (w === 'gaseosa' || w === 'gaseosas') return { k: 'so' };
    if (/^escoces/.test(w)) return { k: 'es' };
    if (/^(agua|aguas|cielo|luis)$/.test(w)) return { k: 'ag' };
    for (const b in BEER) if (w === b || w.startsWith(b)) return { k: 'be', beer: BEER[b] };
    return null;
  }

  function resolve(it, courtesy, catPrice) {
    const m = x => it.mods.includes(x);
    let name;
    switch (it.kind) {
      case 'ch':
        if (it.sarza || m('combinado')) name = 'Combinado Taypa con sarza';
        else if (m('media')) name = 'Chicharrón ½ porción';
        else if (m('porcion')) name = 'Chicharrón 1 porción';
        else if (m('plato')) name = 'Chicharrón plato normal';
        else if (m('taypa')) name = 'Chicharrón Taypa';
        else if (it.price && has(CH_BY_PRICE, it.price)) name = CH_BY_PRICE[it.price];
        else return { error: it.price ? 'no hay chicharrón de S/ ' + it.price : 'chicharrón sin precio (di "de 20", "de 17", "de 15" o "de 10")' };
        break;
      case 'sarza':
        name = (m('media') || it.price === 10) ? 'Sarza ½ porción' : 'Sarza de cabeza';
        break;
      case 'cm':
        if (courtesy) return { name: 'Chicha morada de cortesía', price: 0 };
        if (it.size && it.size !== 'sz05' && it.size !== 'sz1') return { error: 'no hay chicha morada de ese tamaño' };
        name = (it.jar === 'jh' || it.size === 'sz05') ? 'Chicha morada ½ litro' : 'Chicha morada 1 litro';
        break;
      case 'so':
        if (!it.brand) return { error: '¿Coca o Inca? (gaseosa sin marca)' };
        if (!it.size) return { error: 'falta el tamaño de ' + it.brand + ' (ej: "de 1 litro")' };
        if (!has(SODA_SIZE, it.size)) return { error: 'no tenemos ' + it.brand + ' de ese tamaño' };
        name = it.brand + ' ' + SODA_SIZE[it.size];
        break;
      case 'es':
        if (!it.size) return { error: 'falta el tamaño de la escocesa (ej: "personal" o "de 1 litro")' };
        if (!has(ESC_SIZE, it.size)) return { error: 'no hay escocesa de ese tamaño' };
        name = 'Escocesa ' + ESC_SIZE[it.size];
        break;
      case 'ag':
        name = 'Agua (Cielo, San Luis)';
        break;
      case 'be':
        name = it.beer;
        break;
      default:
        return { error: 'producto desconocido' };
    }
    const cp = catPrice(name);
    if (cp === null) return { error: '"' + name + '" no está en la carta' };
    return { name, price: it.price > 0 ? it.price : cp };
  }

  const STD_NAMES = new Set([
    'Chicharrón Taypa', 'Chicharrón plato normal', 'Chicharrón 1 porción', 'Chicharrón ½ porción',
    'Combinado Taypa con sarza', 'Sarza de cabeza', 'Sarza ½ porción',
    'Chicha morada 1 litro', 'Chicha morada ½ litro', 'Chicha morada de cortesía',
    'Coca 3 litros', 'Coca 2½ litros', 'Coca 1½ litros', 'Coca 1 litro', 'Coca ½ litro', 'Coca 625 ml', 'Coca 400 ml',
    'Inca 3 litros', 'Inca 2½ litros', 'Inca 1½ litros', 'Inca 1 litro', 'Inca ½ litro', 'Inca 625 ml', 'Inca 400 ml',
    'Escocesa 2 litros', 'Escocesa 1½ litros', 'Escocesa 1 litro (vidrio)', 'Escocesa ½ litro', 'Escocesa personal (vidrio)',
    'Agua (Cielo, San Luis)', 'Heineken', 'Arequipeña', 'Pilsen', 'Trigo', 'Negra'
  ]);
  const STOP_WORDS = /^(de|del|con|sin|en|el|la|los|las|un|una|por|para|y|o|a)$/;
  function stem(w) {
    if (w.length > 4 && w.endsWith('es') && !/^sz/.test(w)) return w.slice(0, -2);
    if (w.length > 3 && w.endsWith('s') && !/^sz/.test(w)) return w.slice(0, -1);
    return w;
  }
  function buildCustomMatchers(cat) {
    const list = [];
    for (const p of cat) {
      if (!p || !p.nombre || STD_NAMES.has(p.nombre)) continue;
      const tokens = preprocess(norm(p.nombre))
        .replace(/,/g, ' ')
        .split(/\s+/)
        .filter(w => w && !STOP_WORDS.test(w))
        .map(stem);
      if (tokens.length) list.push({ prod: p, tokens });
    }
    list.sort((a, b) => b.tokens.length - a.tokens.length);
    return list;
  }
  function matchCustomAt(tk, idx, matchers) {
    if (!matchers.length) return null;
    const w0 = stem(tk[idx]);
    for (const m of matchers) {
      if (m.tokens[0] !== w0) continue;
      let ok = true, maxEnd = idx;
      const windowEnd = Math.min(tk.length - 1, idx + m.tokens.length + 2);
      for (let j = 1; j < m.tokens.length; j++) {
        const target = m.tokens[j];
        let foundAt = -1;
        for (let k = idx + 1; k <= windowEnd; k++) {
          if (stem(tk[k]) === target) { foundAt = k; break; }
        }
        if (foundAt === -1) { ok = false; break; }
        if (foundAt > maxEnd) maxEnd = foundAt;
      }
      if (ok) return { prod: m.prod, end: maxEnd };
    }
    return null;
  }

  function parseMetodo(n0) {
    if (/\b(yape\w*|llape\w*|jape|ya\s+pe)\b/.test(n0)) return 'yape';
    if (/\b(plin\w*|plim)\b/.test(n0)) return 'plin';
    if (/\b(tarjeta\w*|pos|visa|mastercard|debito|credito)\b/.test(n0)) return 'tarjeta';
    if (/\b(transferencia\w*|deposito\w*|bcp|interbank|bbva|scotiabank)\b/.test(n0)) return 'transferencia';
    if (/\b(efectivo|cash|contado)\b/.test(n0)) return 'efectivo';
    return null;
  }

  // catalog: [{ nombre, precio }]. Devuelve { items: [{name, q, price}], rejects: [texto], metodo: string|null }
  function parseVenta(txt, catalog) {
    const cat = catalog || [];
    const customMatchers = buildCustomMatchers(cat);
    const n0 = norm(txt);
    const metodo = parseMetodo(n0);
    const courtesy = /\b(cortesia|invit\w*)\b/.test(n0);
    const nClean = n0.replace(/\b(pagad[oa]s?|pagos?|pagar|efectivo|cash|contado|yape\w*|llape\w*|jape|ya\s+pe|plin\w*|plim|tarjeta\w*|pos|visa|mastercard|debito|credito|transferencia\w*|deposito\w*|bcp|interbank|bbva|scotiabank)\b/g, ' ');
    const tk = preprocess(nClean).replace(/,/g, ' ').split(/\s+/).filter(Boolean);
    const out = [];
    let cur = null, pend = null, psz = null, pmods = [];

    for (let i = 0; i < tk.length; i++) {
      const w = tk[i], prev = tk[i - 1] || '', next = tk[i + 1] || '';

      if (/^\d+([.,]\d+)?$/.test(w)) {
        const v = parseFloat(w.replace(',', '.'));
        if (/^(de|a|por)$/.test(prev) && cur && i - cur.end <= 4) { cur.price = v; cur.end = i; continue; }
        if (next && (kindOf(next) || FILL.test(next) || matchCustomAt(tk, i + 1, customMatchers))) pend = v;
        continue;
      }

      const cm = matchCustomAt(tk, i, customMatchers);
      if (cm) {
        const it = {
          kind: 'custom', customProd: cm.prod, q: pend === null ? 1 : pend,
          size: null, price: 0, brand: null, jar: null, beer: null, mods: [], sarza: false, end: cm.end
        };
        out.push(it); cur = it;
        pend = null; psz = null; pmods = [];
        i = cm.end;
        continue;
      }

      if (/^sz/.test(w)) {
        if (cur && !cur.size && (cur.kind === 'so' || cur.kind === 'es' || cur.kind === 'cm') && pend === null && i - cur.end <= 3) {
          cur.size = w; cur.end = i;
        } else psz = w;
        continue;
      }

      const kd = kindOf(w);
      if (!kd) continue;

      if (kd.k === 'mod') {
        if (cur && (cur.kind === 'ch' || cur.kind === 'sarza') && pend === null && i - cur.end <= 3) { cur.mods.push(kd.mod); cur.end = i; }
        else pmods.push(kd.mod);
        continue;
      }

      if (kd.k === 'sarza' && cur && cur.kind === 'ch' && !cur.sarza && pend === null && i - cur.end <= 4) {
        cur.sarza = true; cur.end = i; continue;
      }

      let merged = false;
      if (cur && pend === null) {
        if (kd.k === 'cm' && cur.kind === 'cm' && i - cur.end <= 3) {
          if (kd.jar && !cur.jar) cur.jar = kd.jar;
          cur.end = i; merged = true;
        } else if (kd.k === 'so' && cur.kind === 'so' && i - cur.end <= 1 && (!kd.brand || !cur.brand || kd.brand === cur.brand)) {
          if (kd.brand && !cur.brand) cur.brand = kd.brand;
          cur.end = i; merged = true;
        } else if (kd.k === 'ag' && cur.kind === 'ag' && i - cur.end <= 1) {
          cur.end = i; merged = true;
        } else if (kd.k === 'ch' && kd.mod && cur.kind === 'ch' && i - cur.end <= 2) {
          cur.mods.push(kd.mod); cur.end = i; merged = true;
        }
      }

      if (!merged) {
        const it = {
          kind: kd.k, q: pend === null ? 1 : pend, size: psz, price: 0,
          brand: kd.brand || null, jar: kd.jar || null, beer: kd.beer || null,
          mods: pmods.concat(kd.mod ? [kd.mod] : []), sarza: false, end: i
        };
        out.push(it); cur = it;
        pend = null; psz = null; pmods = [];
      }
    }

    const items = [], rejects = [];
    const catPrice = name => { const p = cat.find(x => x.nombre === name); return p ? Number(p.precio) : null; };
    for (const it of out) {
      if (it.kind === 'custom') {
        items.push({ name: it.customProd.nombre, q: it.q, price: it.price > 0 ? it.price : Number(it.customProd.precio) });
        continue;
      }
      const r = resolve(it, courtesy, catPrice);
      if (r.error) rejects.push(r.error);
      else items.push({ name: r.name, q: it.q, price: r.price });
    }
    return { items, rejects, metodo };
  }

  const api = { parseVenta, parseMetodo, norm };
  root.FlaquitaParser = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);

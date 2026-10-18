/* SPDX-License-Identifier: MIT */

/* Timelapse + lectura de Gemini + clientes sin luz (SEC), sincronizados. */
(function () {
  'use strict';

  const EVENTOS = [
    { id: '13oct', etiqueta: '13-oct tormenta', fechaCorta: '13 oct' },
    { id: '08oct', etiqueta: '8-oct aluvión', fechaCorta: '8 oct' },
  ];
  const PAUSA_FINAL_MS = 2500;
  const CHART = { w: 600, h: 300, izq: 62, der: 16, arr: 26, abj: 30, desde: 6, hasta: 23 };

  const $ = (id) => document.getElementById(id);
  const lienzo = $('lienzo');
  const ctx = lienzo.getContext('2d');
  const slider = $('slider');
  const play = $('play');
  const svg = $('chart');
  const NS = 'http://www.w3.org/2000/svg';
  const fmt = new Intl.NumberFormat('es-CL');

  const estado = {
    evento: null, datos: null, imagenes: [], indice: 0,
    sonando: false, fps: 7, temporizador: null, cache: {},
  };

  // ---------- utilidades ----------
  function minutos(hhmm) {
    const [h, m] = hhmm.split(':').map(Number);
    return h * 60 + m;
  }
  function el(tag, attrs, padre) {
    const n = document.createElementNS(NS, tag);
    for (const k in attrs) { n.setAttribute(k, attrs[k]); }
    if (padre) { padre.appendChild(n); }
    return n;
  }
  function ultimoHasta(lista, min) {
    let r = null;
    for (const x of lista) { if (minutos(x.hora) <= min) { r = x; } }
    return r;
  }

  // ---------- selector ----------
  function armarSelector() {
    const nav = $('selector');
    for (const ev of EVENTOS) {
      const b = document.createElement('button');
      b.textContent = ev.etiqueta;
      b.dataset.id = ev.id;
      b.addEventListener('click', () => cargarEvento(ev.id));
      nav.appendChild(b);
    }
  }

  // ---------- carga ----------
  async function cargarEvento(id) {
    if (estado.evento === id) { return; }
    pausar();
    estado.evento = id;
    document.querySelectorAll('#selector button').forEach((b) => {
      b.classList.toggle('activo', b.dataset.id === id);
    });
    const meta = EVENTOS.find((e) => e.id === id);
    $('fecha').textContent = meta.fechaCorta;

    if (!estado.cache[id]) {
      const resp = await fetch('/api/datos?evento=' + id, { credentials: 'same-origin' });
      if (!resp.ok) { throw new Error('datos ' + resp.status); }
      const datos = await resp.json();
      estado.cache[id] = { datos: datos, imagenes: precargar(id, datos.cuadros) };
    }
    if (estado.evento !== id) { return; }
    estado.datos = estado.cache[id].datos;
    estado.imagenes = estado.cache[id].imagenes;
    $('titulo').textContent = estado.datos.titulo;
    slider.max = String(estado.datos.cuadros.length - 1);
    armarMarcas();
    armarGrafico();
    await esperarCarga(estado.imagenes);
    if (estado.evento !== id) { return; }
    // ?hora=16:00 abre directo en ese cuadro (útil para ensayar o capturar).
    const pedida = new URLSearchParams(location.search).get('hora');
    const i = pedida ? estado.datos.cuadros.findIndex((c) => c.horaChile === pedida) : -1;
    mostrar(Math.max(0, i));
  }

  function precargar(id, cuadros) {
    return cuadros.map((c) => {
      const img = new Image();
      img.decoding = 'async';
      img.src = '/api/cuadro/' + id + '/' + c.utc + '.jpg';
      return img;
    });
  }

  function esperarCarga(imagenes) {
    const aviso = $('cargando');
    aviso.classList.remove('oculto');
    return new Promise((resolver) => {
      const tick = () => {
        const listas = imagenes.filter((i) => i.complete).length;
        $('progreso').textContent = String(Math.round(100 * listas / imagenes.length));
        if (listas === imagenes.length) {
          aviso.classList.add('oculto');
          resolver();
        } else {
          setTimeout(tick, 120);
        }
      };
      tick();
    });
  }

  // ---------- marcas de hitos en el slider ----------
  function armarMarcas() {
    const cont = $('marcas');
    cont.innerHTML = '';
    const n = estado.datos.cuadros.length - 1;
    for (const h of estado.datos.hitos) {
      const i = estado.datos.cuadros.findIndex((c) => c.horaChile === h.hora);
      if (i < 0) { continue; }
      const s = document.createElement('span');
      s.style.left = (100 * i / n) + '%';
      s.textContent = h.hora;
      s.title = h.texto;
      cont.appendChild(s);
    }
  }

  // ---------- gráfico SEC ----------
  let escalas = null;
  let capaDinamica = null;

  function armarGrafico() {
    svg.innerHTML = '';
    const c = CHART;
    // El SVG se dibuja a su tamaño real en px para que el texto no escale.
    const caja = svg.getBoundingClientRect();
    c.w = Math.max(320, Math.round(caja.width));
    c.h = Math.max(110, Math.round(caja.height));
    svg.setAttribute('viewBox', '0 0 ' + c.w + ' ' + c.h);
    const serie = estado.datos.sec.filter((p) => {
      const h = minutos(p.hora) / 60;
      return h >= c.desde && h <= c.hasta;
    });
    const maxY = Math.max(...serie.map((p) => p.clientes));
    const paso = maxY <= 20000 ? 5000 : 10000;
    const techo = Math.ceil(maxY / paso) * paso || paso;
    const x = (min) => c.izq + (min / 60 - c.desde) / (c.hasta - c.desde) * (c.w - c.izq - c.der);
    const y = (v) => c.h - c.abj - v / techo * (c.h - c.arr - c.abj);
    escalas = { x: x, y: y, serie: serie };

    const grilla = el('g', { class: 'grilla' }, svg);
    const eje = el('g', { class: 'eje' }, svg);
    for (let v = 0; v <= techo; v += paso) {
      el('line', { x1: c.izq, x2: c.w - c.der, y1: y(v), y2: y(v) }, grilla);
      const t = el('text', { x: c.izq - 8, y: y(v) + 4, 'text-anchor': 'end' }, eje);
      t.textContent = v === 0 ? '0' : fmt.format(v / 1000) + ' mil';
    }
    for (let h = c.desde; h <= c.hasta; h += 3) {
      const t = el('text', { x: x(h * 60), y: c.h - 8, 'text-anchor': 'middle' }, eje);
      t.textContent = String(h).padStart(2, '0') + 'h';
    }

    // Hitos: etiquetas a la izquierda de su línea, en filas dentro del área
    // del gráfico; el más tardío arriba (la serie sube después de los hitos).
    const gh = el('g', {}, svg);
    const nh = estado.datos.hitos.length;
    estado.datos.hitos.forEach((hito, k) => {
      const g = el('g', { class: 'hito', 'data-min': minutos(hito.hora) }, gh);
      const xx = x(minutos(hito.hora));
      const fila = 14 + (nh - 1 - k) * 18;
      el('line', { x1: xx, x2: xx, y1: fila - 12, y2: c.h - c.abj }, g);
      const t = el('text', { x: xx - 6, y: fila, 'text-anchor': 'end' }, g);
      t.textContent = hito.texto;
    });

    const pts = serie.map((p) => [x(minutos(p.hora)), y(p.clientes)]);
    const d = pts.map((p, i) => (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' ');
    el('path', { d: d, class: 'linea-tenue' }, svg);

    // Parte revelada hasta el cursor (clip).
    const defs = el('defs', {}, svg);
    const clip = el('clipPath', { id: 'revelado' }, defs);
    const rect = el('rect', { x: 0, y: 0, width: 0, height: c.h }, clip);
    const area = d + ' L' + pts[pts.length - 1][0] + ' ' + y(0) + ' L' + pts[0][0] + ' ' + y(0) + ' Z';
    el('path', { d: area, class: 'area', 'clip-path': 'url(#revelado)' }, svg);
    el('path', { d: d, class: 'linea', 'clip-path': 'url(#revelado)' }, svg);

    const cursor = el('line', { class: 'cursor', y1: c.arr - 6, y2: c.h - c.abj }, svg);
    const punto = el('circle', { class: 'punto', r: 6 }, svg);
    capaDinamica = { rect: rect, cursor: cursor, punto: punto };

    // Clic en el gráfico = saltar al cuadro más cercano de esa hora.
    svg.onclick = (e) => {
      const r = svg.getBoundingClientRect();
      const xs = (e.clientX - r.left) / r.width * c.w;
      const min = ((xs - c.izq) / (c.w - c.izq - c.der) * (c.hasta - c.desde) + c.desde) * 60;
      let mejor = 0;
      estado.datos.cuadros.forEach((q, i) => {
        if (Math.abs(minutos(q.horaChile) - min) < Math.abs(minutos(estado.datos.cuadros[mejor].horaChile) - min)) { mejor = i; }
      });
      pausar();
      mostrar(mejor);
    };
  }

  function actualizarGrafico(min) {
    const c = CHART;
    const xx = escalas.x(min);
    capaDinamica.rect.setAttribute('width', Math.max(0, xx));
    capaDinamica.cursor.setAttribute('x1', xx);
    capaDinamica.cursor.setAttribute('x2', xx);

    // Valor interpolado entre horas para que el punto siga la línea.
    const s = escalas.serie;
    let yy = escalas.y(0);
    for (let i = 0; i < s.length - 1; i++) {
      const a = minutos(s[i].hora), b = minutos(s[i + 1].hora);
      if (min >= a && min <= b) {
        const t = (min - a) / (b - a);
        yy = escalas.y(s[i].clientes + t * (s[i + 1].clientes - s[i].clientes));
        break;
      }
    }
    capaDinamica.punto.setAttribute('cx', xx);
    capaDinamica.punto.setAttribute('cy', yy);

    svg.querySelectorAll('.hito').forEach((g) => {
      g.classList.toggle('pasado', Number(g.dataset.min) <= min);
    });

    const ult = ultimoHasta(estado.datos.sec, min);
    $('clientes').textContent = ult ? fmt.format(ult.clientes) : '–';
    $('clientes-hora').textContent = ult ? 'clientes a las ' + ult.hora : '';
  }

  // ---------- tarjeta Gemini ----------
  function actualizarGemini(min) {
    const r = ultimoHasta(estado.datos.satelite, min);
    if (!r) { return; }
    $('lectura').textContent = 'lectura de las ' + r.hora;
    $('intensidad').textContent = String(r.intensidad);
    const escala = $('escala');
    if (!escala.children.length) {
      for (let i = 0; i < 10; i++) { escala.appendChild(document.createElement('i')); }
    }
    Array.from(escala.children).forEach((n, i) => n.classList.toggle('on', i < r.intensidad));
    $('nubosidad').textContent = r.nubosidadPct + '%';
    const si = (id, v) => {
      $(id).textContent = v ? 'Sí' : 'No';
      $(id).classList.toggle('si', !!v);
    };
    si('conveccion', r.conveccion);
    si('celula', r.celulaSobreSantiago);
    const tipo = r.tipo.replace(/_/g, ' ');
    $('tipo').textContent = tipo.charAt(0).toUpperCase() + tipo.slice(1);
    $('descripcion').textContent = r.descripcion;
  }

  // ---------- reproducción ----------
  function mostrar(i) {
    const d = estado.datos;
    estado.indice = i;
    const img = estado.imagenes[i];
    if (img && img.complete && img.naturalWidth) {
      ctx.drawImage(img, 0, 0, lienzo.width, lienzo.height);
    }
    const c = d.cuadros[i];
    $('hora').textContent = c.horaChile;
    slider.value = String(i);
    const min = minutos(c.horaChile);
    actualizarGemini(min);
    actualizarGrafico(min);
  }

  function siguiente() {
    const n = estado.datos.cuadros.length;
    const i = estado.indice + 1;
    if (i >= n) {
      estado.temporizador = setTimeout(() => { mostrar(0); programar(); }, PAUSA_FINAL_MS);
      return;
    }
    mostrar(i);
    programar();
  }
  function programar() {
    if (!estado.sonando) { return; }
    const espera = estado.indice === estado.datos.cuadros.length - 1 ? 0 : 1000 / estado.fps;
    estado.temporizador = setTimeout(siguiente, espera);
  }
  function reproducir() {
    if (!estado.datos) { return; }
    estado.sonando = true;
    play.classList.add('sonando');
    play.setAttribute('aria-label', 'Pausar');
    clearTimeout(estado.temporizador);
    programar();
  }
  function pausar() {
    estado.sonando = false;
    play.classList.remove('sonando');
    play.setAttribute('aria-label', 'Reproducir');
    clearTimeout(estado.temporizador);
  }

  play.addEventListener('click', () => (estado.sonando ? pausar() : reproducir()));
  slider.addEventListener('input', () => { pausar(); mostrar(Number(slider.value)); });
  $('velocidad').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) { return; }
    estado.fps = Number(b.dataset.fps);
    document.querySelectorAll('#velocidad button').forEach((x) => x.classList.toggle('activo', x === b));
  });
  document.addEventListener('keydown', (e) => {
    if (!estado.datos) { return; }
    const n = estado.datos.cuadros.length;
    if (e.key === ' ') { e.preventDefault(); estado.sonando ? pausar() : reproducir(); }
    else if (e.key === 'ArrowRight') { pausar(); mostrar(Math.min(n - 1, estado.indice + 1)); }
    else if (e.key === 'ArrowLeft') { pausar(); mostrar(Math.max(0, estado.indice - 1)); }
    else if (e.key === 'Home') { pausar(); mostrar(0); }
    else if (e.key === '1') { cargarEvento('13oct'); }
    else if (e.key === '2') { cargarEvento('08oct'); }
  });

  // Redibuja si cambia el tamaño real del gráfico (ventana, fuentes, layout).
  // Síncrono: ResizeObserver corre antes del paint, así nunca se ve desfasado.
  let ultimoTam = '';
  new ResizeObserver(() => {
    const r = svg.getBoundingClientRect();
    const tam = Math.round(r.width) + 'x' + Math.round(r.height);
    if (!estado.datos || tam === ultimoTam) { return; }
    ultimoTam = tam;
    armarGrafico();
    mostrar(estado.indice);
  }).observe(svg);

  armarSelector();
  const inicial = new URLSearchParams(location.search).get('evento');
  cargarEvento(EVENTOS.some((e) => e.id === inicial) ? inicial : '13oct').catch((err) => {
    $('cargando').textContent = 'No se pudieron cargar los datos (' + err.message + ')';
  });
})();

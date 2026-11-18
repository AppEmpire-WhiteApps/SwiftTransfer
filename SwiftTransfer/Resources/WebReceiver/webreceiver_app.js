/*
 * SwiftTransfer web receiver.
 *
 * Vanilla ES2017, no dependencies, no build step. Served by the iPhone's local
 * HTTP server; talks only to the API under ST_CONFIG.base.
 */
(() => {
  'use strict';

  // ---------- Constants ----------

  const POLL_INTERVAL_MS = 1500;
  const STATUS_RETRY_LIMIT = 2;
  const PAGE_SIZE = 200;
  const DIRECT_LINK_CATEGORIES = ['contacts', 'calendar', 'reminders'];
  const DIRECT_LINK_MAX_FILES = 3;
  const MAX_NETWORK_FAILURE_STREAK = 2;

  const CATEGORY_META = {
    contacts: {
      title: 'cat_contacts',
      zip: 'download_cat_zip_contacts',
      hint: 'import_contacts',
      icon: 'contacts',
    },
    calendar: {
      title: 'cat_calendar',
      zip: 'download_cat_zip_calendar',
      hint: 'import_calendar',
      icon: 'calendar',
    },
    reminders: {
      title: 'cat_reminders',
      zip: 'download_cat_zip_reminders',
      hint: 'import_reminders',
      icon: 'reminders',
    },
    photos: {
      title: 'cat_photos',
      zip: 'download_cat_zip_photos',
      hint: 'import_media',
      icon: 'photos',
    },
    videos: {
      title: 'cat_videos',
      zip: 'download_cat_zip_videos',
      hint: 'import_media',
      icon: 'videos',
    },
    files: {
      title: 'cat_files',
      zip: 'download_cat_zip_files',
      hint: 'import_files',
      icon: 'files',
    },
  };

  const UPLOAD_STATUS_LABELS = {
    waiting: 'upload_status_waiting',
    sending: 'upload_status_sending',
    done: 'upload_status_done',
    failed: 'upload_status_failed',
  };

  const UPLOAD_STATUS_ICONS = {
    waiting: 'clock',
    done: 'check',
    failed: 'close',
  };

  // Stroke icons on a 24x24 grid (static path data, never user input).
  const ICONS = {
    contacts: [
      'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2',
      'M12 3a4 4 0 1 0 0 8a4 4 0 1 0 0-8z',
    ],
    calendar: [
      'M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z',
      'M16 2v4',
      'M8 2v4',
      'M3 10h18',
    ],
    reminders: [
      'M4 6l1.5 1.5L8 5',
      'M4 12l1.5 1.5L8 11',
      'M4 18l1.5 1.5L8 17',
      'M11 6h9',
      'M11 12h9',
      'M11 18h9',
    ],
    photos: [
      'M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z',
      'M8.5 7a1.5 1.5 0 1 0 0 3a1.5 1.5 0 1 0 0-3z',
      'M21 15l-5-5L5 21',
    ],
    videos: [
      'M4 5h11a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z',
      'M17 10l5-3v10l-5-3z',
    ],
    files: [
      'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z',
      'M14 2v6h6',
      'M8 13h8',
      'M8 17h8',
    ],
    download: [
      'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4',
      'M7 10l5 5 5-5',
      'M12 15V3',
    ],
    upload: [
      'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4',
      'M17 8l-5-5-5 5',
      'M12 3v12',
    ],
    send: [
      'M22 2L11 13',
      'M22 2l-7 20-4-9-9-4z',
    ],
    check: ['M20 6L9 17l-5-5'],
    close: ['M18 6L6 18', 'M6 6l12 12'],
    alert: [
      'M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20z',
      'M12 8v4',
      'M12 16h.01',
    ],
    info: [
      'M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20z',
      'M12 16v-4',
      'M12 8h.01',
    ],
    wifiOff: [
      'M1 1l22 22',
      'M16.72 11.06A10.94 10.94 0 0 1 19 12.55',
      'M5 12.55a10.94 10.94 0 0 1 5.17-2.39',
      'M10.71 5.05A16 16 0 0 1 22.58 9',
      'M1.42 9a15.91 15.91 0 0 1 4.7-2.88',
      'M8.53 16.11a6 6 0 0 1 6.95 0',
      'M12 20h.01',
    ],
    lock: [
      'M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z',
      'M7 11V7a5 5 0 0 1 10 0v4',
    ],
    phone: [
      'M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z',
      'M12 18h.01',
    ],
    power: [
      'M18.36 6.64a9 9 0 1 1-12.73 0',
      'M12 2v10',
    ],
    clock: [
      'M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20z',
      'M12 6v6l4 2',
    ],
    chevron: ['M6 9l6 6 6-6'],
    refresh: [
      'M23 4v6h-6',
      'M20.49 15a9 9 0 1 1-2.12-9.36L23 10',
    ],
  };

  const BYTE_UNITS = ['byte', 'kilobyte', 'megabyte', 'gigabyte', 'terabyte'];
  const BYTE_LABELS = ['B', 'KB', 'MB', 'GB', 'TB'];
  const SVG_NS = 'http://www.w3.org/2000/svg';

  // ---------- State ----------

  const I18N = isPlainObject(window.ST_I18N) ? window.ST_I18N : {};
  const CONFIG = readConfig(window.ST_CONFIG);
  const LANG = resolveLang();
  const pluralRules = createPluralRules();

  const app = document.getElementById('app');
  const live = document.getElementById('st-live');

  let viewToken = 0;
  let pollTimer = null;
  let currentView = 'boot';
  let gateBounces = 0;
  let listCounter = 0;
  let deviceName = CONFIG.deviceName;

  const uploadState = {
    items: [],
    nextId: 1,
    uploading: false,
    visibleCount: PAGE_SIZE,
  };

  // ---------- Generic helpers ----------

  function isPlainObject(value) {
    return value !== null && typeof value === 'object' && !Array.isArray(value);
  }

  function hasOwn(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key);
  }

  function cleanName(value) {
    return typeof value === 'string' ? value.trim() : '';
  }

  function readConfig(raw) {
    const source = isPlainObject(raw) ? raw : {};
    const modes = ['download', 'upload', 'code'];
    const errors = ['wrong_code', 'locked'];
    return {
      mode: modes.indexOf(source.mode) >= 0 ? source.mode : 'code',
      base: typeof source.base === 'string' ? source.base.replace(/\/+$/, '') : '',
      deviceName: cleanName(source.deviceName) || 'iPhone',
      error: errors.indexOf(source.error) >= 0 ? source.error : null,
    };
  }

  function resolveLang() {
    const root = document.documentElement;
    const attr = (root.getAttribute('lang') || '').trim();
    if (!attr || attr.indexOf('{') >= 0) {
      root.setAttribute('lang', 'en');
      return 'en';
    }
    return attr;
  }

  function createPluralRules() {
    try {
      return new Intl.PluralRules(LANG);
    } catch (error) {
      try {
        return new Intl.PluralRules('en');
      } catch (fallbackError) {
        return null;
      }
    }
  }

  // ---------- i18n ----------

  function t(key, params) {
    const template = hasOwn(I18N, key) && typeof I18N[key] === 'string' ? I18N[key] : key;
    if (!params) {
      return template;
    }
    return template.replace(/\{(\w+)\}/g, (match, name) => (
      hasOwn(params, name) ? String(params[name]) : match
    ));
  }

  // Plural-aware lookup: baseKey_one / _few / _many / _other.
  function tp(baseKey, count, params) {
    const form = pluralRules ? pluralRules.select(count) : (count === 1 ? 'one' : 'other');
    const values = Object.assign({ count: formatNumber(count) }, params);
    const formKey = baseKey + '_' + form;
    return t(hasOwn(I18N, formKey) ? formKey : baseKey + '_other', values);
  }

  function applyStaticI18n() {
    document.querySelectorAll('[data-i18n]').forEach((node) => {
      const key = node.getAttribute('data-i18n');
      if (hasOwn(I18N, key)) {
        node.textContent = t(key);
      }
    });
  }

  // ---------- Formatting ----------

  function formatNumber(value, maxFractionDigits) {
    try {
      return new Intl.NumberFormat(LANG, {
        maximumFractionDigits: maxFractionDigits || 0,
      }).format(value);
    } catch (error) {
      const factor = Math.pow(10, maxFractionDigits || 0);
      return String(Math.round(value * factor) / factor);
    }
  }

  function formatBytes(bytes) {
    if (typeof bytes !== 'number' || !isFinite(bytes) || bytes < 0) {
      return '';
    }
    let value = bytes;
    let unit = 0;
    while (value >= 1000 && unit < BYTE_UNITS.length - 1) {
      value /= 1000;
      unit += 1;
    }
    const digits = unit === 0 || value >= 10 ? 0 : 1;
    try {
      return new Intl.NumberFormat(LANG, {
        style: 'unit',
        unit: BYTE_UNITS[unit],
        unitDisplay: 'short',
        maximumFractionDigits: digits,
      }).format(value);
    } catch (error) {
      return formatNumber(value, digits) + '\u00a0' + BYTE_LABELS[unit];
    }
  }

  function formatPercent(fraction) {
    try {
      return new Intl.NumberFormat(LANG, {
        style: 'percent',
        maximumFractionDigits: 0,
      }).format(fraction);
    } catch (error) {
      return Math.round(fraction * 100) + '%';
    }
  }

  function summaryLine(count, bytes, pluralKey) {
    const items = tp(pluralKey, count);
    if (bytes === null || bytes === undefined) {
      return items;
    }
    return t('summary_line', { items: items, size: formatBytes(bytes) });
  }

  // ---------- DOM helpers (text only, never innerHTML) ----------

  function el(tag, props, children) {
    const node = document.createElement(tag);
    if (props) {
      Object.keys(props).forEach((key) => {
        const value = props[key];
        if (value === null || value === undefined || value === false) {
          return;
        }
        if (key === 'class') {
          node.className = value;
        } else if (key === 'text') {
          node.textContent = value;
        } else if (key.indexOf('on') === 0 && typeof value === 'function') {
          node.addEventListener(key.slice(2), value);
        } else if (value === true) {
          node.setAttribute(key, '');
        } else {
          node.setAttribute(key, String(value));
        }
      });
    }
    appendChildren(node, children);
    return node;
  }

  function appendChildren(node, children) {
    if (children === null || children === undefined || children === false) {
      return;
    }
    if (Array.isArray(children)) {
      children.forEach((child) => appendChildren(node, child));
      return;
    }
    if (typeof children === 'string' || typeof children === 'number') {
      node.appendChild(document.createTextNode(String(children)));
      return;
    }
    node.appendChild(children);
  }

  function clear(node) {
    while (node.firstChild) {
      node.removeChild(node.firstChild);
    }
  }

  function icon(name, extraClass) {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '2');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('focusable', 'false');
    svg.setAttribute('class', extraClass ? 'icon ' + extraClass : 'icon');
    (ICONS[name] || ICONS.files).forEach((d) => {
      const path = document.createElementNS(SVG_NS, 'path');
      path.setAttribute('d', d);
      svg.appendChild(path);
    });
    return svg;
  }

  function announce(message) {
    if (!live) {
      return;
    }
    live.textContent = '';
    window.setTimeout(() => {
      live.textContent = message;
    }, 60);
  }

  function beginView() {
    viewToken += 1;
    window.clearTimeout(pollTimer);
    pollTimer = null;
    return viewToken;
  }

  function renderView(name, nodes, focusHeading) {
    currentView = name;
    clear(app);
    appendChildren(app, nodes);
    window.scrollTo(0, 0);
    if (!focusHeading) {
      return;
    }
    const heading = app.querySelector('h1');
    if (heading) {
      try {
        heading.focus({ preventScroll: true });
      } catch (error) {
        heading.focus();
      }
    }
  }

  function button(label, variant, onClick, iconName) {
    return el('button', {
      type: 'button',
      class: 'btn btn-block ' + variant,
      onclick: () => onClick(),
    }, [iconName ? icon(iconName) : null, el('span', { text: label })]);
  }

  function downloadLink(url, label, variant, fileName) {
    return el('a', {
      class: 'btn btn-block ' + variant,
      href: url,
      download: fileName || '',
    }, [icon('download'), el('span', { text: label })]);
  }

  function statusCard(options) {
    const visual = options.spinner
      ? el('div', { class: 'spinner', 'aria-hidden': 'true' })
      : el('div', {
        class: 'icon-circle icon-circle--lg' + (options.tone ? ' icon-circle--' + options.tone : ''),
      }, icon(options.icon));
    return el('section', { class: 'card card--center' }, [
      visual,
      el('div', { class: 'stack' }, [
        el('h1', { class: 'title', tabindex: '-1', text: options.title }),
        options.text ? el('p', { class: 'subtitle', text: options.text }) : null,
      ]),
      options.extra || null,
      options.actions || null,
    ]);
  }

  // ---------- API ----------

  class ApiError extends Error {
    constructor(kind, status, body) {
      super('API error: ' + kind + ' (' + status + ')');
      this.kind = kind;
      this.status = status;
      this.body = body;
    }
  }

  function parseJson(text) {
    if (!text) {
      return null;
    }
    try {
      return JSON.parse(text);
    } catch (error) {
      return null;
    }
  }

  // Maps an HTTP status to an error kind; null means success.
  function classifyStatus(status, body) {
    if (status >= 200 && status < 300) {
      return null;
    }
    if (status === 0) {
      return 'network';
    }
    if (status === 403) {
      return 'not_approved';
    }
    if (status === 410) {
      return 'stopped';
    }
    if (status === 507 || (isPlainObject(body) && body.error === 'insufficient_space')) {
      return 'insufficient_space';
    }
    return 'http';
  }

  async function apiRequest(path, options) {
    const init = Object.assign({
      method: 'GET',
      cache: 'no-store',
      credentials: 'same-origin',
    }, options);
    init.headers = Object.assign({ Accept: 'application/json' }, options && options.headers);

    let response;
    try {
      response = await fetch(CONFIG.base + path, init);
    } catch (error) {
      throw new ApiError('network', 0, null);
    }

    let text = '';
    try {
      text = await response.text();
    } catch (error) {
      throw new ApiError('network', response.status, null);
    }

    const body = parseJson(text);
    const kind = classifyStatus(response.status, body);
    if (kind) {
      throw new ApiError(kind, response.status, body);
    }
    return { status: response.status, body: body };
  }

  function handleApiError(error, retry) {
    const kind = error && error.kind;
    if (kind === 'not_approved') {
      gateBounces += 1;
      startGate(gateBounces > 1 ? POLL_INTERVAL_MS : 0);
      return;
    }
    if (kind === 'stopped') {
      renderStopped();
      return;
    }
    if (kind === 'network') {
      renderNetworkError(retry);
      return;
    }
    if (!(error instanceof ApiError)) {
      console.error(error);
    }
    renderGenericError(error && error.status, retry);
  }

  // ---------- Shared state views ----------

  function renderLoadingView() {
    renderView('loading', statusCard({ spinner: true, title: t('loading') }), false);
  }

  function showPending() {
    if (currentView === 'pending') {
      return;
    }
    renderView('pending', statusCard({
      spinner: true,
      title: t('gate_pending_title'),
      text: t('gate_pending_text'),
    }), true);
    announce(t('gate_pending_title'));
  }

  function renderDenied() {
    beginView();
    renderView('denied', statusCard({
      icon: 'lock',
      tone: 'error',
      title: t('gate_denied_title'),
      text: t('gate_denied_text'),
    }), true);
    announce(t('gate_denied_title'));
  }

  function renderStopped() {
    beginView();
    uploadState.uploading = false;
    renderView('stopped', statusCard({
      icon: 'power',
      title: t('gate_stopped_title'),
      text: t('gate_stopped_text'),
    }), true);
    announce(t('gate_stopped_title'));
  }

  function renderNetworkError(retry) {
    beginView();
    const retryAction = retry || (() => startGate());
    renderView('network', statusCard({
      icon: 'wifiOff',
      tone: 'warning',
      title: t('error_network_title'),
      text: t('error_network_text'),
      actions: button(t('btn_retry'), 'btn-primary', retryAction, 'refresh'),
    }), true);
    announce(t('error_network_inline'));
  }

  function renderGenericError(status, retry) {
    beginView();
    const retryAction = retry || (() => startGate());
    renderView('error', statusCard({
      icon: 'alert',
      tone: 'error',
      title: t('error_generic_title'),
      text: t('error_generic_text'),
      extra: status ? el('p', { class: 'small', text: t('error_code', { status: status }) }) : null,
      actions: button(t('btn_retry'), 'btn-primary', retryAction, 'refresh'),
    }), true);
    announce(t('error_generic_title'));
  }

  // ---------- Approval gate ----------

  function startGate(delayMs) {
    const token = beginView();
    if (currentView !== 'pending') {
      renderLoadingView();
    }
    if (delayMs) {
      schedulePoll(token, 0, delayMs);
    } else {
      pollStatus(token, 0);
    }
  }

  function schedulePoll(token, failures, delayMs) {
    window.clearTimeout(pollTimer);
    pollTimer = window.setTimeout(() => {
      if (token === viewToken) {
        pollStatus(token, failures);
      }
    }, delayMs || POLL_INTERVAL_MS);
  }

  async function pollStatus(token, failures) {
    let response;
    try {
      response = await apiRequest('/api/status');
    } catch (error) {
      if (token !== viewToken) {
        return;
      }
      if (error.kind === 'not_approved') {
        showPending();
        schedulePoll(token, 0);
        return;
      }
      if (error.kind === 'network' && failures < STATUS_RETRY_LIMIT) {
        schedulePoll(token, failures + 1);
        return;
      }
      handleApiError(error, () => startGate());
      return;
    }

    if (token !== viewToken) {
      return;
    }
    const body = isPlainObject(response.body) ? response.body : {};
    const name = cleanName(body.deviceName);
    if (name) {
      deviceName = name;
    }

    switch (body.state) {
      case 'approved':
        openModeView(body.mode);
        break;
      case 'denied':
        renderDenied();
        break;
      case 'stopped':
        renderStopped();
        break;
      default:
        showPending();
        schedulePoll(token, 0);
        break;
    }
  }

  function openModeView(statusMode) {
    const mode = CONFIG.mode === 'upload' || CONFIG.mode === 'download' ? CONFIG.mode : statusMode;
    if (mode === 'upload') {
      renderUpload();
    } else {
      loadManifest();
    }
  }

  // ---------- Code entry ----------

  function renderCode() {
    beginView();
    const locked = CONFIG.error === 'locked';
    let initialError = null;
    if (locked) {
      initialError = 'code_error_locked';
    } else if (CONFIG.error === 'wrong_code') {
      initialError = 'code_error_wrong';
    }

    const errorText = el('span');
    const errorBox = el('p', {
      id: 'st-code-error',
      class: 'alert alert--error',
      role: 'alert',
      hidden: true,
    }, [icon('alert'), errorText]);

    const input = el('input', {
      id: 'st-code-input',
      class: 'code-input',
      type: 'text',
      name: 'code',
      inputmode: 'numeric',
      pattern: '[0-9]{6}',
      maxlength: '6',
      autocomplete: 'one-time-code',
      autocorrect: 'off',
      autocapitalize: 'off',
      spellcheck: 'false',
      enterkeyhint: 'go',
      placeholder: '000000',
      required: true,
      disabled: locked,
    });

    const submit = el('button', {
      type: 'submit',
      class: 'btn btn-primary btn-block',
      disabled: locked,
    }, t('code_continue'));

    const showError = (key) => {
      errorText.textContent = t(key);
      errorBox.hidden = false;
      input.setAttribute('aria-invalid', 'true');
      input.setAttribute('aria-describedby', 'st-code-error');
    };

    const hideError = () => {
      errorBox.hidden = true;
      input.removeAttribute('aria-invalid');
      input.removeAttribute('aria-describedby');
    };

    input.addEventListener('input', () => {
      const digits = input.value.replace(/\D+/g, '').slice(0, 6);
      if (digits !== input.value) {
        input.value = digits;
      }
      if (!locked && !errorBox.hidden) {
        hideError();
      }
    });

    const form = el('form', {
      class: 'code-form',
      method: 'get',
      action: '/c',
      novalidate: true,
    }, [
      el('label', { class: 'visually-hidden', for: 'st-code-input', text: t('code_label') }),
      input,
      errorBox,
      submit,
    ]);

    form.addEventListener('submit', (event) => {
      if (locked) {
        event.preventDefault();
        return;
      }
      if (!/^[0-9]{6}$/.test(input.value)) {
        event.preventDefault();
        showError('code_error_format');
        input.focus();
      }
    });

    renderView('code', el('section', { class: 'card card--center' }, [
      el('div', { class: 'icon-circle icon-circle--lg' }, icon('phone')),
      el('div', { class: 'stack' }, [
        el('h1', { class: 'title', tabindex: '-1', text: t('code_title') }),
        el('p', { class: 'subtitle', text: t('code_subtitle') }),
      ]),
      form,
      el('p', { class: 'small', text: t('code_hint') }),
    ]), false);

    if (initialError) {
      showError(initialError);
    }
    if (!locked && initialError) {
      input.focus();
    }
  }

  // ---------- Download mode (iPhone -> Android) ----------

  function toSize(value) {
    return typeof value === 'number' && isFinite(value) && value >= 0 ? value : null;
  }

  function toCount(value, fallback) {
    return typeof value === 'number' && isFinite(value) && value >= 0 ? Math.floor(value) : fallback;
  }

  function fileNameFromPath(path) {
    if (typeof path !== 'string') {
      return '';
    }
    const parts = path.split('/');
    return parts[parts.length - 1] || path;
  }

  // Accepts only same-origin URLs and returns them as a root-relative path.
  function safeUrl(value) {
    if (typeof value !== 'string' || !value) {
      return null;
    }
    try {
      const url = new URL(value, window.location.href);
      if (url.origin !== window.location.origin) {
        return null;
      }
      return url.pathname + url.search + url.hash;
    } catch (error) {
      return null;
    }
  }

  function normalizeFile(file) {
    return {
      name: (typeof file.name === 'string' && file.name) || fileNameFromPath(file.path),
      path: typeof file.path === 'string' ? file.path : '',
      size: toSize(file.size),
      url: safeUrl(file.url),
    };
  }

  function normalizeCategory(category) {
    const files = (Array.isArray(category.files) ? category.files : [])
      .filter(isPlainObject)
      .map(normalizeFile);
    return {
      id: typeof category.id === 'string' ? category.id : 'files',
      count: toCount(category.count, files.length),
      bytes: toSize(category.bytes),
      zipUrl: safeUrl(category.zipUrl),
      files: files,
    };
  }

  function normalizeManifest(raw) {
    const source = isPlainObject(raw) ? raw : {};
    const categories = (Array.isArray(source.categories) ? source.categories : [])
      .filter(isPlainObject)
      .map(normalizeCategory);
    const name = cleanName(source.deviceName);
    if (name) {
      deviceName = name;
    }
    const countSum = categories.reduce((sum, category) => sum + category.count, 0);
    return {
      totalCount: toCount(source.totalCount, countSum),
      totalBytes: toSize(source.totalBytes),
      allZipUrl: safeUrl(source.allZipUrl),
      categories: categories,
    };
  }

  async function loadManifest() {
    const token = beginView();
    renderLoadingView();
    let response;
    try {
      response = await apiRequest('/api/manifest');
    } catch (error) {
      if (token === viewToken) {
        handleApiError(error, loadManifest);
      }
      return;
    }
    if (token !== viewToken) {
      return;
    }
    gateBounces = 0;
    renderDownload(normalizeManifest(response.body));
  }

  function renderDownload(manifest) {
    beginView();

    if (manifest.totalCount === 0 || manifest.categories.length === 0) {
      renderView('download', statusCard({
        icon: 'download',
        title: t('download_empty_title'),
        text: t('download_empty_text'),
        actions: button(t('btn_retry'), 'btn-secondary', loadManifest, 'refresh'),
      }), true);
      return;
    }

    const hero = el('section', { class: 'card hero' }, [
      el('div', { class: 'stack stack--tight' }, [
        el('h1', { class: 'title', tabindex: '-1', text: t('download_title', { name: deviceName }) }),
        el('p', {
          class: 'subtitle',
          text: summaryLine(manifest.totalCount, manifest.totalBytes, 'n_items'),
        }),
      ]),
      manifest.allZipUrl
        ? downloadLink(manifest.allZipUrl, t('download_all'), 'btn-primary')
        : null,
      manifest.allZipUrl
        ? el('p', { class: 'hint' }, [icon('info'), el('span', { text: t('download_all_note') })])
        : null,
    ]);

    const footer = el('section', { class: 'card card--note' }, [
      el('ul', { class: 'note-list' }, [
        el('li', {}, [icon('phone'), el('span', { text: t('download_keep_open') })]),
        el('li', {}, [icon('refresh'), el('span', { text: t('download_resume_tip') })]),
      ]),
    ]);

    renderView('download', [
      hero,
      manifest.categories.map(renderCategory),
      footer,
    ], true);
  }

  function renderCategory(category) {
    const meta = CATEGORY_META[category.id] || CATEGORY_META.files;
    listCounter += 1;
    const headingId = 'st-cat-' + listCounter;

    const metaParts = [tp('n_items', category.count)];
    if (category.bytes !== null) {
      metaParts.push(formatBytes(category.bytes));
    }

    const head = el('div', { class: 'cat-head' }, [
      el('div', { class: 'icon-circle' }, icon(meta.icon)),
      el('div', { class: 'cat-head__text' }, [
        el('h2', { class: 'cat-title', id: headingId, text: t(meta.title) }),
        el('p', { class: 'small', text: metaParts.join(' \u00b7 ') }),
      ]),
    ]);

    const actions = el('div', { class: 'cat-actions' });
    const showDirectLinks = DIRECT_LINK_CATEGORIES.indexOf(category.id) >= 0
      && category.files.length > 0
      && category.files.length <= DIRECT_LINK_MAX_FILES;
    if (showDirectLinks) {
      category.files.forEach((file) => {
        if (file.url) {
          actions.appendChild(downloadLink(
            file.url,
            t('download_file', { name: file.name }),
            'btn-primary',
            file.name
          ));
        }
      });
    }
    if (category.zipUrl) {
      actions.appendChild(downloadLink(category.zipUrl, t(meta.zip), 'btn-secondary'));
    }

    const hint = el('p', { class: 'hint' }, [
      icon('info'),
      el('span', {}, [
        el('strong', { class: 'hint__title', text: t('import_title') }),
        t(meta.hint),
      ]),
    ]);

    return el('section', { class: 'card', 'aria-labelledby': headingId }, [
      head,
      actions.firstChild ? actions : null,
      category.files.length > 0 ? createFileList(category.files) : null,
      hint,
    ]);
  }

  // Collapsible, paginated file list: rows are created lazily, PAGE_SIZE at a time.
  function createFileList(files) {
    listCounter += 1;
    const listId = 'st-files-' + listCounter;
    const list = el('ul', { class: 'file-list' });
    const more = el('button', {
      type: 'button',
      class: 'btn btn-secondary btn-small btn-block',
      hidden: true,
    });
    const wrap = el('div', { class: 'file-list-wrap', id: listId, hidden: true }, [list, more]);
    const showLabel = t('show_files', { count: formatNumber(files.length) });
    const label = el('span', { text: showLabel });
    const toggle = el('button', {
      type: 'button',
      class: 'btn btn-text toggle',
      'aria-expanded': 'false',
      'aria-controls': listId,
    }, [label, icon('chevron')]);

    let rendered = 0;
    const renderNextPage = () => {
      const end = Math.min(files.length, rendered + PAGE_SIZE);
      const fragment = document.createDocumentFragment();
      for (let index = rendered; index < end; index += 1) {
        fragment.appendChild(fileRow(files[index]));
      }
      list.appendChild(fragment);
      rendered = end;
      const remaining = files.length - rendered;
      more.hidden = remaining <= 0;
      more.textContent = t('show_more', { count: formatNumber(remaining) });
    };

    more.addEventListener('click', renderNextPage);
    toggle.addEventListener('click', () => {
      const expand = toggle.getAttribute('aria-expanded') !== 'true';
      if (expand && rendered === 0) {
        renderNextPage();
      }
      wrap.hidden = !expand;
      toggle.setAttribute('aria-expanded', String(expand));
      label.textContent = expand ? t('hide_files') : showLabel;
    });

    return [toggle, wrap];
  }

  function fileRow(file) {
    const main = el('div', { class: 'file-row__main' }, [
      el('span', { class: 'file-row__name', title: file.path || file.name, text: file.name }),
      file.size !== null ? el('span', { class: 'file-row__size', text: formatBytes(file.size) }) : null,
    ]);
    const action = file.url
      ? el('a', {
        class: 'btn btn-icon',
        href: file.url,
        download: file.name,
        'aria-label': t('download_file', { name: file.name }),
      }, icon('download'))
      : null;
    return el('li', { class: 'file-row' }, [main, action]);
  }

  // ---------- Upload mode (Android -> iPhone) ----------

  function fileKey(file) {
    return [file.name, file.size, file.lastModified].join('|');
  }

  function whereItem(iconName, key) {
    return el('li', {}, [
      el('span', { class: 'icon-circle' }, icon(iconName)),
      el('span', { text: t(key) }),
    ]);
  }

  function tip(titleKey, textKey) {
    return el('details', { class: 'tip' }, [
      el('summary', {}, [el('span', { text: t(titleKey) }), icon('chevron')]),
      el('p', { class: 'tip__body', text: t(textKey) }),
    ]);
  }

  function renderUpload() {
    beginView();
    const ui = { rows: new Map(), lastPercent: -1 };

    ui.input = el('input', {
      id: 'st-file-input',
      class: 'visually-hidden',
      type: 'file',
      multiple: true,
    });
    ui.input.addEventListener('change', () => {
      addFiles(Array.prototype.slice.call(ui.input.files || []), ui);
      ui.input.value = '';
    });

    ui.dropzone = el('label', { class: 'dropzone', for: 'st-file-input' }, [
      ui.input,
      el('span', { class: 'dropzone__icon' }, icon('upload')),
      el('span', { class: 'dropzone__title', text: t('upload_choose') }),
      el('span', { class: 'dropzone__hint', text: t('upload_choose_hint') }),
    ]);
    attachDropHandlers(ui);

    ui.summary = el('p', { class: 'small' });
    ui.clearButton = el('button', {
      type: 'button',
      class: 'btn btn-text',
      onclick: () => clearSelection(ui),
    }, t('upload_clear'));
    ui.list = el('ul', { class: 'file-list' });
    ui.moreButton = el('button', {
      type: 'button',
      class: 'btn btn-secondary btn-small btn-block',
      hidden: true,
      onclick: () => {
        uploadState.visibleCount += PAGE_SIZE;
        renderSelection(ui);
      },
    });
    ui.selected = el('div', { class: 'stack', hidden: true }, [
      el('div', { class: 'selected-head' }, [
        el('div', { class: 'stack stack--tight' }, [
          el('h2', { class: 'selected-head__title', text: t('upload_selected_title') }),
          ui.summary,
        ]),
        ui.clearButton,
      ]),
      ui.list,
      ui.moreButton,
    ]);

    ui.alert = el('div', { hidden: true });

    ui.progressLabel = el('span', { class: 'progress-block__label', id: 'st-progress-label' });
    ui.progressPercent = el('span', { class: 'progress-block__percent' });
    ui.progressFill = el('div', { class: 'progress__fill' });
    ui.progressBar = el('div', {
      class: 'progress',
      role: 'progressbar',
      'aria-labelledby': 'st-progress-label',
      'aria-valuemin': '0',
      'aria-valuemax': '100',
      'aria-valuenow': '0',
    }, ui.progressFill);
    ui.progress = el('div', { class: 'progress-block', hidden: true }, [
      el('div', { class: 'row row--between' }, [ui.progressLabel, ui.progressPercent]),
      ui.progressBar,
    ]);

    ui.sendIcon = icon('send');
    ui.sendSpinner = el('span', { class: 'spinner spinner--small', 'aria-hidden': 'true', hidden: true });
    ui.sendLabel = el('span', { text: t('upload_send') });
    ui.sendButton = el('button', {
      type: 'button',
      class: 'btn btn-primary btn-block',
      onclick: () => startUpload(ui),
    }, [ui.sendIcon, ui.sendSpinner, ui.sendLabel]);

    const intro = el('section', { class: 'card' }, [
      el('div', { class: 'stack' }, [
        el('h1', { class: 'title', tabindex: '-1', text: t('upload_title', { name: deviceName }) }),
        el('p', { class: 'subtitle', text: t('upload_subtitle') }),
      ]),
      el('ul', { class: 'where-list' }, [
        whereItem('photos', 'upload_where_media'),
        whereItem('contacts', 'upload_where_contacts'),
        whereItem('calendar', 'upload_where_calendar'),
        whereItem('files', 'upload_where_files'),
      ]),
    ]);

    const picker = el('section', { class: 'card' }, [
      ui.dropzone,
      ui.selected,
      ui.alert,
      ui.progress,
      ui.sendButton,
    ]);

    const tips = el('section', { class: 'card' }, [
      el('div', { class: 'tips' }, [
        tip('tip_contacts_title', 'tip_contacts_text'),
        tip('tip_calendar_title', 'tip_calendar_text'),
      ]),
    ]);

    const note = el('section', { class: 'card card--note' }, [
      el('ul', { class: 'note-list' }, [
        el('li', {}, [icon('phone'), el('span', { text: t('upload_keep_open') })]),
      ]),
    ]);

    renderView('upload', [intro, picker, tips, note], true);
    renderSelection(ui);
  }

  function attachDropHandlers(ui) {
    const zone = ui.dropzone;
    zone.addEventListener('dragover', (event) => {
      event.preventDefault();
      if (!uploadState.uploading) {
        zone.classList.add('is-dragover');
      }
    });
    zone.addEventListener('dragleave', () => {
      zone.classList.remove('is-dragover');
    });
    zone.addEventListener('drop', (event) => {
      event.preventDefault();
      zone.classList.remove('is-dragover');
      const files = event.dataTransfer && event.dataTransfer.files;
      if (files && files.length) {
        addFiles(Array.prototype.slice.call(files), ui);
      }
    });
  }

  function addFiles(files, ui) {
    if (uploadState.uploading) {
      return;
    }
    const known = new Set(uploadState.items.map((item) => fileKey(item.file)));
    files.forEach((file) => {
      const key = fileKey(file);
      if (known.has(key)) {
        return;
      }
      known.add(key);
      uploadState.items.push({ id: uploadState.nextId, file: file, status: 'waiting' });
      uploadState.nextId += 1;
    });
    hideAlert(ui);
    renderSelection(ui);
  }

  function removeItem(id, ui) {
    if (uploadState.uploading) {
      return;
    }
    uploadState.items = uploadState.items.filter((item) => item.id !== id);
    renderSelection(ui);
  }

  function clearSelection(ui) {
    if (uploadState.uploading) {
      return;
    }
    uploadState.items = [];
    uploadState.visibleCount = PAGE_SIZE;
    hideAlert(ui);
    renderSelection(ui);
  }

  function renderSelection(ui) {
    const items = uploadState.items;
    ui.rows = new Map();
    clear(ui.list);
    ui.selected.hidden = items.length === 0;

    const totalBytes = items.reduce((sum, item) => sum + item.file.size, 0);
    ui.summary.textContent = summaryLine(items.length, totalBytes, 'n_files');

    const visible = Math.min(items.length, uploadState.visibleCount);
    const fragment = document.createDocumentFragment();
    for (let index = 0; index < visible; index += 1) {
      fragment.appendChild(selectionRow(items[index], ui));
    }
    ui.list.appendChild(fragment);

    const remaining = items.length - visible;
    ui.moreButton.hidden = remaining <= 0;
    ui.moreButton.textContent = t('show_more', { count: formatNumber(remaining) });
    updateControls(ui);
  }

  function selectionRow(item, ui) {
    const status = el('span', { class: 'status-icon', role: 'img' });
    const removeButton = el('button', {
      type: 'button',
      class: 'btn btn-icon',
      'aria-label': t('upload_remove', { name: item.file.name }),
      onclick: () => removeItem(item.id, ui),
    }, icon('close'));
    const refs = { status: status, removeButton: removeButton };
    ui.rows.set(item.id, refs);
    paintStatus(item, refs);

    return el('li', { class: 'file-row' }, [
      status,
      el('div', { class: 'file-row__main' }, [
        el('span', { class: 'file-row__name', text: item.file.name }),
        el('span', { class: 'file-row__size', text: formatBytes(item.file.size) }),
      ]),
      removeButton,
    ]);
  }

  function paintStatus(item, refs) {
    refs.status.className = 'status-icon status-icon--' + item.status;
    refs.status.setAttribute('aria-label', t(UPLOAD_STATUS_LABELS[item.status]));
    clear(refs.status);
    if (item.status === 'sending') {
      refs.status.appendChild(el('span', { class: 'spinner spinner--small', 'aria-hidden': 'true' }));
    } else {
      refs.status.appendChild(icon(UPLOAD_STATUS_ICONS[item.status]));
    }
    refs.removeButton.disabled = uploadState.uploading;
  }

  function setItemStatus(item, status, ui) {
    item.status = status;
    const refs = ui.rows.get(item.id);
    if (refs) {
      paintStatus(item, refs);
    }
  }

  function updateControls(ui) {
    const busy = uploadState.uploading;
    ui.input.disabled = busy;
    ui.dropzone.classList.toggle('is-disabled', busy);
    ui.clearButton.disabled = busy;
    ui.moreButton.disabled = false;
    ui.rows.forEach((refs) => {
      refs.removeButton.disabled = busy;
    });
    ui.sendButton.disabled = busy;
    ui.sendIcon.style.display = busy ? 'none' : '';
    ui.sendSpinner.hidden = !busy;
    ui.sendLabel.textContent = busy ? t('upload_sending') : t('upload_send');
  }

  function setUploading(ui, value) {
    uploadState.uploading = value;
    updateControls(ui);
  }

  function stopUploading(ui) {
    setUploading(ui, false);
    ui.progress.hidden = true;
  }

  function showProgress(ui, label, fraction) {
    ui.progress.hidden = false;
    ui.progressLabel.textContent = label;
    updateProgress(ui, fraction);
  }

  function updateProgress(ui, fraction) {
    const clamped = Math.max(0, Math.min(1, fraction || 0));
    const percent = Math.round(clamped * 100);
    if (percent === ui.lastPercent) {
      return;
    }
    ui.lastPercent = percent;
    ui.progressFill.style.width = percent + '%';
    ui.progressBar.setAttribute('aria-valuenow', String(percent));
    ui.progressPercent.textContent = formatPercent(percent / 100);
  }

  function showAlert(ui, tone, message, action) {
    clear(ui.alert);
    const body = el('div', { class: 'alert__body' }, el('span', { text: message }));
    if (action) {
      body.appendChild(el('button', {
        type: 'button',
        class: 'btn btn-secondary btn-small',
        onclick: () => action.onClick(),
      }, action.label));
    }
    ui.alert.appendChild(el('div', {
      class: 'alert alert--' + tone,
      role: tone === 'error' ? 'alert' : 'status',
    }, [icon(tone === 'error' ? 'alert' : 'info'), body]));
    ui.alert.hidden = false;
  }

  function hideAlert(ui) {
    clear(ui.alert);
    ui.alert.hidden = true;
  }

  function showNoSpace(ui, body) {
    const free = isPlainObject(body) ? toSize(body.freeBytes) : null;
    showAlert(ui, 'error', t('upload_no_space', { size: free === null ? '\u2014' : formatBytes(free) }));
  }

  function handleUploadError(error, ui) {
    const kind = error && error.kind;
    if (kind === 'insufficient_space') {
      showNoSpace(ui, error.body);
      return;
    }
    if (kind === 'network') {
      showAlert(ui, 'error', t('error_network_inline'));
      return;
    }
    if (kind === 'not_approved' || kind === 'stopped') {
      handleApiError(error);
      return;
    }
    if (!(error instanceof ApiError)) {
      console.error(error);
    }
    const status = error && error.status;
    const suffix = status ? ' ' + t('error_code', { status: status }) : '';
    showAlert(ui, 'error', t('error_generic_text') + suffix);
  }

  // Sends one file per request with XMLHttpRequest (for upload progress).
  function uploadFile(file, onProgress) {
    return new Promise((resolve) => {
      const xhr = new XMLHttpRequest();
      xhr.open('POST', CONFIG.base + '/api/upload', true);
      xhr.setRequestHeader('Accept', 'application/json');
      xhr.upload.addEventListener('progress', (event) => {
        if (event.lengthComputable && event.total > 0) {
          onProgress(Math.min(1, event.loaded / event.total) * file.size);
        }
      });
      xhr.addEventListener('load', () => {
        const body = parseJson(xhr.responseText);
        const kind = classifyStatus(xhr.status, body);
        resolve({ kind: kind || 'ok', status: xhr.status, body: body });
      });
      xhr.addEventListener('error', () => resolve({ kind: 'network', status: 0, body: null }));
      xhr.addEventListener('timeout', () => resolve({ kind: 'network', status: 0, body: null }));
      xhr.addEventListener('abort', () => resolve({ kind: 'network', status: 0, body: null }));

      const form = new FormData();
      form.append('file', file, file.name);
      xhr.send(form);
    });
  }

  async function uploadWithRetry(file, onProgress) {
    let result = await uploadFile(file, onProgress);
    if (result.kind === 'network' || result.kind === 'http') {
      onProgress(0);
      result = await uploadFile(file, onProgress);
    }
    return result;
  }

  async function startUpload(ui) {
    if (uploadState.uploading) {
      return;
    }
    hideAlert(ui);
    const queue = uploadState.items.filter((item) => item.status !== 'done');
    if (queue.length === 0) {
      showAlert(ui, 'error', t('upload_empty_error'));
      return;
    }

    const token = viewToken;
    const totalBytes = queue.reduce((sum, item) => sum + item.file.size, 0);
    const progressFor = (bytes, filesDone) => (
      totalBytes > 0 ? bytes / totalBytes : filesDone / queue.length
    );

    setUploading(ui, true);
    queue.forEach((item) => setItemStatus(item, 'waiting', ui));
    ui.lastPercent = -1;
    showProgress(ui, t('upload_checking'), 0);
    announce(t('upload_checking'));

    try {
      const plan = await apiRequest('/api/upload-plan', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ count: queue.length, bytes: totalBytes }),
      });
      if (isPlainObject(plan.body) && plan.body.ok === false) {
        throw new ApiError('http', plan.status, plan.body);
      }
    } catch (error) {
      stopUploading(ui);
      if (token === viewToken) {
        handleUploadError(error, ui);
      }
      return;
    }
    gateBounces = 0;

    let bytesDone = 0;
    let sent = 0;
    let failed = 0;
    let networkStreak = 0;

    for (let index = 0; index < queue.length; index += 1) {
      if (token !== viewToken) {
        uploadState.uploading = false;
        return;
      }
      const item = queue[index];
      const label = t('upload_progress', {
        current: formatNumber(index + 1),
        total: formatNumber(queue.length),
      });
      showProgress(ui, label, progressFor(bytesDone, index));
      setItemStatus(item, 'sending', ui);

      const result = await uploadWithRetry(item.file, (loaded) => {
        updateProgress(ui, progressFor(bytesDone + loaded, index));
      });
      if (token !== viewToken) {
        uploadState.uploading = false;
        return;
      }

      if (result.kind === 'ok') {
        setItemStatus(item, 'done', ui);
        sent += 1;
        networkStreak = 0;
      } else if (result.kind === 'insufficient_space') {
        setItemStatus(item, 'failed', ui);
        stopUploading(ui);
        showNoSpace(ui, result.body);
        return;
      } else if (result.kind === 'not_approved' || result.kind === 'stopped') {
        setItemStatus(item, 'waiting', ui);
        stopUploading(ui);
        handleApiError(new ApiError(result.kind, result.status, result.body));
        return;
      } else {
        setItemStatus(item, 'failed', ui);
        failed += 1;
        networkStreak = result.kind === 'network' ? networkStreak + 1 : 0;
        if (networkStreak >= MAX_NETWORK_FAILURE_STREAK) {
          stopUploading(ui);
          showAlert(ui, 'error', t('error_network_inline'));
          return;
        }
      }

      bytesDone += item.file.size;
      updateProgress(ui, progressFor(bytesDone, index + 1));
    }

    await finishUpload(ui, token, sent, failed);
  }

  async function finishUpload(ui, token, sent, failed) {
    if (sent === 0) {
      stopUploading(ui);
      showAlert(ui, 'error', t('upload_all_failed'));
      return;
    }

    setUploading(ui, true);
    showProgress(ui, t('upload_finishing'), 1);
    try {
      await apiRequest('/api/upload-finish', { method: 'POST' });
    } catch (error) {
      stopUploading(ui);
      if (token !== viewToken) {
        return;
      }
      if (error.kind === 'network' || error.kind === 'http') {
        const message = error.kind === 'network' ? t('error_network_inline') : t('error_generic_text');
        showAlert(ui, 'error', message, {
          label: t('btn_retry'),
          onClick: () => {
            hideAlert(ui);
            finishUpload(ui, viewToken, sent, failed);
          },
        });
        return;
      }
      handleUploadError(error, ui);
      return;
    }

    uploadState.uploading = false;
    if (token === viewToken) {
      renderUploadDone(sent, failed);
    }
  }

  function renderUploadDone(sent, failed) {
    beginView();
    uploadState.items = [];
    uploadState.visibleCount = PAGE_SIZE;

    const title = t('upload_done_title');
    const text = tp('upload_done_text', sent);
    const warning = failed > 0
      ? el('p', { class: 'alert alert--warning' }, [
        icon('alert'),
        el('span', { text: t('upload_failed_count', { count: formatNumber(failed) }) }),
      ])
      : null;

    renderView('upload-done', statusCard({
      icon: 'check',
      tone: 'success',
      title: title,
      text: text,
      extra: warning,
      actions: button(t('upload_send_more'), 'btn-primary', renderUpload, 'upload'),
    }), true);
    announce(title + ' ' + text);
  }

  // ---------- Startup ----------

  function onBeforeUnload(event) {
    if (!uploadState.uploading) {
      return undefined;
    }
    const message = t('upload_leave_warning');
    event.preventDefault();
    event.returnValue = message;
    return message;
  }

  function onPageShow(event) {
    // Returning from the back/forward cache: re-check the session state.
    if (event.persisted && CONFIG.mode !== 'code' && !uploadState.uploading) {
      startGate();
    }
  }

  function init() {
    applyStaticI18n();
    window.addEventListener('beforeunload', onBeforeUnload);
    window.addEventListener('pageshow', onPageShow);
    if (CONFIG.mode === 'code') {
      renderCode();
      return;
    }
    startGate();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();

/**
 * BM Exam - Web Kiosk Mode
 * Bekerja di Chrome, Edge, Safari (Android & Desktop)
 * 
 * Fitur:
 * - Fullscreen API (paksa layar penuh)
 * - Visibility change detection (deteksi pindah tab/minimize)
 * - Beforeunload warning (cegah tutup halaman)
 * - Right-click disable
 * - Keyboard shortcut blocking (F11, Alt+Tab, dll)
 * - Anti screenshot (CSS blur saat tidak fokus)
 * - Pelanggaran counter (sesuai maxCurang)
 * - Auto-submit saat pelanggaran melebihi batas
 */

window.BMKiosk = (function () {

  // ── State ──────────────────────────────────────────────────────────────────
  let _active        = false;
  let _curang        = 0;
  let _maxCurang     = 3;
  let _onViolation   = null;   // callback(count, max)
  let _onAutoSubmit  = null;   // callback()
  let _examTitle     = 'Ujian';
  let _overlayEl     = null;
  let _warnEl        = null;

  // ── Fullscreen ─────────────────────────────────────────────────────────────
  function _requestFullscreen() {
    const el = document.documentElement;
    const fn = el.requestFullscreen || el.webkitRequestFullscreen ||
               el.mozRequestFullScreen || el.msRequestFullscreen;
    if (fn) {
      fn.call(el).catch(() => {
        // Safari iOS tidak support Fullscreen API — pakai fallback CSS
        document.body.style.position = 'fixed';
        document.body.style.top = '0';
        document.body.style.left = '0';
        document.body.style.width = '100vw';
        document.body.style.height = '100vh';
      });
    }
  }

  function _exitFullscreen() {
    const fn = document.exitFullscreen || document.webkitExitFullscreen ||
               document.mozCancelFullScreen || document.msExitFullscreen;
    if (fn) fn.call(document).catch(() => {});
    // Reset CSS fallback
    document.body.style.position = '';
    document.body.style.top = '';
    document.body.style.left = '';
    document.body.style.width = '';
    document.body.style.height = '';
  }

  // Paksa fullscreen kembali jika user keluar (tekan Esc)
  function _onFullscreenChange() {
    if (!_active) return;
    const isFullscreen = !!(document.fullscreenElement || document.webkitFullscreenElement ||
                            document.mozFullScreenElement || document.msFullscreenElement);
    if (!isFullscreen) {
      _recordViolation('fullscreen_exit');
      // Coba masuk fullscreen lagi setelah 500ms
      setTimeout(_requestFullscreen, 500);
    }
  }

  // ── Visibility / Focus Detection ───────────────────────────────────────────
  function _onVisibilityChange() {
    if (!_active) return;
    if (document.hidden || document.visibilityState === 'hidden') {
      _recordViolation('tab_switch');
    }
  }

  function _onWindowBlur() {
    if (!_active) return;
    // Delay sedikit untuk hindari false positive saat klik di dalam app
    setTimeout(() => {
      if (!document.hasFocus()) {
        _recordViolation('window_blur');
      }
    }, 200);
  }

  // ── Keyboard Blocking ──────────────────────────────────────────────────────
  function _onKeyDown(e) {
    if (!_active) return;

    const blocked = [
      e.key === 'F11',                            // fullscreen toggle
      e.key === 'Escape',                          // exit fullscreen
      e.altKey && e.key === 'Tab',                 // alt+tab
      e.altKey && e.key === 'F4',                  // close window
      e.metaKey,                                   // Windows/Cmd key
      e.ctrlKey && e.shiftKey && e.key === 'I',    // devtools
      e.ctrlKey && e.shiftKey && e.key === 'J',    // devtools console
      e.ctrlKey && e.key === 'U',                  // view source
      e.key === 'F12',                             // devtools
      e.key === 'PrintScreen',                     // screenshot
      e.ctrlKey && e.key === 'p',                  // print
      e.ctrlKey && e.key === 'w',                  // close tab
      e.ctrlKey && e.key === 't',                  // new tab
      e.ctrlKey && e.key === 'n',                  // new window
      e.ctrlKey && e.key === 'Tab',                // switch tab
      e.ctrlKey && e.shiftKey && e.key === 'Tab',  // switch tab reverse
    ];

    if (blocked.some(Boolean)) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }
  }

  // ── Right Click Disable ────────────────────────────────────────────────────
  function _onContextMenu(e) {
    if (!_active) return;
    e.preventDefault();
    return false;
  }

  // ── Beforeunload Warning ───────────────────────────────────────────────────
  function _onBeforeUnload(e) {
    if (!_active) return;
    const msg = 'Ujian sedang berlangsung! Keluar dari halaman ini akan dicatat sebagai pelanggaran.';
    e.preventDefault();
    e.returnValue = msg;
    return msg;
  }

  // ── Violation Overlay ──────────────────────────────────────────────────────
  function _createOverlay() {
    if (_overlayEl) return;

    _overlayEl = document.createElement('div');
    _overlayEl.id = 'bm-kiosk-overlay';
    _overlayEl.style.cssText = `
      position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
      background: rgba(0,0,0,0.85); z-index: 999999;
      display: none; flex-direction: column;
      justify-content: center; align-items: center;
      font-family: 'Segoe UI', Roboto, Arial, sans-serif;
      backdrop-filter: blur(8px);
    `;

    _warnEl = document.createElement('div');
    _warnEl.style.cssText = `
      background: white; border-radius: 16px; padding: 32px 40px;
      text-align: center; max-width: 400px; width: 90%;
      box-shadow: 0 20px 60px rgba(0,0,0,0.5);
    `;

    document.body.appendChild(_overlayEl);
    _overlayEl.appendChild(_warnEl);
  }

  function _showViolationOverlay(count, max) {
    if (!_overlayEl) _createOverlay();

    const isLast = count >= max;
    _warnEl.innerHTML = `
      <div style="font-size:56px; margin-bottom:16px">${isLast ? '🔒' : '⚠️'}</div>
      <h2 style="color:${isLast ? '#d32f2f' : '#f57c00'}; margin:0 0 8px; font-size:22px">
        ${isLast ? 'Ujian Dikunci!' : 'Peringatan Kecurangan'}
      </h2>
      <p style="color:#555; margin:0 0 8px; font-size:15px; line-height:1.5">
        ${isLast
          ? 'Batas pelanggaran tercapai. Ujian kamu telah dikunci dan dilaporkan ke pengawas.'
          : `Kamu terdeteksi keluar dari halaman ujian.<br>Pelanggaran <strong>${count}</strong> dari <strong>${max}</strong>.`
        }
      </p>
      ${!isLast ? `
        <button id="bm-kiosk-resume" style="
          margin-top:16px; background:#0F172A; color:white; border:none;
          padding:12px 28px; border-radius:10px; font-size:15px; cursor:pointer;
          width:100%;
        ">🔒 Kembali ke Ujian</button>
      ` : `
        <p style="color:#d32f2f; font-size:13px; margin-top:12px">
          Hubungi pengawas untuk membuka kunci.
        </p>
      `}
    `;

    _overlayEl.style.display = 'flex';

    const resumeBtn = document.getElementById('bm-kiosk-resume');
    if (resumeBtn) {
      resumeBtn.addEventListener('click', () => {
        _overlayEl.style.display = 'none';
        _requestFullscreen();
      });
    }
  }

  // ── Anti Screenshot (CSS blur saat tidak fokus) ────────────────────────────
  function _onFocusBlur(focused) {
    if (!_active) return;
    // Blur konten saat window tidak fokus (partial protection)
    const flutterView = document.querySelector('flt-glass-pane') ||
                        document.querySelector('flutter-view') ||
                        document.body;
    if (flutterView) {
      flutterView.style.filter = focused ? '' : 'blur(20px)';
      flutterView.style.transition = 'filter 0.3s';
    }
  }

  // ── Record Violation ───────────────────────────────────────────────────────
  function _recordViolation(reason) {
    if (!_active) return;

    _curang++;
    console.warn(`[BMKiosk] Pelanggaran #${_curang} — ${reason}`);

    // Callback ke Flutter (jika ada)
    if (_onViolation) {
      try { _onViolation(_curang, _maxCurang); } catch (_) {}
    }

    // Kirim ke Flutter via postMessage
    window.dispatchEvent(new CustomEvent('bm-kiosk-violation', {
      detail: { count: _curang, max: _maxCurang, reason }
    }));

    if (_curang >= _maxCurang) {
      _showViolationOverlay(_curang, _maxCurang);
      if (_onAutoSubmit) {
        try { _onAutoSubmit(); } catch (_) {}
      }
      // Kirim event auto-submit ke Flutter
      window.dispatchEvent(new CustomEvent('bm-kiosk-autosubmit', {
        detail: { reason: 'max_violation' }
      }));
    } else {
      _showViolationOverlay(_curang, _maxCurang);
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /**
   * Mulai kiosk mode
   * @param {Object} options
   * @param {number}   options.maxCurang    - Maks pelanggaran sebelum auto-submit (default: 3)
   * @param {string}   options.examTitle    - Judul ujian
   * @param {Function} options.onViolation  - callback(count, max)
   * @param {Function} options.onAutoSubmit - callback()
   */
  function start(options = {}) {
    if (_active) return;
    _active     = true;
    _curang     = 0;
    _maxCurang  = options.maxCurang  ?? 3;
    _examTitle  = options.examTitle  ?? 'Ujian';
    _onViolation   = options.onViolation   ?? null;
    _onAutoSubmit  = options.onAutoSubmit  ?? null;

    _createOverlay();
    _requestFullscreen();

    // Event listeners
    document.addEventListener('fullscreenchange',       _onFullscreenChange);
    document.addEventListener('webkitfullscreenchange', _onFullscreenChange);
    document.addEventListener('mozfullscreenchange',    _onFullscreenChange);
    document.addEventListener('msfullscreenchange',     _onFullscreenChange);
    document.addEventListener('visibilitychange',       _onVisibilityChange);
    document.addEventListener('contextmenu',            _onContextMenu);
    document.addEventListener('keydown',                _onKeyDown, true);
    window.addEventListener('blur',                     _onWindowBlur);
    window.addEventListener('beforeunload',             _onBeforeUnload);
    window.addEventListener('focus',  () => _onFocusBlur(true));
    window.addEventListener('blur',   () => _onFocusBlur(false));

    console.log('[BMKiosk] Kiosk mode aktif. maxCurang:', _maxCurang);
  }

  /**
   * Hentikan kiosk mode (saat ujian selesai)
   */
  function stop() {
    _active = false;

    _exitFullscreen();

    document.removeEventListener('fullscreenchange',       _onFullscreenChange);
    document.removeEventListener('webkitfullscreenchange', _onFullscreenChange);
    document.removeEventListener('mozfullscreenchange',    _onFullscreenChange);
    document.removeEventListener('msfullscreenchange',     _onFullscreenChange);
    document.removeEventListener('visibilitychange',       _onVisibilityChange);
    document.removeEventListener('contextmenu',            _onContextMenu);
    document.removeEventListener('keydown',                _onKeyDown, true);
    window.removeEventListener('blur',                     _onWindowBlur);
    window.removeEventListener('beforeunload',             _onBeforeUnload);

    // Hapus overlay
    if (_overlayEl && _overlayEl.parentNode) {
      _overlayEl.parentNode.removeChild(_overlayEl);
      _overlayEl = null;
    }

    // Reset blur
    const flutterView = document.querySelector('flt-glass-pane') ||
                        document.querySelector('flutter-view') ||
                        document.body;
    if (flutterView) flutterView.style.filter = '';

    console.log('[BMKiosk] Kiosk mode dinonaktifkan.');
  }

  /** Reset counter pelanggaran (misal setelah dialog dikonfirmasi) */
  function resetViolations() {
    _curang = 0;
  }

  /** Ambil jumlah pelanggaran saat ini */
  function getViolationCount() {
    return _curang;
  }

  /** Cek apakah kiosk aktif */
  function isActive() {
    return _active;
  }

  return { start, stop, resetViolations, getViolationCount, isActive };

})();

// ── Integrasi dengan Flutter via JS Channel ──────────────────────────────────
// Flutter bisa memanggil: BMKiosk.start({...}) lewat js.context
// Atau lewat JavascriptChannel bernama 'KioskChannel'

// Expose ke Flutter WebView jika dibutuhkan
window.addEventListener('message', (e) => {
  if (!e.data || typeof e.data !== 'object') return;
  const { type, payload } = e.data;

  if (type === 'KIOSK_START') {
    window.BMKiosk.start(payload || {});
  } else if (type === 'KIOSK_STOP') {
    window.BMKiosk.stop();
  }
});

/* LOCAL MARS · seamless online update manager */
(() => {
  'use strict';
  if (!('serviceWorker' in navigator)) return;
  let registration = null, updatePending = false, reloading = false;
  let lastActivity = Date.now(), hadController = !!navigator.serviceWorker.controller;
  let banner = null, button = null;
  const markActivity = () => { lastActivity = Date.now(); };
  ['pointerdown','keydown','input','touchstart'].forEach(type => window.addEventListener(type, markActivity, {passive:true,capture:true}));
  function ensureBanner() {
    if (banner) return;
    banner = document.createElement('aside');
    banner.id = 'lmUpdateNotice';
    banner.setAttribute('role','status');
    banner.setAttribute('aria-live','polite');
    banner.innerHTML = '<span><b>LOCAL MARS · UPDATE READY</b><small>มีเวอร์ชันใหม่พร้อมใช้งาน ระบบจะอัปเดตให้อัตโนมัติเมื่อคุณว่าง</small></span><button type="button">อัปเดตตอนนี้</button>';
    const style = document.createElement('style');
    style.textContent = '#lmUpdateNotice{position:fixed;z-index:12000;left:50%;bottom:calc(92px + env(safe-area-inset-bottom));transform:translateX(-50%);width:min(540px,calc(100vw - 24px));display:flex;align-items:center;justify-content:space-between;gap:14px;padding:13px 15px;border:1px solid #c7a66b;border-radius:15px;background:linear-gradient(145deg,#142b42,#071522);box-shadow:0 12px 44px #000b;color:#f5eddf;font:13px system-ui,sans-serif}#lmUpdateNotice span{display:grid;gap:4px}#lmUpdateNotice b{font-size:11px;letter-spacing:1.1px;color:#e5c68d}#lmUpdateNotice small{font-size:12px;line-height:1.4;color:#d6e0e9}#lmUpdateNotice button{flex:0 0 auto;border:1px solid #d5b77c;border-radius:10px;padding:10px 12px;background:#b99659;color:#071321;font-weight:800;font-size:12px}';
    document.head.appendChild(style);
    document.body.appendChild(banner);
    button = banner.querySelector('button');
    button.addEventListener('click', () => applyUpdate(true));
  }
  function userIsBusy() {
    const active = document.activeElement;
    if (active && active.matches('input,textarea,select,[contenteditable="true"]')) return true;
    const visible = selector => {
      const el = document.querySelector(selector);
      return !!el && (el.classList.contains('open') || el.getAttribute('aria-hidden') === 'false') && getComputedStyle(el).display !== 'none';
    };
    return visible('#lmChatOverlay') || visible('#lmSystemsOverlay') || visible('#login') || visible('#lmWorkspaceOverlay') || !!document.querySelector('form:focus-within');
  }
  function applyUpdate(force) {
    if (!updatePending || reloading || document.hidden) return;
    if (!force && (userIsBusy() || Date.now() - lastActivity < 15000)) return;
    reloading = true;
    if (button) button.textContent = 'กำลังอัปเดต…';
    window.location.reload();
  }
  function announceUpdate() { updatePending = true; ensureBanner(); markActivity(); }
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    const isUpdate = hadController;
    hadController = true;
    if (isUpdate) announceUpdate();
  });
  async function checkForUpdate() {
    if (!registration || document.hidden || !navigator.onLine) return;
    try { await registration.update(); }
    catch (error) { console.debug('LOCAL MARS update check deferred:', error); }
  }
  async function start() {
    try {
      registration = await navigator.serviceWorker.register('./sw.js', {scope:'./'});
      hadController = !!navigator.serviceWorker.controller;
      registration.addEventListener('updatefound', () => {
        const worker = registration.installing;
        if (!worker) return;
        worker.addEventListener('statechange', () => {
          if (worker.state === 'installed' && navigator.serviceWorker.controller) announceUpdate();
        });
      });
      await checkForUpdate();
      window.setInterval(checkForUpdate, 5 * 60 * 1000);
      window.addEventListener('online', checkForUpdate);
      document.addEventListener('visibilitychange', () => { if (!document.hidden) checkForUpdate(); });
      window.setInterval(() => applyUpdate(false), 5000);
    } catch (error) { console.warn('LOCAL MARS automatic updates unavailable:', error); }
  }
  if (document.readyState === 'complete') start();
  else window.addEventListener('load', start, {once:true});
})();

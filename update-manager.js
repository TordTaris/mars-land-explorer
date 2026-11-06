/* LOCAL MARS · silent online update manager
   Checks for new releases in the background and applies them only when the
   member is idle. No update buttons, banners, or controls are shown in Explorer.
*/
(() => {
  'use strict';
  if (!('serviceWorker' in navigator)) return;

  let registration = null;
  let updatePending = false;
  let reloading = false;
  let lastActivity = Date.now();
  let hadController = !!navigator.serviceWorker.controller;

  const markActivity = () => { lastActivity = Date.now(); };
  ['pointerdown','keydown','input','touchstart'].forEach(type =>
    window.addEventListener(type, markActivity, { passive: true, capture: true })
  );

  function userIsBusy() {
    const active = document.activeElement;
    if (active && active.matches('input,textarea,select,[contenteditable="true"]')) return true;
    const visible = selector => {
      const el = document.querySelector(selector);
      return !!el &&
        (el.classList.contains('open') || el.getAttribute('aria-hidden') === 'false') &&
        getComputedStyle(el).display !== 'none';
    };
    return visible('#lmChatOverlay') ||
      visible('#lmSystemsOverlay') ||
      visible('#login') ||
      visible('#lmWorkspaceOverlay') ||
      !!document.querySelector('form:focus-within');
  }

  function applyUpdate() {
    if (!updatePending || reloading || document.hidden || !navigator.onLine) return;
    if (userIsBusy() || Date.now() - lastActivity < 30000) return;
    reloading = true;
    window.location.reload();
  }

  function scheduleApply() {
    updatePending = true;
    // Apply immediately if idle; otherwise the five-second idle loop will retry.
    applyUpdate();
  }

  navigator.serviceWorker.addEventListener('controllerchange', () => {
    const isUpdate = hadController;
    hadController = true;
    if (isUpdate) scheduleApply();
  });

  async function checkForUpdate() {
    if (!registration || document.hidden || !navigator.onLine) return;
    try {
      await registration.update();
    } catch (error) {
      console.debug('LOCAL MARS background update check deferred:', error);
    }
  }

  async function start() {
    try {
      registration = await navigator.serviceWorker.register('./sw.js', { scope: './' });
      hadController = !!navigator.serviceWorker.controller;
      registration.addEventListener('updatefound', () => {
        const worker = registration.installing;
        if (!worker) return;
        worker.addEventListener('statechange', () => {
          if (worker.state === 'installed' && navigator.serviceWorker.controller) scheduleApply();
        });
      });
      await checkForUpdate();
      window.setInterval(checkForUpdate, 5 * 60 * 1000);
      window.addEventListener('online', checkForUpdate);
      document.addEventListener('visibilitychange', () => {
        if (!document.hidden) checkForUpdate();
      });
      window.setInterval(applyUpdate, 5000);
    } catch (error) {
      console.warn('LOCAL MARS background updates unavailable:', error);
    }
  }

  if (document.readyState === 'complete') start();
  else window.addEventListener('load', start, { once: true });
})();

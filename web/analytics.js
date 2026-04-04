/**
 * Google Analytics 4 — carregamento após load + requestIdleCallback (Core Web Vitals).
 * Consent Mode v2: pub refusé par défaut ; analytics autorisé (ajustez analytics_storage: 'denied'
 * + bandeau RGPD + window.biblecoSetAnalyticsConsent(true) si audience UE stricte).
 * ID: DEFAULT_GA4_ID ou window.__BIBLECO_GA4_ID__ (script inline avant ce fichier).
 */
(function () {
  'use strict';

  var DEFAULT_GA4_ID = 'G-JYCBRGHJNG';
  var id = String(window.__BIBLECO_GA4_ID__ || DEFAULT_GA4_ID).trim();
  if (!id || id === '__GA4_MEASUREMENT_ID__') return;
  if (!/^G-[A-Z0-9]+$/i.test(id)) return;

  window.biblecoSetAnalyticsConsent = function (granted) {
    try {
      if (typeof window.gtag !== 'function') return;
      window.gtag('consent', 'update', {
        analytics_storage: granted ? 'granted' : 'denied',
      });
    } catch (e) {}
  };

  function loadGtag() {
    window.dataLayer = window.dataLayer || [];
    function gtag() {
      window.dataLayer.push(arguments);
    }
    window.gtag = gtag;

    gtag('consent', 'default', {
      analytics_storage: 'granted',
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
      wait_for_update: 500,
    });

    var s = document.createElement('script');
    s.async = true;
    s.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(id);
    s.referrerPolicy = 'strict-origin-when-cross-origin';
    s.onerror = function () {};
    document.head.appendChild(s);

    gtag('js', new Date());
    gtag('config', id, {
      send_page_view: true,
      cookie_flags: 'SameSite=Lax;Secure',
    });
  }

  function schedule() {
    if (typeof window.requestIdleCallback === 'function') {
      window.requestIdleCallback(
        function () {
          loadGtag();
        },
        { timeout: 4000 },
      );
    } else {
      setTimeout(loadGtag, 1);
    }
  }

  if (document.readyState === 'complete') {
    schedule();
  } else {
    window.addEventListener('load', schedule, { once: true });
  }
})();

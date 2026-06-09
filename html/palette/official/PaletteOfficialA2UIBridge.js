/**
 * PaletteOfficialA2UIBridge — official A2UI v0.9 parallel card host.
 * P1 only accepts fixed fixtures. It never replaces the legacy .card-a2ui path.
 */
(function (root) {
  var HOST_TAG = "nmer-official-a2ui-surface";
  var FIXTURES = [
    "happy-six-components",
    "malformed-jsonl",
    "unsupported-component",
    "oversized-surface",
    "callback-timeout"
  ];

  function normalizeSpec(raw) {
    if (!raw) return null;
    if (raw === true) return { source: "fixture", fixtureId: "happy-six-components" };
    if (typeof raw === "string") return { source: "fixture", fixtureId: raw };
    if (typeof raw !== "object") return null;
    var source = String(raw.source || "fixture");
    var fixtureId = String(raw.fixtureId || raw.fixture || "");
    if (source === "go-jsonl") {
      var surfaceId = String(raw.surfaceId || "");
      if (!surfaceId) return null;
      return { source: source, surfaceId: surfaceId };
    }
    if (source !== "fixture" || FIXTURES.indexOf(fixtureId) < 0) return null;
    return { source: source, fixtureId: fixtureId };
  }

  function ensureContainer(dom) {
    if (!dom || !dom.querySelector) return null;
    var host = dom.querySelector(".card-official-a2ui");
    if (host) return host;
    var body = dom.querySelector(".card-body");
    if (!body) return null;
    host = document.createElement("section");
    host.className = "card-official-a2ui";
    host.hidden = true;
    host.innerHTML =
      '<div class="card-official-a2ui-head">官方 A2UI v0.9</div>' +
      '<div class="card-official-a2ui-mount"></div>';
    var legacyA2ui = dom.querySelector(".card-a2ui");
    if (legacyA2ui && legacyA2ui.parentNode === body) body.insertBefore(host, legacyA2ui);
    else body.appendChild(host);
    return host;
  }

  function hasLegacyReply(dom) {
    return !!(
      dom &&
      dom.querySelector &&
      dom.querySelector(".card-replies .card-reply-body, .card-reply .card-reply-body")
    );
  }

  function debug(options, eventName, detail) {
    if (!options || typeof options.debugLog !== "function") return;
    try {
      options.debugLog(eventName, JSON.stringify(detail || {}));
    } catch (_) {}
  }

  function syncHostTokens(el) {
    if (!el) return;
    if (
      typeof root.PaletteA2UIDesignTokens !== "undefined" &&
      PaletteA2UIDesignTokens.applyToHost
    ) {
      var mode =
        root.document &&
        root.document.body &&
        root.document.body.getAttribute("data-theme");
      PaletteA2UIDesignTokens.applyToHost(el, mode || "dark");
    }
  }

  function bindHostEvents(el, cardId, container, dom, options) {
    if (!el || el.dataset.paletteOfficialBound === "1") return;
    el.dataset.paletteOfficialBound = "1";
    el.addEventListener("official-a2ui-render", function (event) {
      var detail = (event && event.detail) || {};
      if (
        detail.status === "fallback" &&
        root.PaletteA2UIMetrics &&
        PaletteA2UIMetrics.recordFallback
      ) {
        PaletteA2UIMetrics.recordFallback({
          hint: String(detail.error || detail.fixtureId || "render_fallback"),
          cardId: cardId,
          source: "official_bridge"
        });
        if (detail.error && PaletteA2UIMetrics.recordError) {
          PaletteA2UIMetrics.recordError({
            code: "RENDER_SURFACE_FALLBACK",
            message: String(detail.error),
            layer: "render",
            cardId: cardId,
            source: "official_bridge"
          });
        }
      }
      var fallbackToReply = detail.status === "fallback" && hasLegacyReply(dom);
      container.hidden = fallbackToReply;
      container.classList.toggle("is-fallback", detail.status === "fallback");
      container.dataset.renderStatus = String(detail.status || "");
      debug(options, "official_a2ui_render", {
        cardId: cardId,
        fixtureId: detail.fixtureId || "",
        status: detail.status || "",
        fallbackToReply: fallbackToReply,
        error: detail.error || ""
      });
    });
    el.addEventListener("official-a2ui-action", function (event) {
      var detail = Object.assign({}, (event && event.detail) || {}, { cardId: cardId });
      debug(options, "official_a2ui_action", detail);
      if (typeof root.CustomEvent === "function" && root.document && document.dispatchEvent) {
        document.dispatchEvent(
          new CustomEvent("palette-official-a2ui-action", {
            detail: detail
          })
        );
      }
    });
    el.addEventListener("official-a2ui-action-error", function (event) {
      var detail = Object.assign({}, (event && event.detail) || {}, { cardId: cardId });
      debug(options, "official_a2ui_action_error", detail);
    });
  }

  function clear(dom) {
    var container = dom && dom.querySelector ? dom.querySelector(".card-official-a2ui") : null;
    if (!container) return false;
    var el = container.querySelector(HOST_TAG);
    if (el && typeof el.clear === "function") el.clear();
    var mount = container.querySelector(".card-official-a2ui-mount");
    if (mount) mount.innerHTML = "";
    container.hidden = true;
    container.removeAttribute("data-render-status");
    return true;
  }

  function mountFixture(cardId, dom, rawSpec, options) {
    var spec = normalizeSpec(rawSpec);
    if (!spec) {
      clear(dom);
      return { ok: false, reason: "disabled" };
    }
    var container = ensureContainer(dom);
    if (!container) return { ok: false, reason: "container_unavailable" };
    var mount = container.querySelector(".card-official-a2ui-mount");
    if (!mount) return { ok: false, reason: "mount_unavailable" };
    if (!root.customElements || !customElements.get(HOST_TAG)) {
      container.hidden = false;
      mount.textContent = "⚠ 官方 A2UI 渲染包未加载，已保留旧回复。";
      debug(options, "official_a2ui_render", {
        cardId: cardId,
        fixtureId: spec.fixtureId,
        status: "fallback",
        fallbackToReply: hasLegacyReply(dom),
        error: "bundle_unavailable"
      });
      if (hasLegacyReply(dom)) container.hidden = true;
      return { ok: false, reason: "bundle_unavailable" };
    }
    var el = mount.querySelector(HOST_TAG);
    if (!el) {
      mount.innerHTML = "";
      el = document.createElement(HOST_TAG);
      mount.appendChild(el);
    }
    el.cardId = String(cardId || "");
    syncHostTokens(el);
    bindHostEvents(el, cardId, container, dom, options);
    container.hidden = false;
    var key = spec.source + ":" + (spec.fixtureId || spec.surfaceId);
    if (el.dataset.fixtureKey === key) {
      if (container.dataset.renderStatus === "fallback" && hasLegacyReply(dom)) {
        container.hidden = true;
      }
      return { ok: true, reason: "unchanged", element: el };
    }
    if (
      spec.source === "go-jsonl" &&
      el.dataset.fixtureKey &&
      el.dataset.fixtureKey !== key &&
      typeof el.clear === "function"
    ) {
      el.clear();
    }
    el.dataset.fixtureKey = key;
    if (spec.source === "go-jsonl") {
      return { ok: true, reason: "stream_ready", element: el };
    }
    if (typeof el.loadFixture !== "function") return { ok: false, reason: "host_api_unavailable" };
    Promise.resolve(el.loadFixture(spec.fixtureId)).catch(function (error) {
      container.hidden = hasLegacyReply(dom);
      debug(options, "official_a2ui_render", {
        cardId: cardId,
        fixtureId: spec.fixtureId,
        status: "fallback",
        fallbackToReply: container.hidden,
        error: String(error && error.message ? error.message : error)
      });
    });
    return { ok: true, reason: "mounted", element: el };
  }

  function syncCard(card, dom, options) {
    return mountFixture(card && card.id, dom, card && card.officialA2ui, options);
  }

  function applyEnvelope(cardId, dom, envelope, options) {
    if (!envelope || typeof envelope !== "object") {
      return { ok: false, reason: "invalid_envelope" };
    }
    var mounted = mountFixture(
      cardId,
      dom,
      { source: "go-jsonl", surfaceId: envelope.surfaceId },
      options
    );
    if (!mounted.ok || !mounted.element) return mounted;
    if (typeof mounted.element.applyEnvelope !== "function") {
      return { ok: false, reason: "host_stream_api_unavailable" };
    }
    var result = mounted.element.applyEnvelope(envelope);
    return {
      ok: !!(result && result.status === "rendered"),
      reason: (result && result.status) || "unknown",
      result: result,
      element: mounted.element
    };
  }

  root.PaletteOfficialA2UIBridge = {
    HOST_TAG: HOST_TAG,
    FIXTURES: FIXTURES.slice(),
    normalizeSpec: normalizeSpec,
    ensureContainer: ensureContainer,
    hasLegacyReply: hasLegacyReply,
    mountFixture: mountFixture,
    applyEnvelope: applyEnvelope,
    syncCard: syncCard,
    clear: clear
  };
})(typeof window !== "undefined" ? window : globalThis);

/**
 * PaletteLitRenderer — card-level Lit 渲染桥（FollowUpChips v2）
 */
(function (root) {
  var COMPONENT_KEY = "FollowUpChips";
  var COMPONENT_ID = "follow-up-chips";
  var SLOT_ID = "actions";

  function getComponentDef() {
    if (root.PaletteCardSlots && PaletteCardSlots.getComponent) {
      return PaletteCardSlots.getComponent(COMPONENT_KEY);
    }
    return null;
  }

  function isAvailable() {
    if (typeof customElements === "undefined") return false;
    if (!customElements.get("palette-followup-chips")) return false;
    if (!root.Lit || !root.Lit.LitElement) return false;
    return true;
  }

  function mapLegacyReason(context) {
    context = context || {};
    if (context.renderFailed || context.reason === "render_exception") return "render_exception";
    if (context.resultNull) return "render_exception";
    if (context.noContainer) return "bridge_unavailable";
    if (context.invalidDescriptor) return "invalid_descriptor";
    if (context.emptyChips) return "empty_chips";
    if (context.noComponent) return "component_not_registered";
    if (typeof customElements === "undefined" || !root.Lit || !root.Lit.LitElement) return "lit_unavailable";
    if (!customElements.get("palette-followup-chips")) return "lit_unavailable";
    return "lit_unavailable";
  }

  function explainLitFallback(context) {
    context = context || {};
    if (isAvailable() && !context.renderFailed && !context.resultNull && !context.invalidDescriptor) {
      return { available: true, reason: "lit_ok", detail: "" };
    }
    var reason = mapLegacyReason(context);
    return {
      available: false,
      reason: reason,
      detail: String(context.error || context.detail || "")
    };
  }

  function validateDescriptor(descriptor) {
    if (!descriptor || !descriptor.props) return false;
    if (!Array.isArray(descriptor.props.chips)) return false;
    for (var i = 0; i < descriptor.props.chips.length; i++) {
      var c = descriptor.props.chips[i];
      if (!c || !c.id || !c.action || c.action.type !== "prefill") return false;
    }
    return true;
  }

  function toFollowUpChipsDescriptor(card, chips) {
    var def = getComponentDef();
    if (def && def.toDescriptor) return def.toDescriptor(card, chips);
    card = card || {};
    chips = chips || [];
    return {
      component: COMPONENT_ID,
      slot: SLOT_ID,
      props: {
        cardId: card.id || "",
        routeId: (card.routeProfile && card.routeProfile.routeId) || card.routeId || "",
        visible: false,
        dataSource: "merged",
        renderer: "lit",
        chips: []
      }
    };
  }

  function findOrCreateElement(container, tag) {
    var existing = container.querySelector(tag);
    if (existing) return existing;
    container.innerHTML = "";
    var el = document.createElement(tag);
    container.appendChild(el);
    return el;
  }

  function logRender(cardId, descriptor, count, options) {
    if (!options.debugLog) return;
    try {
      options.debugLog(
        "followup_chips_render",
        JSON.stringify({
          cardId: cardId,
          routeId: descriptor.props.routeId || "",
          chipIds: (descriptor.props.chips || []).map(function (c) {
            return c.id;
          }),
          count: count,
          renderer: count > 0 ? "lit" : "none",
          component: COMPONENT_ID,
          slot: SLOT_ID,
          dataSource: descriptor.props.dataSource || "merged"
        })
      );
    } catch (_) {}
  }

  function renderByDescriptor(cardId, card, containerEl, descriptor, options) {
    options = options || {};
    card = card || {};
    descriptor = descriptor || {};
    var props = descriptor.props || {};
    if (!containerEl) {
      return {
        ok: false,
        renderer: "legacy",
        component: COMPONENT_ID,
        slot: SLOT_ID,
        reason: "bridge_unavailable",
        count: 0
      };
    }
    if (!isAvailable()) {
      return {
        ok: false,
        renderer: "legacy",
        component: COMPONENT_ID,
        slot: SLOT_ID,
        reason: explainLitFallback({}).reason,
        count: 0
      };
    }
    var def = getComponentDef();
    if (!def) {
      return {
        ok: false,
        renderer: "legacy",
        component: COMPONENT_ID,
        slot: SLOT_ID,
        reason: "component_not_registered",
        count: 0
      };
    }
    if (!validateDescriptor(descriptor)) {
      return {
        ok: false,
        renderer: "legacy",
        component: COMPONENT_ID,
        slot: SLOT_ID,
        reason: "invalid_descriptor",
        count: 0
      };
    }
    if (!props.visible || !props.chips.length) {
      containerEl.hidden = true;
      containerEl.innerHTML = "";
      logRender(cardId, descriptor, 0, options);
      return {
        ok: true,
        renderer: "none",
        component: COMPONENT_ID,
        slot: SLOT_ID,
        reason: "empty_chips",
        count: 0
      };
    }
    try {
      containerEl.hidden = false;
      var el = findOrCreateElement(containerEl, def.tag);
      def.applyProps(el, props);
      logRender(cardId, descriptor, props.chips.length, options);
      return {
        ok: true,
        renderer: "lit",
        component: COMPONENT_ID,
        slot: SLOT_ID,
        count: props.chips.length,
        chips: props.chips
      };
    } catch (err) {
      if (options.debugLog) {
        try {
          options.debugLog(
            "lit_render_failed",
            JSON.stringify({
              cardId: cardId,
              error: String(err && err.message ? err.message : err),
              component: COMPONENT_ID,
              reason: "render_exception"
            })
          );
        } catch (_) {}
      }
      return {
        ok: false,
        renderer: "legacy",
        component: COMPONENT_ID,
        slot: SLOT_ID,
        reason: "render_exception",
        count: 0,
        error: String(err && err.message ? err.message : err)
      };
    }
  }

  function renderFollowUpChips(cardId, card, containerEl, options) {
    options = options || {};
    var chips =
      root.PaletteActionBinder && PaletteActionBinder.resolveFollowUpChips
        ? PaletteActionBinder.resolveFollowUpChips(card, options)
        : [];
    var def = getComponentDef();
    var descriptor = def && def.toDescriptor ? def.toDescriptor(card, chips) : toFollowUpChipsDescriptor(card, chips);
    return renderByDescriptor(cardId, card, containerEl, descriptor, options);
  }

  root.PaletteLitRenderer = {
    isAvailable: isAvailable,
    explainLitFallback: explainLitFallback,
    validateDescriptor: validateDescriptor,
    toFollowUpChipsDescriptor: toFollowUpChipsDescriptor,
    renderByDescriptor: renderByDescriptor,
    renderFollowUpChips: renderFollowUpChips
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);

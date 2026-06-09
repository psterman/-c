/**
 * PaletteLitRenderer — card-level Lit 渲染桥（FollowUpChips + 通用 renderSlot）
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

  function resolveComponentDef(descriptor) {
    descriptor = descriptor || {};
    if (root.PaletteComponentRegistry && PaletteComponentRegistry.resolve) {
      var registered = PaletteComponentRegistry.resolve(descriptor);
      if (registered) return registered;
    }
    if (root.PaletteCardSlots && PaletteCardSlots.getComponentById) {
      var byId = PaletteCardSlots.getComponentById(descriptor.component);
      if (byId) return byId;
    }
    if (descriptor.component === COMPONENT_ID) return getComponentDef();
    return null;
  }

  function isLitAvailableForTag(tag) {
    if (typeof customElements === "undefined") return false;
    if (!tag || !customElements.get(tag)) return false;
    if (!root.Lit || !root.Lit.LitElement) return false;
    return true;
  }

  function isAvailable() {
    return isLitAvailableForTag("palette-followup-chips");
  }

  function mapLegacyReason(context) {
    context = context || {};
    if (context.renderFailed || context.reason === "render_error" || context.reason === "render_exception") {
      return "render_error";
    }
    if (context.resultNull) return "render_error";
    if (context.noContainer) return "no_lit_component";
    if (context.invalidDescriptor) return "invalid_schema";
    if (context.emptyChips) return "invalid_schema";
    if (context.emptyEntries) return "invalid_schema";
    if (context.noComponent) return "no_lit_component";
    if (context.tag && !isLitAvailableForTag(context.tag)) return "no_lit_component";
    if (typeof customElements === "undefined" || !root.Lit || !root.Lit.LitElement) return "no_lit_component";
    return context.reason || "no_lit_component";
  }

  function explainLitFallback(context) {
    context = context || {};
    var tag = context.tag;
    if (!tag) {
      if (context.component === "status-log") tag = "palette-status-log";
      else if (context.component === "ActionChips") tag = "palette-action-chips";
      else if (context.component === "Alert") tag = "palette-alert";
      else tag = "palette-followup-chips";
    }
    if (
      isLitAvailableForTag(tag) &&
      !context.renderFailed &&
      !context.resultNull &&
      !context.invalidDescriptor
    ) {
      return { available: true, reason: "ok", detail: "" };
    }
    var reason = mapLegacyReason(Object.assign({ tag: tag }, context));
    return {
      available: false,
      reason: reason,
      detail: String(context.error || context.detail || "")
    };
  }

  function validateActionChipsDescriptor(descriptor) {
    if (!descriptor || !descriptor.props) return false;
    if (!Array.isArray(descriptor.props.actions) || !descriptor.props.actions.length) return false;
    for (var i = 0; i < descriptor.props.actions.length; i++) {
      var a = descriptor.props.actions[i];
      if (!a || !a.id || !a.label) return false;
    }
    return true;
  }

  function validateAlertDescriptor(descriptor) {
    if (!descriptor || !descriptor.props) return false;
    return !!String(descriptor.props.text || "").trim();
  }

  function validateDescriptor(descriptor) {
    if (!descriptor || !descriptor.props) return false;
    if (descriptor.component === "status-log") return validateStatusDescriptor(descriptor);
    if (descriptor.component === "ActionChips") return validateActionChipsDescriptor(descriptor);
    if (descriptor.component === "ComparisonTable") return validateComparisonTableDescriptor(descriptor);
    if (descriptor.component === "Steps") return validateStepsDescriptor(descriptor);
    if (descriptor.component === "Alert") return validateAlertDescriptor(descriptor);
    if (!Array.isArray(descriptor.props.chips)) return false;
    for (var i = 0; i < descriptor.props.chips.length; i++) {
      var c = descriptor.props.chips[i];
      if (!c || !c.id || !c.action || c.action.type !== "prefill") return false;
    }
    return true;
  }

  function validateStatusDescriptor(descriptor) {
    if (!descriptor || !descriptor.props) return false;
    if (Array.isArray(descriptor.props.entries) && descriptor.props.entries.length) return true;
    return !!String(descriptor.props.text || "").trim();
  }

  function validateComparisonTableDescriptor(descriptor) {
    if (!descriptor || !descriptor.props) return false;
    var columns = descriptor.props.columns;
    var rows = descriptor.props.rows;
    if (!Array.isArray(columns) || !columns.length || !Array.isArray(rows)) return false;
    for (var i = 0; i < rows.length; i++) {
      if (!Array.isArray(rows[i])) return false;
    }
    return true;
  }

  function validateStepsDescriptor(descriptor) {
    if (!descriptor || !descriptor.props) return false;
    var items = descriptor.props.items;
    if (!Array.isArray(items) || !items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (!String(items[i] == null ? "" : items[i]).trim()) return false;
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

  function findOrCreateSlotElement(container, tag, blockId, mountMode) {
    if (mountMode === "append" && blockId) {
      var safeId = String(blockId).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
      var existing = container.querySelector(tag + '[data-block-id="' + safeId + '"]');
      if (existing) return existing;
      var appended = document.createElement(tag);
      appended.setAttribute("data-block-id", blockId);
      container.appendChild(appended);
      return appended;
    }
    return findOrCreateElement(container, tag);
  }

  function slotCount(descriptor) {
    var props = (descriptor && descriptor.props) || {};
    if (descriptor.component === "status-log") {
      if (Array.isArray(props.entries) && props.entries.length) return props.entries.length;
      return String(props.text || "").trim() ? 1 : 0;
    }
    if (descriptor.component === "ActionChips" && Array.isArray(props.actions)) return props.actions.length;
    if (descriptor.component === "ComparisonTable" && Array.isArray(props.rows)) return props.rows.length;
    if (descriptor.component === "Steps" && Array.isArray(props.items)) return props.items.length;
    if (descriptor.component === "Alert" && String(props.text || "").trim()) return 1;
    if (Array.isArray(props.chips)) return props.chips.length;
    return 0;
  }

  function logActionChipsLitRender(cardId, descriptor, result, options) {
    if (!options.debugLog) return;
    try {
      options.debugLog(
        "action_chips_lit_rendered",
        JSON.stringify({
          cardId: cardId,
          blockId: (descriptor.props && descriptor.props.blockId) || "",
          component: "ActionChips",
          count: result.count != null ? result.count : slotCount(descriptor),
          renderer: result.renderer || "lit",
          reason: result.reason || ""
        })
      );
    } catch (_) {}
  }

  function logSlotRender(eventName, cardId, descriptor, result, options) {
    if (!options.debugLog) return;
    try {
      options.debugLog(
        eventName,
        JSON.stringify({
          cardId: cardId,
          blockId: (descriptor.props && descriptor.props.blockId) || "",
          component: descriptor.component || "",
          slot: descriptor.slot || "",
          count: result.count != null ? result.count : slotCount(descriptor),
          renderer: result.renderer || "legacy",
          reason: result.reason || ""
        })
      );
    } catch (_) {}
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

  function renderSlot(cardId, containerEl, descriptor, options) {
    options = options || {};
    descriptor = descriptor || {};
    var props = descriptor.props || {};
    var componentId = descriptor.component || "";
    var slotId = descriptor.slot || "";
    var def = resolveComponentDef(descriptor);
    var tag = (def && def.tag) || descriptor.tag || "";

    if (!containerEl) {
      return {
        ok: false,
        renderer: "legacy",
        component: componentId,
        slot: slotId,
        reason: "no_lit_component",
        count: 0
      };
    }
    if (!def || !tag) {
      return {
        ok: false,
        renderer: "legacy",
        component: componentId,
        slot: slotId,
        reason: "no_lit_component",
        count: 0
      };
    }
    if (!isLitAvailableForTag(tag)) {
      var fb = explainLitFallback({ tag: tag });
      return {
        ok: false,
        renderer: "legacy",
        component: componentId,
        slot: slotId,
        reason: fb.reason,
        count: 0
      };
    }
    if (!validateDescriptor(descriptor)) {
      return {
        ok: false,
        renderer: "legacy",
        component: componentId,
        slot: slotId,
        reason: "invalid_schema",
        count: 0
      };
    }

    if (componentId === "follow-up-chips") {
      if (!props.visible || !props.chips.length) {
        containerEl.hidden = true;
        containerEl.innerHTML = "";
        logRender(cardId, descriptor, 0, options);
        return {
          ok: true,
          renderer: "none",
          component: componentId,
          slot: slotId,
          reason: "empty_chips",
          count: 0
        };
      }
    } else if (componentId === "status-log") {
      var entryCount = slotCount(descriptor);
      if (!entryCount) {
        return {
          ok: false,
          renderer: "legacy",
          component: componentId,
          slot: slotId,
          reason: "empty_entries",
          count: 0
        };
      }
    } else if (componentId === "ActionChips") {
      if (!props.actions || !props.actions.length) {
        return {
          ok: false,
          renderer: "legacy",
          component: componentId,
          slot: slotId,
          reason: "invalid_schema",
          count: 0
        };
      }
    } else if (componentId === "ComparisonTable") {
      if (!props.columns || !props.columns.length || !Array.isArray(props.rows)) {
        return {
          ok: false,
          renderer: "legacy",
          component: componentId,
          slot: slotId,
          reason: "invalid_schema",
          count: 0
        };
      }
    } else if (componentId === "Steps") {
      if (!props.items || !props.items.length) {
        return {
          ok: false,
          renderer: "legacy",
          component: componentId,
          slot: slotId,
          reason: "invalid_schema",
          count: 0
        };
      }
    } else if (componentId === "Alert") {
      if (!String(props.text || "").trim()) {
        return {
          ok: false,
          renderer: "legacy",
          component: componentId,
          slot: slotId,
          reason: "invalid_schema",
          count: 0
        };
      }
    }

    try {
      if (
        componentId === "follow-up-chips" ||
        componentId === "ActionChips" ||
        componentId === "ComparisonTable" ||
        componentId === "Steps" ||
        componentId === "Alert"
      ) {
        containerEl.hidden = false;
      }
      var mountMode = def.mountMode || (slotId === "status" ? "append" : "replace");
      var el = findOrCreateSlotElement(containerEl, tag, props.blockId || "", mountMode);
      def.applyProps(el, props);
      var count = slotCount(descriptor);
      if (componentId === "follow-up-chips") {
        logRender(cardId, descriptor, count, options);
      } else if (componentId === "ActionChips") {
        logActionChipsLitRender(cardId, descriptor, { renderer: "lit", count: count }, options);
      } else if (componentId === "status-log") {
        logSlotRender("status_block_render", cardId, descriptor, { renderer: "lit", count: count }, options);
      }
      return {
        ok: true,
        renderer: "lit",
        component: componentId,
        slot: slotId,
        count: count
      };
    } catch (err) {
      if (options.debugLog) {
        try {
          if (componentId === "ActionChips") {
            options.debugLog(
              "action_chips_lit_error",
              JSON.stringify({
                cardId: cardId,
                blockId: props.blockId || "",
                error: String(err && err.message ? err.message : err),
                component: componentId,
                reason: "render_error"
              })
            );
          } else {
            options.debugLog(
              "lit_render_failed",
              JSON.stringify({
                cardId: cardId,
                blockId: props.blockId || "",
                error: String(err && err.message ? err.message : err),
                component: componentId,
                slot: slotId,
                reason: "render_error"
              })
            );
          }
        } catch (_) {}
      }
      return {
        ok: false,
        renderer: "legacy",
        component: componentId,
        slot: slotId,
        reason: "render_error",
        count: 0,
        error: String(err && err.message ? err.message : err)
      };
    }
  }

  function renderByDescriptor(cardId, card, containerEl, descriptor, options) {
    return renderSlot(cardId, containerEl, descriptor, options);
  }

  function toActionChipsDescriptor(card, block) {
    var def =
      root.PaletteCardSlots && PaletteCardSlots.getComponent
        ? PaletteCardSlots.getComponent("ActionChips")
        : null;
    if (def && def.toDescriptorFromBlock) return def.toDescriptorFromBlock(card, block);
    block = block || {};
    return {
      component: "ActionChips",
      slot: "ActionChips",
      tag: "palette-action-chips",
      props: {
        cardId: (card && card.id) || "",
        blockId: block.id || "",
        actions: (block.props && block.props.actions) || [],
        renderer: "lit"
      }
    };
  }

  function renderActionChipsBlock(cardId, card, containerEl, block, options) {
    options = options || {};
    var descriptor = toActionChipsDescriptor(card, block);
    return renderSlot(cardId, containerEl, descriptor, options);
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
    isLitAvailableForTag: isLitAvailableForTag,
    explainLitFallback: explainLitFallback,
    validateDescriptor: validateDescriptor,
    toFollowUpChipsDescriptor: toFollowUpChipsDescriptor,
    renderSlot: renderSlot,
    renderByDescriptor: renderByDescriptor,
    renderFollowUpChips: renderFollowUpChips,
    renderActionChipsBlock: renderActionChipsBlock,
    toActionChipsDescriptor: toActionChipsDescriptor,
    validateActionChipsDescriptor: validateActionChipsDescriptor,
    validateComparisonTableDescriptor: validateComparisonTableDescriptor,
    validateStepsDescriptor: validateStepsDescriptor,
    validateAlertDescriptor: validateAlertDescriptor
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);

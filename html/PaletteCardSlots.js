/**
 * PaletteCardSlots — card-level UI slot + Lit 组件映射表（FollowUpChips v2 + block descriptor v1）
 */
(function (root) {
  var COMPONENT_IDS = {
    FollowUpChips: "follow-up-chips",
    StatusLog: "status-log",
    ActionChips: "ActionChips"
  };
  var SLOT_IDS = { actions: "actions", followupChips: "followup-chips" };

  var BLOCK_COMPONENT_IDS = {
    plan: "plan-timeline",
    status: "status-log",
    reply: "reply-markdown",
    a2ui: "a2ui"
  };

  var BLOCK_SLOT_IDS = {
    plan: "plan",
    status: "status",
    reply: "reply",
    a2ui: "a2ui"
  };

  var BLOCK_MOUNTS = {
    plan: ".card-timeline",
    status: ".card-status-log",
    reply: ".card-replies",
    a2ui: ".card-a2ui"
  };

  var BLOCK_DESCRIPTOR_TYPES = ["plan", "status", "reply", "a2ui"];

  function shouldShowChips(card) {
    if (root.PaletteActionBinder && PaletteActionBinder.shouldShowChips) {
      return PaletteActionBinder.shouldShowChips(card);
    }
    if (!card || !card.expanded) return false;
    return card.uiState === "Done" || card.uiState === "Waiting";
  }

  function inferDataSource(card, chips) {
    card = card || {};
    chips = chips || [];
    var hasReply = false;
    var hasRoute = false;
    if (root.PaletteActionBinder && PaletteActionBinder.getLatestReplyBlock) {
      var reply = PaletteActionBinder.getLatestReplyBlock(card);
      if (reply && Array.isArray(reply.actions) && reply.actions.length) hasReply = true;
    }
    var rp = card.routeProfile || {};
    if (Array.isArray(rp.followUpChips) && rp.followUpChips.length) hasRoute = true;
    if (hasReply && hasRoute) return "merged";
    if (hasReply) return "reply.actions";
    if (hasRoute) return "routeProfile.followUpChips";
    return chips.length ? "merged" : "merged";
  }

  function mapChipToDescriptor(chip) {
    chip = chip || {};
    return {
      id: chip.id || "",
      label: chip.label || chip.id || "",
      action: {
        type: "prefill",
        value: String(chip.prefill || chip.label || "")
      }
    };
  }

  var COMPONENTS = {
    FollowUpChips: {
      slot: SLOT_IDS.actions,
      mount: ".card-followup-chips",
      tag: "palette-followup-chips",
      componentId: COMPONENT_IDS.FollowUpChips,
      toDescriptor: function (card, rawChips) {
        card = card || {};
        rawChips = rawChips || [];
        var visible = shouldShowChips(card) && rawChips.length > 0;
        return {
          component: COMPONENT_IDS.FollowUpChips,
          slot: SLOT_IDS.actions,
          props: {
            cardId: card.id || "",
            routeId: (card.routeProfile && card.routeProfile.routeId) || card.routeId || "",
            visible: visible,
            dataSource: inferDataSource(card, rawChips),
            renderer: "lit",
            chips: rawChips.map(mapChipToDescriptor)
          }
        };
      },
      applyProps: function (el, props) {
        props = props || {};
        el.cardId = props.cardId || "";
        el.routeId = props.routeId || "";
        el.dataSource = props.dataSource || "merged";
        el.chips = Array.isArray(props.chips) ? props.chips : [];
        el.actions = el.chips;
        el.visible = !!props.visible;
        if (props.visible) el.removeAttribute("hidden");
        else el.setAttribute("hidden", "");
      }
    },
    ActionChips: {
      slot: "ActionChips",
      mount: ".card-followup-chips",
      tag: "palette-action-chips",
      componentId: COMPONENT_IDS.ActionChips,
      toDescriptorFromBlock: function (card, block) {
        card = card || {};
        block = block || {};
        var props = block.props || {};
        return {
          component: COMPONENT_IDS.ActionChips,
          slot: "ActionChips",
          mount: ".card-followup-chips",
          tag: "palette-action-chips",
          props: {
            cardId: card.id || "",
            blockId: block.id || "",
            actions: Array.isArray(props.actions) ? props.actions : [],
            disabled: !!props.disabled,
            pendingActionId: props.pendingActionId || card.pendingActionId || "",
            selectedActionId: props.selectedActionId || "",
            renderer: "lit"
          }
        };
      },
      applyProps: function (el, props) {
        props = props || {};
        el.cardId = props.cardId || "";
        el.blockId = props.blockId || "";
        el.actions = Array.isArray(props.actions) ? props.actions : [];
        el.disabled = !!props.disabled;
        el.pendingActionId = props.pendingActionId || "";
        el.selectedActionId = props.selectedActionId || "";
        if (props.disabled) el.setAttribute("aria-disabled", "true");
        else el.removeAttribute("aria-disabled");
      }
    },
    StatusLog: {
      slot: BLOCK_SLOT_IDS.status,
      mount: BLOCK_MOUNTS.status,
      tag: "palette-status-log",
      componentId: BLOCK_COMPONENT_IDS.status,
      mountMode: "append",
      toDescriptorFromBlock: function (card, block) {
        card = card || {};
        block = block || {};
        var items = Array.isArray(block.items) ? block.items : [];
        return {
          component: BLOCK_COMPONENT_IDS.status,
          slot: BLOCK_SLOT_IDS.status,
          mount: BLOCK_MOUNTS.status,
          tag: "palette-status-log",
          props: {
            cardId: card.id || "",
            blockId: block.id || "",
            type: "status",
            renderer: "lit",
            entries: items,
            text: "",
            streaming: block.state === "streaming"
          }
        };
      },
      applyProps: function (el, props) {
        props = props || {};
        el.cardId = props.cardId || "";
        el.blockId = props.blockId || "";
        el.entries = Array.isArray(props.entries) ? props.entries : [];
        el.text = props.text || "";
        el.streaming = !!props.streaming;
      }
    }
  };

  var SLOTS = {
    actions: {
      tag: "palette-followup-chips",
      mount: ".card-followup-chips",
      component: "FollowUpChips",
      componentId: COMPONENT_IDS.FollowUpChips
    },
    "followup-chips": {
      tag: "palette-followup-chips",
      mount: ".card-followup-chips",
      component: "FollowUpChips",
      componentId: COMPONENT_IDS.FollowUpChips
    },
    plan: {
      mount: BLOCK_MOUNTS.plan,
      component: "plan-timeline",
      componentId: BLOCK_COMPONENT_IDS.plan,
      blockType: "plan"
    },
    status: {
      tag: "palette-status-log",
      mount: BLOCK_MOUNTS.status,
      component: "StatusLog",
      componentId: BLOCK_COMPONENT_IDS.status,
      blockType: "status"
    },
    reply: {
      mount: BLOCK_MOUNTS.reply,
      component: "reply-markdown",
      componentId: BLOCK_COMPONENT_IDS.reply,
      blockType: "reply"
    },
    a2ui: {
      mount: BLOCK_MOUNTS.a2ui,
      component: "a2ui",
      componentId: BLOCK_COMPONENT_IDS.a2ui,
      blockType: "a2ui"
    }
  };

  function resolveA2uiComponent(block) {
    block = block || {};
    var comp = String(block.component || "").trim();
    if (!comp) return BLOCK_COMPONENT_IDS.a2ui;
    if (root.PaletteBlockSchema && PaletteBlockSchema.A2UI_WHITELIST) {
      if (PaletteBlockSchema.A2UI_WHITELIST.indexOf(comp) >= 0) return comp;
    }
    return comp;
  }

  function toBlockDescriptor(card, block) {
    card = card || {};
    block = block || {};
    var type = String(block.type || "");
    if (BLOCK_DESCRIPTOR_TYPES.indexOf(type) < 0) return null;

    var component = type === "a2ui" ? resolveA2uiComponent(block) : BLOCK_COMPONENT_IDS[type];
    var props = {
      cardId: card.id || "",
      blockId: block.id || "",
      type: type,
      renderer: "legacy"
    };

    if (type === "plan") {
      props.items = Array.isArray(block.items) ? block.items : [];
    } else if (type === "status") {
      props.items = Array.isArray(block.items) ? block.items : [];
      props.entries = props.items;
      props.text = "";
      props.streaming = block.state === "streaming";
      props.renderer = "lit";
    } else if (type === "reply") {
      props.turnId = block.turnId != null ? Number(block.turnId) : 1;
      props.title = block.title || "";
      props.markdown = block.markdown || "";
    } else if (type === "a2ui") {
      props.component = block.component || "";
      props.a2uiProps = block.props || {};
      if (block.component === COMPONENT_IDS.ActionChips) {
        var acDef = COMPONENTS.ActionChips;
        if (acDef && acDef.toDescriptorFromBlock) {
          return acDef.toDescriptorFromBlock(card, block);
        }
      }
    }

    return {
      component: component,
      slot: BLOCK_SLOT_IDS[type],
      mount: BLOCK_MOUNTS[type],
      tag: type === "status" ? "palette-status-log" : "",
      props: props
    };
  }

  root.PaletteCardSlots = {
    COMPONENT_IDS: COMPONENT_IDS,
    SLOT_IDS: SLOT_IDS,
    BLOCK_COMPONENT_IDS: BLOCK_COMPONENT_IDS,
    BLOCK_SLOT_IDS: BLOCK_SLOT_IDS,
    BLOCK_MOUNTS: BLOCK_MOUNTS,
    BLOCK_DESCRIPTOR_TYPES: BLOCK_DESCRIPTOR_TYPES,
    SLOTS: SLOTS,
    COMPONENTS: COMPONENTS,
    mapChipToDescriptor: mapChipToDescriptor,
    toBlockDescriptor: toBlockDescriptor,
    getSlot: function (name) {
      return SLOTS[name] || null;
    },
    getComponent: function (name) {
      return COMPONENTS[name] || null;
    },
    getComponentById: function (componentId) {
      var id = String(componentId || "");
      var keys = Object.keys(COMPONENTS);
      for (var i = 0; i < keys.length; i++) {
        var def = COMPONENTS[keys[i]];
        if (def && def.componentId === id) return def;
      }
      return null;
    },
    listComponents: function () {
      return Object.keys(COMPONENTS);
    }
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);

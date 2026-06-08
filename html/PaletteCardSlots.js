/**
 * PaletteCardSlots — card-level UI slot + Lit 组件映射表（FollowUpChips v2 descriptor）
 */
(function (root) {
  var COMPONENT_IDS = { FollowUpChips: "follow-up-chips" };
  var SLOT_IDS = { actions: "actions", followupChips: "followup-chips" };

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
    }
  };

  root.PaletteCardSlots = {
    COMPONENT_IDS: COMPONENT_IDS,
    SLOT_IDS: SLOT_IDS,
    SLOTS: SLOTS,
    COMPONENTS: COMPONENTS,
    mapChipToDescriptor: mapChipToDescriptor,
    getSlot: function (name) {
      return SLOTS[name] || null;
    },
    getComponent: function (name) {
      return COMPONENTS[name] || null;
    },
    listComponents: function () {
      return Object.keys(COMPONENTS);
    }
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);

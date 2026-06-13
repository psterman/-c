(function (global) {
  "use strict";
  function createActionCardManager(api) {
    var manager = {
          transitionCardState: function (cardId, newState) {
            var card = api.getActionCard(cardId);
            if (!card) return;
            card.uiState = newState;
            var dom = api.ensureActionCardDom(card);
            if (!dom) return;
            dom.className =
              "cmd-action-card state-" +
              newState +
              (card.expanded ? " is-expanded" : " is-collapsed") +
              (card.id === api.actionState.activeCardId ? " is-active" : "") +
              (card.id === api.actionState.detailCardId ? " is-detail-card" : "") +
              (dom.classList.contains("has-status-log") ? " has-status-log" : "");
            var loader = dom.querySelector(".card-pulse-loader");
            var badge = dom.querySelector(".cmd-action-card-badge");
            var inputEl = api.getInputEl();
            if (badge) badge.textContent = api.actionCardUiLabel(newState);
            if (loader)
              loader.style.display =
                card.expanded && (newState === "Planning" || newState === "Running") ? "block" : "none";
            api.refreshActionCardPreview(cardId);
            if (cardId === api.actionState.activeCardId) api.updateActionLiveDock(cardId);
            if (inputEl) {
              if (newState === "Planning") inputEl.placeholder = "引擎正在重新规划任务流…";
              else if (newState === "Running") inputEl.placeholder = "正在执行云端代理具身流，请稍候…";
              else if (newState === "Waiting") {
                inputEl.placeholder = "大脑向您提问！请就地输入修正回复…";
                dom.classList.add("waiting-user-reply");
                inputEl.focus();
              } else if (newState === "Done") {
                inputEl.placeholder = api.IntentRouter.PLACEHOLDERS.action || "描述任务 Enter 提交至上方所选引擎（龙虾/Hermes）…";
                dom.classList.remove("waiting-user-reply");
              } else {
                inputEl.placeholder = api.IntentRouter.PLACEHOLDERS[api.state.intent] || api.IntentRouter.PLACEHOLDERS.local;
              }
            }
            if (newState === "Running") {
              var logEl = dom.querySelector(".card-status-log");
              if (logEl) logEl.scrollTop = logEl.scrollHeight;
            }
            if (card.id === api.actionState.detailCardId) api.syncActionDetailNav();
            api.syncActionResultsLayout();
          },
          onBlockUpdate: function (cardId, block) {
            var card = api.getActionCard(cardId);
            if (!card || !block) return;
            api.agentDebugLog(
              "block_" + String(block.type || "unknown"),
              "seq=" +
                block.seq +
                " closed=" +
                (block.closed ? 1 : 0) +
                (block.parseWarn ? " warn=" + block.parseWarn : "") +
                (block.replan ? " replan=1" : "")
            );
            var dom = api.ensureActionCardDom(card);
            if (!dom) return;
            if (block.type === "plan") {
              if (block.closed) {
                card._protoStarted = true;
                card.blocks.plan = block.steps || [];
                if (block.replan) manager.transitionCardState(cardId, "Planning");
                var tl = dom.querySelector(".card-timeline");
                if (tl) {
                  tl.innerHTML = (block.steps || [])
                    .map(function (s, i) {
                      return '<div class="card-timeline-step">' + api.esc("步骤" + (i + 1) + "：" + s) + "</div>";
                    })
                    .join("");
                }
                api.refreshActionCardPreview(cardId);
                if (card.uiState === "Planning") manager.transitionCardState(cardId, "Running");
              }
            } else if (block.type === "status") {
              card._protoStarted = true;
              if (!card.blocks.status) card.blocks.status = [];
              var idx = card.blocks.status.length - 1;
              if (!block.closed && idx >= 0 && card.blocks.status[idx] && card.blocks.status[idx].seq === block.seq) {
                card.blocks.status[idx] = block;
              } else if (block.closed) {
                card.blocks.status.push(block);
              } else {
                card.blocks.status.push(block);
              }
              var open = card.blocks.status[card.blocks.status.length - 1];
              var logBox = dom.querySelector(".card-status-log");
              if (logBox) {
                var tail = logBox.querySelector('.b-status[data-seq="' + block.seq + '"]');
                if (!tail) {
                  tail = document.createElement("div");
                  tail.className = "b-status";
                  tail.setAttribute("data-seq", String(block.seq));
                  tail.innerHTML = '<div class="b-status-title"></div><div class="b-status-log"></div>';
                  logBox.appendChild(tail);
                }
                if (tail) {
                  tail.querySelector(".b-status-title").textContent = open.title || "[执行中]";
                  api.writeAgentRichText(tail.querySelector(".b-status-log"), open.log || open.body || "");
                }
                logBox.scrollTop = logBox.scrollHeight;
                PaletteCardRenderer.syncActionCardStatusLogVisibility(dom);
              }
              api.refreshActionCardPreview(cardId);
              if (cardId === api.actionState.activeCardId) api.updateActionLiveDock(cardId);
              if (card.uiState !== "Waiting" && card.uiState !== "Done") manager.transitionCardState(cardId, "Running");
            } else if (block.type === "orphan" && block.closed) {
              var orphanBody = String(block.content || block.body || "").trim();
              if (orphanBody) {
                var orphanLog = dom.querySelector(".card-status-log");
                if (orphanLog) {
                  var orphanHit = orphanLog.querySelector('.b-status[data-seq="' + block.seq + '"]');
                  if (!orphanHit) {
                    orphanHit = document.createElement("div");
                    orphanHit.className = "b-status";
                    orphanHit.setAttribute("data-seq", String(block.seq));
                    orphanHit.innerHTML =
                      '<div class="b-status-title">[回复]</div><div class="b-status-log md-body"></div>';
                    orphanLog.appendChild(orphanHit);
                  }
                  var orphanLogEl = orphanHit.querySelector(".b-status-log");
                  if (orphanLogEl && orphanLogEl.getAttribute("data-raw-md") !== orphanBody) {
                    api.writeAgentRichText(orphanLogEl, orphanBody);
                  }
                  orphanLog.scrollTop = orphanLog.scrollHeight;
                  PaletteCardRenderer.syncActionCardStatusLogVisibility(dom);
                }
              }
              api.refreshActionCardPreview(cardId);
              if (cardId === api.actionState.activeCardId) api.updateActionLiveDock(cardId);
              if (card.uiState !== "Waiting" && card.uiState !== "Done") manager.transitionCardState(cardId, "Running");
            } else if (block.type === "question" && block.closed) {
              card.blocks.question = block;
              card.waitingForUser = true;
              var qEl = dom.querySelector(".card-question");
              if (qEl) {
                qEl.hidden = false;
                var qBody = String(block.content || block.body || "").trim();
                qEl.innerHTML =
                  '<div class="card-question-title">' +
                  api.esc(block.title || "需要您的确认") +
                  '</div><div class="card-question-body md-body">' +
                  api.renderAgentPlainMarkdown(qBody) +
                  "</div>";
              }
              manager.transitionCardState(cardId, "Waiting");
            } else if (block.type === "reply" && block.closed) {
              var rBodyCheck = String(block.content || block.body || "").trim();
              if (!rBodyCheck || api.isAgentStatusPreview(rBodyCheck)) return;
              card.blocks.reply = block;
              card.waitingForUser = false;
              var rEl = dom.querySelector(".card-reply");
              if (rEl) {
                rEl.hidden = false;
                var rBody = String(block.content || block.body || "").trim();
                var rTitle = String(block.title || "任务完结").trim();
                rEl.innerHTML =
                  '<div class="card-reply-title">' +
                  api.esc(rTitle) +
                  '</div><div class="card-reply-body md-body">' +
                  api.renderAgentPlainMarkdown(rBody || block.body || "") +
                  "</div>";
              }
              manager.transitionCardState(cardId, "Done");
            }
          }
    };
    return manager;
  }
  global.PaletteAgentDetail = { createActionCardManager: createActionCardManager };
})(typeof window !== "undefined" ? window : globalThis);

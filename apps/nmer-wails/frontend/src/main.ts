import './style.css';
import './poc/poc.css';
import './a2ui-spike/spike-element';
import './ftb-shell/ftb-shell-host';
import './cp-shell/cp-shell-host';
import { GetAppInfo, GetWsHubStatus, GetWsUrl, StartWsFakePump, StopWsFakePump } from '../wailsjs/go/main/App';
import { EventsOn } from '../wailsjs/runtime/runtime';
import type { FtbShellEventDetail } from './ftb-shell/ftb-shell-host';
import type { NmerFtbShellHostElement } from './ftb-shell/ftb-shell-host';
import type { CpShellEventDetail } from './cp-shell/cp-shell-host';
import type { NmerCpShellHostElement } from './cp-shell/cp-shell-host';
import { reduceAgentEvent } from './poc/agentReducer';
import { initialReducerState } from './poc/types';
import { fakeCompareProvider } from './poc/fakeProvider';
import { renderBlocksToDom } from './poc/litRenderer';
import { AgentWsClient, type WsClientState } from './poc/wsClient';
import type { AgentEvent, ReducerState } from './poc/types';

const app = document.querySelector('#app')!;

let poc1State: ReducerState = initialReducerState();
let poc2State: ReducerState = initialReducerState();
let wsClient: AgentWsClient | null = null;
let poc1Running = false;
let ftbShellHost: NmerFtbShellHostElement | null = null;
let cpShellHost: NmerCpShellHostElement | null = null;

function ensureCpShellHost(): NmerCpShellHostElement {
  if (!cpShellHost) {
    cpShellHost = document.createElement('nmer-cp-shell-host') as NmerCpShellHostElement;
    document.body.appendChild(cpShellHost);
  }
  return cpShellHost;
}

function applyCpShellEvent(detail: CpShellEventDetail) {
  ensureCpShellHost().applyShellEvent(detail || {});
}

function ensureFtbShellHost(): NmerFtbShellHostElement {
  if (!ftbShellHost) {
    ftbShellHost = document.createElement('nmer-ftb-shell-host') as NmerFtbShellHostElement;
    document.body.appendChild(ftbShellHost);
  }
  return ftbShellHost;
}

function applyFtbShellEvent(detail: FtbShellEventDetail) {
  ensureFtbShellHost().applyShellEvent(detail || {});
}

function renderShell() {
  app.innerHTML = `
    <header class="shell-header">
      <h1>NMER Wails POC</h1>
      <p id="app-meta" class="tagline">loading…</p>
    </header>
    <div class="poc-grid">
      <section class="poc-panel" id="poc1">
        <h2>POC 1 · Fake Provider → Reducer → Lit</h2>
        <p class="poc-desc">进程内 AsyncGenerator 推送 AgentEvent，经 TS reducer 产出 blocks[]，Lit 渲染。</p>
        <div class="poc-toolbar">
          <button type="button" class="btn primary" id="btn-poc1-run">运行 Fake 演示</button>
          <span id="poc1-status" class="badge">idle</span>
        </div>
        <div id="poc1-render" class="poc-render" aria-live="polite"></div>
        <pre id="poc1-trace" class="poc-trace"></pre>
      </section>
      <section class="poc-panel" id="poc2">
        <h2>POC 2 · WebSocket + 断线重连</h2>
        <p class="poc-desc">连接 Go Hub（:18791），支持 hello 重放、指数退避重连、Wails EventsEmit 双通道。</p>
        <div class="poc-toolbar">
          <button type="button" class="btn" id="btn-ws-connect">连接 WS</button>
          <button type="button" class="btn" id="btn-ws-disconnect">断开</button>
          <button type="button" class="btn primary" id="btn-ws-pump">Go Fake Pump</button>
          <button type="button" class="btn" id="btn-ws-stop">停止 Pump</button>
        </div>
        <div id="poc2-ws-meta" class="poc-meta">WS: —</div>
        <div id="poc2-render" class="poc-render" aria-live="polite"></div>
        <pre id="poc2-trace" class="poc-trace"></pre>
      </section>
      <section class="poc-panel poc-panel-wide" id="poc3">
        <h2>POC 3 · 官方 A2UI v0.9 隔离 Spike</h2>
        <p class="poc-desc">固定 Fixture → 输入闸门 → 官方 MessageProcessor → 官方 Lit renderer；不接 LLM，不替换旧 NmerBlock。S10 阶段 2 时 FTB 仅在窗口<strong>底栏</strong>懒加载，本区 POC 审查界面保持可见。</p>
        <nmer-a2ui-spike></nmer-a2ui-spike>
      </section>
    </div>
  `;

  document.querySelector('#btn-poc1-run')?.addEventListener('click', () => void runPoc1());
  document.querySelector('#btn-ws-connect')?.addEventListener('click', () => connectWs());
  document.querySelector('#btn-ws-disconnect')?.addEventListener('click', () => wsClient?.disconnect());
  document.querySelector('#btn-ws-pump')?.addEventListener('click', () => void StartWsFakePump());
  document.querySelector('#btn-ws-stop')?.addEventListener('click', () => void StopWsFakePump());
}

function setPoc1Status(text: string) {
  const el = document.querySelector('#poc1-status');
  if (el) el.textContent = text;
}

function appendTrace(id: string, line: string) {
  const el = document.querySelector(id);
  if (!el) return;
  const prev = el.textContent || '';
  el.textContent = (prev ? prev + '\n' : '') + line;
  el.scrollTop = el.scrollHeight;
}

function paintPoc1() {
  const host = document.querySelector('#poc1-render') as HTMLElement;
  if (host) renderBlocksToDom(host, poc1State.blocks);
}

function paintPoc2() {
  const host = document.querySelector('#poc2-render') as HTMLElement;
  if (host) renderBlocksToDom(host, poc2State.blocks);
}

async function runPoc1() {
  if (poc1Running) return;
  poc1Running = true;
  poc1State = initialReducerState();
  const trace = '#poc1-trace';
  (document.querySelector(trace) as HTMLElement).textContent = '';
  setPoc1Status('running');
  paintPoc1();

  try {
    for await (const ev of fakeCompareProvider()) {
      poc1State = reduceAgentEvent(poc1State, ev);
      paintPoc1();
      appendTrace(trace, `#${ev.seq} ${ev.kind}`);
    }
    setPoc1Status(`done · ${poc1State.blocks.length} blocks`);
  } catch (e) {
    setPoc1Status('error');
    appendTrace(trace, String(e));
  } finally {
    poc1Running = false;
  }
}

function applyPoc2Event(ev: AgentEvent, source: string) {
  poc2State = reduceAgentEvent(poc2State, ev);
  paintPoc2();
  appendTrace('#poc2-trace', `[${source}] #${ev.seq} ${ev.kind}`);
}

function updateWsMeta(extra = '') {
  const el = document.querySelector('#poc2-ws-meta');
  if (!el) return;
  const st = wsClient?.getState() || 'idle';
  const retries = wsClient?.getRetryCount() ?? 0;
  el.textContent = `WS: ${st} · retries=${retries}${extra ? ' · ' + extra : ''}`;
}

async function connectWs() {
  const url = await GetWsUrl();
  if (wsClient) wsClient.disconnect();
  poc2State = initialReducerState();
  (document.querySelector('#poc2-trace') as HTMLElement).textContent = '';
  paintPoc2();

  wsClient = new AgentWsClient({
    url,
    onEvent: (ev) => applyPoc2Event(ev, 'ws'),
    onReplay: (events) => appendTrace('#poc2-trace', `replay ${events.length} events`),
    onState: (st: WsClientState, detail) => updateWsMeta(detail || st),
  });
  wsClient.connect();
}

function isBridgeOnlyPresentation(info: { bridgeOnly?: boolean }, ftbStatus?: { presentationMode?: string }) {
  if (info?.bridgeOnly) return true;
  return String(ftbStatus?.presentationMode || '').toLowerCase() === 'external';
}

async function boot() {
  let bridgeOnly = false;
  let ftbStatus: { presentationMode?: string; visible?: boolean } | undefined;
  try {
    const info = await GetAppInfo();
    bridgeOnly = !!info.bridgeOnly;
    if (!bridgeOnly) {
      const hub = await GetWsHubStatus();
      const addr = hub?.addr || '127.0.0.1:18791';
      const res = await fetch(`http://${addr}/shell/ftb/status`);
      if (res.ok) {
        const body = (await res.json()) as { status?: { presentationMode?: string; visible?: boolean } };
        ftbStatus = body?.status;
        bridgeOnly = isBridgeOnlyPresentation(info, ftbStatus);
      }
    }
    if (bridgeOnly) {
      document.body.classList.add('nmer-bridge-only');
      const appRoot = document.querySelector('#app');
      if (appRoot) appRoot.innerHTML = '<header class="shell-header"><h1>NMER Bridge</h1><p id="app-meta" class="tagline">HTTP/WS hub · FTB external presentation</p></header>';
    } else {
      renderShell();
    }
    const meta = document.querySelector('#app-meta');
    if (meta) {
      meta.textContent = bridgeOnly
        ? `${info.appName} v${info.version} · bridge-only · hub ready`
        : `${info.appName} v${info.version} · ${info.buildMode} · app ready`;
    }
    if (!bridgeOnly) {
      const hub = await GetWsHubStatus();
      updateWsMeta(`hub clients=${hub.clientCount}`);
    }
  } catch {
    renderShell();
    const meta = document.querySelector('#app-meta');
    if (meta) meta.textContent = 'browser preview (Wails bindings unavailable)';
  }

  ensureCpShellHost();
  EventsOn('shell:cp', (detail: CpShellEventDetail) => {
    applyCpShellEvent(detail || {});
  });

  if (!bridgeOnly) {
    EventsOn('ws:agent_event', (data: AgentEvent) => {
      if (data && data.kind) applyPoc2Event(data, 'wails');
    });
    EventsOn('ws:hub_status', (st: { clientCount?: number; pumpRunning?: boolean }) => {
      updateWsMeta(`clients=${st?.clientCount ?? 0} pump=${st?.pumpRunning ? 'on' : 'off'}`);
    });
    EventsOn('shell:ftb', (detail: FtbShellEventDetail) => {
      applyFtbShellEvent(detail || {});
    });
    try {
      const hub = await GetWsHubStatus();
      const addr = hub?.addr || '127.0.0.1:18791';
      const res = await fetch(`http://${addr}/shell/ftb/status`);
      if (res.ok) {
        const body = (await res.json()) as { status?: FtbShellEventDetail & { htmlUrl?: string; presentationMode?: string } };
        const ftb = body?.status;
        if (ftb?.visible && String(ftb.presentationMode || '').toLowerCase() !== 'external') {
          applyFtbShellEvent({
            action: 'show',
            visible: true,
            mounted: ftb.mounted,
            ready: ftb.ready,
            entry: ftb.entry,
            htmlUrl: ftb.htmlUrl,
            phase: ftb.phase,
          });
        }
      }
    } catch {
      // hub may not be up in browser preview
    }

    document.body.addEventListener('poc-chip-click', ((e: CustomEvent) => {
      const d = e.detail || {};
      appendTrace('#poc1-trace', `chip: ${d.action?.label || ''}`);
      appendTrace('#poc2-trace', `chip: ${d.action?.label || ''}`);
    }) as EventListener);

    connectWs();
  }

  try {
    const hub = await GetWsHubStatus();
    const addr = hub?.addr || '127.0.0.1:18791';
    const cpRes = await fetch(`http://${addr}/shell/cp/status`);
    if (cpRes.ok) {
      const cpBody = (await cpRes.json()) as { status?: CpShellEventDetail & { htmlUrl?: string } };
      const cp = cpBody?.status;
      if (cp?.visible) {
        applyCpShellEvent({
          action: 'show',
          visible: true,
          mounted: cp.mounted,
          ready: cp.ready,
          entry: cp.entry,
          htmlUrl: cp.htmlUrl,
          phase: cp.phase,
        });
      }
    }
  } catch {
    // hub may not be up in browser preview
  }
}

boot();

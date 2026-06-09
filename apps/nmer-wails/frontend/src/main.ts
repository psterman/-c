import './style.css';
import './poc/poc.css';
import './a2ui-spike/spike-element';
import { GetAppInfo, GetWsHubStatus, GetWsUrl, StartWsFakePump, StopWsFakePump } from '../wailsjs/go/main/App';
import { EventsOn } from '../wailsjs/runtime/runtime';
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
        <p class="poc-desc">固定 Fixture → 输入闸门 → 官方 MessageProcessor → 官方 Lit renderer；不接 LLM，不替换旧 NmerBlock。</p>
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

async function boot() {
  renderShell();
  try {
    const info = await GetAppInfo();
    const meta = document.querySelector('#app-meta');
    if (meta) {
      meta.textContent = `${info.appName} v${info.version} · ${info.buildMode} · app ready`;
    }
    const hub = await GetWsHubStatus();
    updateWsMeta(`hub clients=${hub.clientCount}`);
  } catch {
    const meta = document.querySelector('#app-meta');
    if (meta) meta.textContent = 'browser preview (Wails bindings unavailable)';
  }

  EventsOn('ws:agent_event', (data: AgentEvent) => {
    if (data && data.kind) applyPoc2Event(data, 'wails');
  });
  EventsOn('ws:hub_status', (st: { clientCount?: number; pumpRunning?: boolean }) => {
    updateWsMeta(`clients=${st?.clientCount ?? 0} pump=${st?.pumpRunning ? 'on' : 'off'}`);
  });

  document.body.addEventListener('poc-chip-click', ((e: CustomEvent) => {
    const d = e.detail || {};
    appendTrace('#poc1-trace', `chip: ${d.action?.label || ''}`);
    appendTrace('#poc2-trace', `chip: ${d.action?.label || ''}`);
  }) as EventListener);

  connectWs();
}

boot();

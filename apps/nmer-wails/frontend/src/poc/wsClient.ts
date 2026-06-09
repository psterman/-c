import type { AgentEvent } from './types';

export type WsClientState = 'idle' | 'connecting' | 'open' | 'reconnecting' | 'closed';

export interface WsClientOptions {
  url: string;
  clientId?: string;
  onEvent: (ev: AgentEvent) => void;
  onState: (state: WsClientState, detail?: string) => void;
  onReplay?: (events: AgentEvent[]) => void;
  maxRetries?: number;
}

interface WireMessage {
  type: string;
  clientId?: string;
  seq?: number;
  event?: AgentEvent;
  replay?: AgentEvent[];
  reason?: string;
}

export class AgentWsClient {
  private url: string;
  private clientId: string;
  private onEvent: (ev: AgentEvent) => void;
  private onState: (state: WsClientState, detail?: string) => void;
  private onReplay?: (events: AgentEvent[]) => void;
  private maxRetries: number;

  private ws: WebSocket | null = null;
  private retries = 0;
  private reconnectTimer = 0;
  private manualClose = false;
  private state: WsClientState = 'idle';

  constructor(opts: WsClientOptions) {
    this.url = opts.url;
    this.clientId = opts.clientId || `web_${Date.now().toString(36)}`;
    this.onEvent = opts.onEvent;
    this.onState = opts.onState;
    this.onReplay = opts.onReplay;
    this.maxRetries = opts.maxRetries ?? 12;
  }

  getState(): WsClientState {
    return this.state;
  }

  getRetryCount(): number {
    return this.retries;
  }

  connect(): void {
    this.manualClose = false;
    this.openSocket(false);
  }

  disconnect(): void {
    this.manualClose = true;
    this.clearReconnect();
    if (this.ws) {
      this.ws.close(1000, 'manual');
      this.ws = null;
    }
    this.setState('closed', 'manual');
  }

  sendPing(): void {
    this.send({ type: 'ping', seq: Date.now() });
  }

  private setState(s: WsClientState, detail?: string) {
    this.state = s;
    this.onState(s, detail);
  }

  private clearReconnect() {
    if (this.reconnectTimer) {
      window.clearTimeout(this.reconnectTimer);
      this.reconnectTimer = 0;
    }
  }

  private buildUrl(): string {
    const sep = this.url.includes('?') ? '&' : '?';
    return `${this.url}${sep}clientId=${encodeURIComponent(this.clientId)}`;
  }

  private openSocket(isReconnect: boolean) {
    this.clearReconnect();
    this.setState(isReconnect ? 'reconnecting' : 'connecting');
    try {
      this.ws = new WebSocket(this.buildUrl());
    } catch (e) {
      this.scheduleReconnect(String(e));
      return;
    }

    this.ws.onopen = () => {
      this.retries = 0;
      this.setState('open');
      this.send({ type: 'hello', clientId: this.clientId });
    };

    this.ws.onmessage = (msg) => {
      let data: WireMessage;
      try {
        data = JSON.parse(String(msg.data || '{}'));
      } catch {
        return;
      }
      if (data.type === 'hello_ack' && Array.isArray(data.replay) && data.replay.length) {
        this.onReplay?.(data.replay);
        for (const ev of data.replay) this.onEvent(ev);
        return;
      }
      if (data.type === 'agent_event' && data.event) {
        this.onEvent(data.event);
      }
    };

    this.ws.onclose = (ev) => {
      this.ws = null;
      if (this.manualClose) {
        this.setState('closed', 'manual');
        return;
      }
      this.scheduleReconnect(`close code=${ev.code}`);
    };

    this.ws.onerror = () => {
      // onclose will handle reconnect
    };
  }

  private scheduleReconnect(reason: string) {
    if (this.manualClose) return;
    if (this.retries >= this.maxRetries) {
      this.setState('closed', `max_retries (${reason})`);
      return;
    }
    this.retries += 1;
    const backoff = Math.min(8000, 400 * Math.pow(1.6, this.retries - 1));
    this.setState('reconnecting', `retry ${this.retries} in ${Math.round(backoff)}ms`);
    this.reconnectTimer = window.setTimeout(() => this.openSocket(true), backoff);
  }

  private send(msg: WireMessage) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
    try {
      this.ws.send(JSON.stringify(msg));
    } catch {
      /* ignore */
    }
  }
}

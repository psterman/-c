import { css, html, LitElement, nothing } from 'lit';
import { customElement, state } from 'lit/decorators.js';

export interface FtbShellEventDetail {
  action?: string;
  visible?: boolean;
  mounted?: boolean;
  ready?: boolean;
  entry?: string;
  htmlUrl?: string;
  phase?: number;
  injectPayload?: unknown;
}

@customElement('nmer-ftb-shell-host')
export class NmerFtbShellHostElement extends LitElement {
  static styles = css`
    :host {
      display: block;
      position: fixed;
      left: 0;
      right: 0;
      bottom: 0;
      z-index: 12000;
      pointer-events: none;
    }

    .frame-wrap {
      display: none;
      position: relative;
      left: 0;
      right: 0;
      bottom: 0;
      height: clamp(120px, 22vh, 220px);
      border-top: 1px solid rgba(255, 141, 42, 0.45);
      box-shadow: 0 -8px 24px rgba(0, 0, 0, 0.35);
      background: #0b1220;
      overflow: hidden;
      pointer-events: auto;
    }

    :host([data-visible='1']) .frame-wrap {
      display: block;
    }

    iframe {
      width: 100%;
      height: 100%;
      border: 0;
      background: #0b1220;
    }

    .badge {
      position: absolute;
      top: 8px;
      right: 10px;
      padding: 2px 8px;
      border-radius: 999px;
      font: 11px/1.4 Consolas, monospace;
      color: #fcd34d;
      background: rgba(15, 23, 42, 0.82);
      border: 1px solid rgba(252, 211, 77, 0.25);
      pointer-events: none;
    }
  `;

  @state()
  private visible = false;

  @state()
  private htmlUrl = '';

  @state()
  private entry = '';

  @state()
  private ready = false;

  private frameWindow: Window | null = null;

  private onWindowMessage = (ev: MessageEvent) => {
    if (!this.frameWindow || ev.source !== this.frameWindow) return;
    const body = typeof ev.data === 'string' ? ev.data : JSON.stringify(ev.data ?? {});
    if (!body || body.charAt(0) !== '{') return;
    const hub = this.hubHttpBase();
    if (!hub) return;
    void fetch(`${hub}/shell/ftb/egress`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body,
    }).catch(() => {
      // hub may restart during bridge recycle
    });
  };

  connectedCallback() {
    super.connectedCallback();
    window.addEventListener('message', this.onWindowMessage);
  }

  disconnectedCallback() {
    window.removeEventListener('message', this.onWindowMessage);
    this.frameWindow = null;
    super.disconnectedCallback();
  }

  private hubHttpBase(): string {
    if (!this.htmlUrl) return 'http://127.0.0.1:18791';
    try {
      const u = new URL(this.htmlUrl);
      return `${u.protocol}//${u.host}`;
    } catch {
      return 'http://127.0.0.1:18791';
    }
  }

  private getFrame(): HTMLIFrameElement | null {
    return this.renderRoot.querySelector('iframe') as HTMLIFrameElement | null;
  }

  injectToFrame(payload: unknown, attempt = 0): boolean {
    const frame = this.getFrame();
    const win = frame?.contentWindow as (Window & { __niumaHostInject?: (json: string) => void }) | null;
    if (!win?.__niumaHostInject) {
      if (attempt < 80) {
        window.setTimeout(() => this.injectToFrame(payload, attempt + 1), 150);
      }
      return false;
    }
    try {
      win.__niumaHostInject!(JSON.stringify(payload ?? {}));
      return true;
    } catch {
      if (attempt < 80) {
        window.setTimeout(() => this.injectToFrame(payload, attempt + 1), 150);
      }
      return false;
    }
  }

  applyShellEvent(detail: FtbShellEventDetail) {
    const action = String(detail?.action || '').toLowerCase();
    if (action === 'inject') {
      if (detail?.injectPayload !== undefined) {
        this.injectToFrame(detail.injectPayload);
      }
      return;
    }
    if (action === 'hide' || action === 'dispose') {
      this.visible = false;
      this.ready = false;
      this.frameWindow = null;
      if (action === 'dispose') {
        this.htmlUrl = '';
        this.entry = '';
      }
      this.syncHostAttr();
      return;
    }
    if (action === 'ready') {
      this.ready = !!detail.ready;
      this.visible = true;
      this.syncHostAttr();
      return;
    }
    if (action === 'show' || action === 'mount' || detail.visible) {
      const nextUrl = detail?.htmlUrl ? String(detail.htmlUrl) : this.htmlUrl;
      const nextEntry = detail?.entry ? String(detail.entry) : this.entry;
      if (this.visible && nextUrl && this.htmlUrl === nextUrl) {
        if (nextEntry !== this.entry) this.entry = nextEntry;
        return;
      }
      if (nextUrl) this.htmlUrl = nextUrl;
      if (nextEntry) this.entry = nextEntry;
      this.visible = true;
      this.syncHostAttr();
    }
  }

  private syncHostAttr() {
    this.dataset.visible = this.visible ? '1' : '0';
    document.body.style.paddingBottom = this.visible ? 'clamp(120px, 22vh, 220px)' : '';
  }

  private bootstrapFtbFrame(frame: HTMLIFrameElement, attempt = 0) {
    const win = frame.contentWindow as (Window & { __niumaHostInject?: (json: string) => void }) | null;
    if (!win?.__niumaHostInject) {
      if (attempt < 80) {
        window.setTimeout(() => this.bootstrapFtbFrame(frame, attempt + 1), 150);
      }
      return;
    }
    this.frameWindow = win;
    const hub = this.hubHttpBase();
    if (hub) {
      void fetch(`${hub}/shell/ftb`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify({ action: 'ready', entry: this.entry }),
      }).catch(() => {
        // hub may restart during bridge recycle
      });
    }
    const inject = (payload: Record<string, unknown>) => {
      try {
        win.__niumaHostInject!(JSON.stringify(payload));
      } catch {
        // strip may still be parsing scripts
      }
    };
    inject({
      type: 'set_toolbar_config',
      actions: ['Search', 'Record', 'Screenshot', 'Prompt', 'NewPrompt', 'VirtualKeyboard', 'Settings'],
    });
    inject({ type: 'set_logo', url: '' });
    inject({ type: 'ftb_boot_paint_nudge' });
    inject({ type: 'host_request_reveal' });
    inject({ type: 'host_first_show' });
    inject({ type: 'nmer_ftb_shell_ready', entry: this.entry, phase: 3 });
  }

  private onFrameLoad() {
    this.ready = true;
    const frame = this.getFrame();
    if (frame) {
      this.bootstrapFtbFrame(frame);
    }
  }

  render() {
    if (!this.visible) {
      return html`${nothing}`;
    }
    return html`
      <div class="frame-wrap" role="complementary" aria-label="Floating Toolbar Shell">
        <div class="badge">FTB shell · ${this.ready ? 'ready' : 'loading'} · ${this.entry || '—'}</div>
        ${this.htmlUrl
          ? html`<iframe
              title="Floating Toolbar"
              src=${this.htmlUrl}
              @load=${() => this.onFrameLoad()}
            ></iframe>`
          : html`<div class="badge" style="position:static;margin:12px">waiting htmlUrl…</div>`}
      </div>
    `;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'nmer-ftb-shell-host': NmerFtbShellHostElement;
  }
}

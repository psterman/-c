import { css, html, LitElement, nothing } from 'lit';
import { customElement, property, state } from 'lit/decorators.js';
import type { SurfaceModel } from '@a2ui/web_core/v0_9';
import type { LitComponentApi } from '@a2ui/lit/v0_9';
import { A2UISpikeRuntime } from '../a2ui-spike/runtime';
import { spikeFixtures } from '../a2ui-spike/fixtures';
import type { ActionEnvelope, SpikeRunResult } from '../a2ui-spike/types';

export interface OfficialA2UIEnvelope {
  schemaVersion: 'nmer.a2ui.transport.v1';
  eventId: string;
  requestId: string;
  correlationId: string;
  cardId: string;
  surfaceId: string;
  seq: number;
  final?: boolean;
  message: unknown;
}

@customElement('nmer-official-a2ui-surface')
export class NmerOfficialA2uiSurfaceElement extends LitElement {
  static styles = css`
    :host {
      display: block;
      color: inherit;
    }

    .fallback {
      padding: 9px 10px;
      border: 1px solid rgba(251, 191, 36, 0.35);
      border-radius: 8px;
      background: rgba(251, 191, 36, 0.1);
      color: #fcd34d;
      white-space: pre-wrap;
      font: 12px/1.55 'Segoe UI', 'Microsoft YaHei UI', sans-serif;
    }

    .loading {
      color: #93c5fd;
      font: 12px/1.5 Consolas, monospace;
    }

    a2ui-surface {
      display: block;
      --a2ui-primary-color: #ff8d2a;
    }
  `;

  private readonly runtime = new A2UISpikeRuntime();

  @property({ attribute: 'card-id' })
  cardId = '';

  @state()
  private surface?: SurfaceModel<LitComponentApi>;

  @state()
  private result?: SpikeRunResult;

  @state()
  private loading = false;

  private activeSurfaceId = '';

  private lastSeq = 0;

  constructor() {
    super();
    this.runtime.processor.onSurfaceCreated(surface => {
      if (surface.id === this.activeSurfaceId || (!this.activeSurfaceId && surface.id === 'nmer-a2ui-spike')) {
        this.activeSurfaceId = surface.id;
        this.surface = surface;
      }
    });
    this.runtime.processor.onSurfaceDeleted(id => {
      if (id === this.activeSurfaceId) this.surface = undefined;
    });
    this.runtime.setActionListener(envelope => this.handleAction(envelope));
    this.runtime.setActionErrorListener(error => {
      this.dispatchHostEvent('official-a2ui-action-error', {
        cardId: this.cardId,
        error: error.message,
      });
    });
  }

  disconnectedCallback() {
    this.runtime.clearSurface(this.activeSurfaceId || 'nmer-a2ui-spike');
    super.disconnectedCallback();
  }

  async loadFixture(fixtureId: string): Promise<SpikeRunResult> {
    this.resetStreamState('nmer-a2ui-spike');
    const fixture = spikeFixtures.find(item => item.id === fixtureId);
    if (!fixture) {
      const result: SpikeRunResult = {
        fixtureId,
        status: 'fallback',
        error: `Unknown official A2UI fixture: ${fixtureId}`,
        fallbackMarkdown: `⚠ 官方 A2UI Fixture 不存在：${fixtureId}`,
      };
      this.result = result;
      this.surface = undefined;
      this.emitRenderResult(result);
      return result;
    }

    this.loading = true;
    this.result = undefined;
    this.surface = undefined;
    try {
      const result = await this.runtime.runFixture(fixture);
      this.result = result;
      this.emitRenderResult(result);
      return result;
    } finally {
      this.loading = false;
    }
  }

  clear() {
    this.runtime.clearSurface(this.activeSurfaceId || 'nmer-a2ui-spike');
    this.result = undefined;
    this.surface = undefined;
    this.loading = false;
    this.activeSurfaceId = '';
    this.lastSeq = 0;
  }

  applyEnvelope(envelope: OfficialA2UIEnvelope): SpikeRunResult {
    try {
      this.validateEnvelope(envelope);
      if (!this.activeSurfaceId) this.activeSurfaceId = envelope.surfaceId;
      if (this.activeSurfaceId !== envelope.surfaceId) {
        throw new Error(`Surface mismatch: ${envelope.surfaceId}`);
      }
      if (envelope.seq <= this.lastSeq) {
        throw new Error(`Stale official A2UI sequence: ${envelope.seq}`);
      }
      this.runtime.processRawMessage(envelope.message as never);
      this.lastSeq = envelope.seq;
      const result: SpikeRunResult = {
        fixtureId: `stream:${envelope.surfaceId}`,
        status: 'rendered',
      };
      this.result = result;
      this.emitRenderResult(result);
      if (envelope.final) this.dispatchHostEvent('official-a2ui-stream-end', {
        cardId: this.cardId,
        surfaceId: envelope.surfaceId,
        seq: envelope.seq,
      });
      return result;
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      this.runtime.clearSurface(this.activeSurfaceId || envelope.surfaceId);
      this.surface = undefined;
      const result: SpikeRunResult = {
        fixtureId: `stream:${envelope.surfaceId || 'unknown'}`,
        status: 'fallback',
        error: reason,
        fallbackMarkdown: `⚠ 官方 A2UI 流失败，已回退到旧回复。\n\n原因：${reason}`,
      };
      this.result = result;
      this.emitRenderResult(result);
      return result;
    }
  }

  render() {
    if (this.loading) return html`<div class="loading">Loading official A2UI fixture…</div>`;
    if (this.result?.status === 'fallback') {
      return html`<div class="fallback">${this.result.fallbackMarkdown}</div>`;
    }
    if (this.surface) {
      return html`<a2ui-surface .surface=${this.surface}></a2ui-surface>`;
    }
    return nothing;
  }

  private async handleAction(envelope: ActionEnvelope) {
    this.dispatchHostEvent('official-a2ui-action', {
      cardId: this.cardId,
      source: this.activeSurfaceId === 'nmer-a2ui-spike' ? 'fixture' : 'go-jsonl',
      envelope,
    });
    if (this.activeSurfaceId !== 'nmer-a2ui-spike') {
      return;
    }
    if (envelope.actionName === 'safe.timeout') {
      await new Promise<void>(() => undefined);
      return;
    }
    this.runtime.processor.processMessages([
      {
        version: 'v0.9',
        updateDataModel: {
          surfaceId: envelope.surfaceId,
          path: '/title',
          value: `CommandPalette 回调完成：${String(envelope.data.question ?? '')}`,
        },
      },
    ]);
  }

  private resetStreamState(surfaceId: string) {
    if (this.activeSurfaceId && this.activeSurfaceId !== surfaceId) {
      this.runtime.clearSurface(this.activeSurfaceId);
    }
    this.activeSurfaceId = surfaceId;
    this.lastSeq = 0;
  }

  private validateEnvelope(envelope: OfficialA2UIEnvelope) {
    if (!envelope || envelope.schemaVersion !== 'nmer.a2ui.transport.v1') {
      throw new Error('Unsupported official A2UI transport');
    }
    if (!envelope.cardId || !envelope.surfaceId || !envelope.eventId) {
      throw new Error('Incomplete official A2UI envelope');
    }
    if (!Number.isInteger(envelope.seq) || envelope.seq <= 0) {
      throw new Error('Invalid official A2UI sequence');
    }
    if (!envelope.message || typeof envelope.message !== 'object') {
      throw new Error('Missing official A2UI message');
    }
  }

  private emitRenderResult(result: SpikeRunResult) {
    this.dispatchHostEvent('official-a2ui-render', {
      cardId: this.cardId,
      fixtureId: result.fixtureId,
      status: result.status,
      error: result.error ?? '',
      fallbackMarkdown: result.fallbackMarkdown ?? '',
    });
  }

  private dispatchHostEvent(name: string, detail: Record<string, unknown>) {
    this.dispatchEvent(
      new CustomEvent(name, {
        detail,
        bubbles: true,
        composed: true,
      }),
    );
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'nmer-official-a2ui-surface': NmerOfficialA2uiSurfaceElement;
  }
}

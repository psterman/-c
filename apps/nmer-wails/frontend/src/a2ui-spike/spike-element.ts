import { css, html, LitElement, nothing } from 'lit';
import { customElement, state } from 'lit/decorators.js';
import type { SurfaceModel } from '@a2ui/web_core/v0_9';
import type { LitComponentApi } from '@a2ui/lit/v0_9';
import { A2UISpikeRuntime } from './runtime';
import { spikeFixtures } from './fixtures';
import type { ActionEnvelope, SpikeRunResult } from './types';

@customElement('nmer-a2ui-spike')
export class NmerA2uiSpikeElement extends LitElement {
  static styles = css`
    :host {
      display: block;
    }

    .toolbar {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      margin-bottom: 8px;
    }

    button {
      height: 30px;
      padding: 0 12px;
      border-radius: 8px;
      border: 1px solid rgba(96, 165, 250, 0.45);
      background: rgba(96, 165, 250, 0.1);
      color: #dbeafe;
      cursor: pointer;
    }

    button[aria-pressed='true'] {
      border-color: #ff8d2a;
      background: rgba(255, 141, 42, 0.2);
      color: #fff7ed;
    }

    button:disabled {
      opacity: 0.55;
      cursor: wait;
    }

    .surface {
      min-height: 190px;
      padding: 10px;
      border: 1px dashed rgba(255, 255, 255, 0.12);
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.02);
      --a2ui-primary-color: #ff8d2a;
    }

    .fallback {
      white-space: pre-wrap;
      color: #fcd34d;
      font-size: 12px;
      line-height: 1.55;
    }

    .guard-pass {
      color: #86efac;
      font-size: 12px;
      font-weight: 700;
      margin-bottom: 6px;
    }

    .status,
    .trace {
      margin-top: 8px;
      font: 11px/1.45 Consolas, monospace;
      color: #93c5fd;
    }

    .trace {
      max-height: 90px;
      overflow: auto;
      white-space: pre-wrap;
      color: #94a3b8;
    }
  `;

  private readonly runtime = new A2UISpikeRuntime();

  @state()
  private surface?: SurfaceModel<LitComponentApi>;

  @state()
  private result?: SpikeRunResult;

  @state()
  private trace: string[] = [];

  @state()
  private activeFixtureId = '';

  @state()
  private running = false;

  constructor() {
    super();
    this.runtime.processor.onSurfaceCreated(surface => {
      if (surface.id === 'nmer-a2ui-spike') this.surface = surface;
    });
    this.runtime.processor.onSurfaceDeleted(id => {
      if (id === 'nmer-a2ui-spike') this.surface = undefined;
    });
    this.runtime.setActionListener(envelope => this.onAction(envelope));
    this.runtime.setActionErrorListener(error => {
      this.trace = [...this.trace, `action error: ${error.message}`];
    });
  }

  connectedCallback() {
    super.connectedCallback();
    void this.runFixture('happy-six-components');
  }

  render() {
    return html`
      <div class="toolbar">
        ${spikeFixtures.map(
          fixture => html`
            <button
              type="button"
              aria-pressed=${this.activeFixtureId === fixture.id}
              ?disabled=${this.running}
              @click=${() => this.runFixture(fixture.id)}
            >
              ${fixture.title}
            </button>
          `,
        )}
      </div>
      <div class="surface">
        ${this.result?.status === 'fallback'
          ? html`
              <div class="guard-pass">✓ 预期护栏已通过</div>
              <div class="fallback">${this.result.fallbackMarkdown}</div>
            `
          : this.surface
            ? html`<a2ui-surface .surface=${this.surface}></a2ui-surface>`
            : html`<span>等待 fixture…</span>`}
      </div>
      <div class="status">
        ${this.result
          ? `${this.result.fixtureId}: ${this.result.status}`
          : 'not started'}
      </div>
      ${this.trace.length
        ? html`<div class="trace">${this.trace.join('\n')}</div>`
        : nothing}
    `;
  }

  private async runFixture(id: string) {
    const fixture = spikeFixtures.find(item => item.id === id);
    if (!fixture) return;
    this.activeFixtureId = fixture.id;
    this.running = true;
    this.result = undefined;
    this.surface = undefined;
    this.trace = [`run ${fixture.id}`];
    try {
      this.result = await this.runtime.runFixture(fixture);
      this.trace = [
        ...this.trace,
        `${this.result.status} (expected ${fixture.expected})`,
        ...(this.result.error ? [this.result.error] : []),
      ];
    } finally {
      this.running = false;
    }
  }

  private async onAction(envelope: ActionEnvelope) {
    this.trace = [
      ...this.trace,
      `action ${envelope.actionName}`,
      `request=${envelope.requestId}`,
      `correlation=${envelope.correlationId}`,
    ];
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
          value: `回调完成：${String(envelope.data.question ?? '')}`,
        },
      },
    ]);
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'nmer-a2ui-spike': NmerA2uiSpikeElement;
  }
}

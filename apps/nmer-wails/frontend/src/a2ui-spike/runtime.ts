import {
  A2uiMessageSchema,
  MessageProcessor,
  type A2uiClientAction,
  type A2uiMessage,
} from '@a2ui/web_core/v0_9';
import { basicCatalog, type LitComponentApi } from '@a2ui/lit/v0_9';
import type { ActionEnvelope, SpikeFixture, SpikeRunResult } from './types';

const ALLOWED_COMPONENTS = new Set([
  'Text',
  'Row',
  'Column',
  'Card',
  'Button',
  'TextField',
]);
const MAX_COMPONENTS_PER_MESSAGE = 200;
const MAX_MESSAGE_BYTES = 256 * 1024;
const MAX_ACTION_DEPTH = 2;
const ACTION_DEDUP_MS = 10_000;
const DEFAULT_ACTION_TIMEOUT_MS = 30_000;

export class A2UISpikeRuntime {
  readonly processor = new MessageProcessor<LitComponentApi>(
    [basicCatalog],
    action => this.handleAction(action),
  );

  private readonly recentActions = new Map<string, number>();
  private actionListener?: (envelope: ActionEnvelope) => Promise<void> | void;
  private actionErrorListener?: (error: Error) => void;

  setActionListener(listener: (envelope: ActionEnvelope) => Promise<void> | void) {
    this.actionListener = listener;
  }

  setActionErrorListener(listener: (error: Error) => void) {
    this.actionErrorListener = listener;
  }

  async runFixture(fixture: SpikeFixture): Promise<SpikeRunResult> {
    this.clearSurface('nmer-a2ui-spike');

    try {
      for await (const rawMessage of fixture.source.stream()) {
        this.processRawMessage(rawMessage);
      }
      return { fixtureId: fixture.id, status: 'rendered' };
    } catch (error) {
      this.clearSurface('nmer-a2ui-spike');
      const reason = error instanceof Error ? error.message : String(error);
      return {
        fixtureId: fixture.id,
        status: 'fallback',
        error: reason,
        fallbackMarkdown: `⚠ A2UI 渲染失败，已回退到安全文本。\n\n原因：${reason}`,
      };
    }
  }

  processRawMessage(rawMessage: string | A2uiMessage): A2uiMessage {
    const message = this.parseAndValidate(rawMessage);
    this.processor.processMessages([message]);
    return message;
  }

  private parseAndValidate(rawMessage: string | A2uiMessage): A2uiMessage {
    const serialized = typeof rawMessage === 'string' ? rawMessage : JSON.stringify(rawMessage);
    if (new TextEncoder().encode(serialized).byteLength > MAX_MESSAGE_BYTES) {
      throw new Error('A2UI message exceeds 256 KiB');
    }

    let candidate: unknown;
    try {
      candidate = typeof rawMessage === 'string' ? JSON.parse(rawMessage) : rawMessage;
    } catch {
      throw new Error('Invalid A2UI JSONL');
    }

    const parsed = A2uiMessageSchema.safeParse(candidate);
    if (!parsed.success) {
      throw new Error('A2UI schema validation failed');
    }

    const message = parsed.data;
    if ('updateComponents' in message) {
      const components = message.updateComponents.components;
      if (components.length > MAX_COMPONENTS_PER_MESSAGE) {
        throw new Error(`A2UI component limit exceeded (${components.length}/200)`);
      }
      for (const component of components) {
        if (!ALLOWED_COMPONENTS.has(component.component)) {
          throw new Error(`Unsupported A2UI component: ${component.component}`);
        }
      }
    }
    return message;
  }

  private async handleAction(action: A2uiClientAction): Promise<void> {
    const depth = Number(action.context.depth ?? 0);
    const kind = String(action.context.kind ?? '');
    if (kind !== 'safe') throw new Error('Only safe A2UI actions are allowed');
    if (depth > MAX_ACTION_DEPTH) throw new Error('A2UI action depth exceeded');

    const dedupKey = `${action.surfaceId}:${action.sourceComponentId}:${action.name}`;
    const now = Date.now();
    const lastTriggeredAt = this.recentActions.get(dedupKey) ?? 0;
    if (now - lastTriggeredAt < ACTION_DEDUP_MS) {
      throw new Error('Duplicate A2UI action suppressed');
    }
    this.recentActions.set(dedupKey, now);

    const eventId = crypto.randomUUID();
    const requestedTimeout = Number(action.context.timeoutMs ?? DEFAULT_ACTION_TIMEOUT_MS);
    const timeoutMs = Math.min(
      DEFAULT_ACTION_TIMEOUT_MS,
      Math.max(100, Number.isFinite(requestedTimeout) ? requestedTimeout : DEFAULT_ACTION_TIMEOUT_MS),
    );
    const envelope: ActionEnvelope = {
      eventId,
      requestId: crypto.randomUUID(),
      correlationId: `${action.surfaceId}:${action.timestamp}`,
      surfaceId: action.surfaceId,
      componentId: action.sourceComponentId,
      actionName: action.name,
      depth,
      timeoutMs,
      abortId: crypto.randomUUID(),
      data: action.context,
      original: action,
    };

    try {
      await this.withTimeout(
        Promise.resolve(this.actionListener?.(envelope)),
        envelope.timeoutMs,
        'A2UI action timed out',
      );
    } catch (error) {
      const normalized = error instanceof Error ? error : new Error(String(error));
      this.actionErrorListener?.(normalized);
      throw normalized;
    }
  }

  clearSurface(surfaceId = 'nmer-a2ui-spike') {
    const surface = this.processor.model.getSurface(surfaceId);
    if (!surface) return;
    this.processor.processMessages([
      {
        version: 'v0.9',
        deleteSurface: { surfaceId: surface.id },
      },
    ]);
  }

  private async withTimeout<T>(promise: Promise<T>, timeoutMs: number, message: string): Promise<T> {
    let timeoutId: ReturnType<typeof setTimeout> | undefined;
    const timeout = new Promise<never>((_, reject) => {
      timeoutId = globalThis.setTimeout(() => reject(new Error(message)), timeoutMs);
    });
    try {
      return await Promise.race([promise, timeout]);
    } finally {
      if (timeoutId !== undefined) globalThis.clearTimeout(timeoutId);
    }
  }
}

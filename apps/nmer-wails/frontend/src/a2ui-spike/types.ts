import type { A2uiClientAction, A2uiMessage } from '@a2ui/web_core/v0_9';

export interface A2UIMessageSource {
  stream(): AsyncIterable<string | A2uiMessage>;
}

export interface SpikeFixture {
  id: string;
  title: string;
  expected: 'rendered' | 'fallback';
  source: A2UIMessageSource;
}

export interface ActionEnvelope {
  eventId: string;
  requestId: string;
  correlationId: string;
  surfaceId: string;
  componentId: string;
  actionName: string;
  depth: number;
  timeoutMs: number;
  abortId: string;
  data: Record<string, unknown>;
  original: A2uiClientAction;
}

export interface SpikeRunResult {
  fixtureId: string;
  status: 'rendered' | 'fallback';
  fallbackMarkdown?: string;
  error?: string;
}

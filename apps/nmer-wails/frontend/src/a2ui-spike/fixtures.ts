import type { A2uiMessage } from '@a2ui/web_core/v0_9';
import type { A2UIMessageSource, SpikeFixture } from './types';

export const SPIKE_SURFACE_ID = 'nmer-a2ui-spike';
export const BASIC_CATALOG_ID = 'https://a2ui.org/specification/v0_9/basic_catalog.json';

export class FixtureMessageSource implements A2UIMessageSource {
  constructor(private readonly messages: Array<string | A2uiMessage>) {}

  async *stream(): AsyncIterable<string | A2uiMessage> {
    for (const message of this.messages) {
      await Promise.resolve();
      yield message;
    }
  }
}

const createSurface: A2uiMessage = {
  version: 'v0.9',
  createSurface: {
    surfaceId: SPIKE_SURFACE_ID,
    catalogId: BASIC_CATALOG_ID,
    sendDataModel: true,
  },
};

const sixComponentSurface: A2uiMessage = {
  version: 'v0.9',
  updateComponents: {
    surfaceId: SPIKE_SURFACE_ID,
    components: [
      {
        id: 'root',
        component: 'Column',
        children: ['title', 'card', 'action-row'],
        align: 'stretch',
      },
      {
        id: 'title',
        component: 'Text',
        text: { path: '/title' },
        variant: 'h3',
      },
      {
        id: 'card',
        component: 'Card',
        child: 'form-column',
      },
      {
        id: 'form-column',
        component: 'Column',
        children: ['description', 'question'],
        align: 'stretch',
      },
      {
        id: 'description',
        component: 'Text',
        text: '官方 v0.9 MessageProcessor + Lit renderer，旧 NmerBlock 通道保持不动。',
        variant: 'body',
      },
      {
        id: 'question',
        component: 'TextField',
        label: '补充问题',
        value: { path: '/question' },
        variant: 'shortText',
      },
      {
        id: 'action-row',
        component: 'Row',
        children: ['submit'],
        justify: 'end',
      },
      {
        id: 'submit-label',
        component: 'Text',
        text: '发送安全回调',
        variant: 'body',
      },
      {
        id: 'submit',
        component: 'Button',
        child: 'submit-label',
        variant: 'primary',
        action: {
          event: {
            name: 'safe.follow-up',
            context: {
              kind: 'safe',
              depth: 0,
              question: { path: '/question' },
            },
          },
        },
      },
    ],
  },
};

const initialData: A2uiMessage = {
  version: 'v0.9',
  updateDataModel: {
    surfaceId: SPIKE_SURFACE_ID,
    path: '/',
    value: {
      title: 'A2UI v0.9 隔离 Spike',
      question: '继续完善 CommandPalette',
    },
  },
};

const updatedData: A2uiMessage = {
  version: 'v0.9',
  updateDataModel: {
    surfaceId: SPIKE_SURFACE_ID,
    path: '/title',
    value: 'A2UI v0.9 · 流式更新已生效',
  },
};

const timeoutActionSurface: A2uiMessage = {
  version: 'v0.9',
  updateComponents: {
    surfaceId: SPIKE_SURFACE_ID,
    components: [
      {
        id: 'root',
        component: 'Column',
        children: ['timeout-title', 'timeout-button'],
        align: 'stretch',
      },
      {
        id: 'timeout-title',
        component: 'Text',
        text: '点击按钮验证 250ms 超时与错误回收',
        variant: 'h3',
      },
      {
        id: 'timeout-label',
        component: 'Text',
        text: '模拟回调超时',
        variant: 'body',
      },
      {
        id: 'timeout-button',
        component: 'Button',
        child: 'timeout-label',
        variant: 'primary',
        action: {
          event: {
            name: 'safe.timeout',
            context: {
              kind: 'safe',
              depth: 0,
              timeoutMs: 250,
            },
          },
        },
      },
    ],
  },
};

export const happyFixture: SpikeFixture = {
  id: 'happy-six-components',
  title: '6 组件 + data model + button',
  expected: 'rendered',
  source: new FixtureMessageSource([
    JSON.stringify(createSurface),
    sixComponentSurface,
    JSON.stringify(initialData),
    updatedData,
  ]),
};

export const malformedJsonFixture: SpikeFixture = {
  id: 'malformed-jsonl',
  title: '非法 JSONL 自动降级',
  expected: 'fallback',
  source: new FixtureMessageSource([
    JSON.stringify(createSurface),
    '{"version":"v0.9","updateComponents":',
  ]),
};

export const unsupportedComponentFixture: SpikeFixture = {
  id: 'unsupported-component',
  title: '未知组件自动降级',
  expected: 'fallback',
  source: new FixtureMessageSource([
    createSurface,
    {
      version: 'v0.9',
      updateComponents: {
        surfaceId: SPIKE_SURFACE_ID,
        components: [{ id: 'root', component: 'RemoteScript', src: 'https://invalid.test/x.js' }],
      },
    },
  ]),
};

export const oversizedSurfaceFixture: SpikeFixture = {
  id: 'oversized-surface',
  title: '超限组件拒绝渲染',
  expected: 'fallback',
  source: new FixtureMessageSource([
    createSurface,
    {
      version: 'v0.9',
      updateComponents: {
        surfaceId: SPIKE_SURFACE_ID,
        components: Array.from({ length: 201 }, (_, index) => ({
          id: index === 0 ? 'root' : `text-${index}`,
          component: 'Text',
          text: `item-${index}`,
        })),
      },
    },
  ]),
};

export const timeoutActionFixture: SpikeFixture = {
  id: 'callback-timeout',
  title: '回调超时演练',
  expected: 'rendered',
  source: new FixtureMessageSource([createSurface, timeoutActionSurface]),
};

export const spikeFixtures = [
  happyFixture,
  malformedJsonFixture,
  unsupportedComponentFixture,
  oversizedSurfaceFixture,
  timeoutActionFixture,
];

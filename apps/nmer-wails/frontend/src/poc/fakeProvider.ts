import type { AgentEvent } from './types';

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Scripted AgentEvent stream for POC 1 (in-process, no network). */
export async function* fakeCompareProvider(): AsyncGenerator<AgentEvent> {
  const cardId = 'poc-card-compare';
  const turnId = 1;
  let seq = 0;
  const emit = (kind: AgentEvent['kind'], payload: Record<string, unknown>): AgentEvent => {
    seq += 1;
    return {
      seq,
      ts: new Date().toISOString(),
      kind,
      cardId,
      turnId,
      payload,
    };
  };

  yield emit('task_start', { query: '比较 pocket4 和 3' });
  await delay(120);
  yield emit('status', { text: '规划中…', level: 'info' });
  await delay(120);
  yield emit('reply_delta', { text: '## Pocket 4 vs Pocket 3\n\n' });
  await delay(100);
  yield emit('reply_delta', { text: '正在整理规格对比…\n' });
  await delay(100);
  yield emit('a2ui', {
    block: {
      id: 'blk_cmp',
      type: 'a2ui',
      component: 'ComparisonTable',
      state: 'final',
      source: 'heuristic',
      turnId,
      props: {
        columns: ['项目', 'Pocket 3', 'Pocket 4'],
        rows: [
          ['传感器', '1 英寸', '1 英寸'],
          ['视频', '4K/120fps', '4K/240fps'],
          ['动态范围', '10 档', '14 档'],
        ],
      },
    },
  });
  await delay(120);
  yield emit('reply_final', {
    markdown:
      '## Pocket 4 vs Pocket 3\n\n对比表见上方 A2UI；差价约 700 元，视频规格提升明显。',
  });
  await delay(100);
  yield emit('a2ui', {
    block: {
      id: 'blk_chips',
      type: 'a2ui',
      component: 'ActionChips',
      state: 'final',
      source: 'system',
      turnId,
      props: {
        actions: [
          {
            id: 'chip1',
            label: '补充对比维度',
            intent: 'prefill',
            payload: { text: '补充续航和配件生态' },
          },
          {
            id: 'chip2',
            label: '缩短结论',
            intent: 'prefill',
            payload: { text: '用三句话总结怎么选' },
          },
        ],
      },
    },
  });
  await delay(80);
  yield emit('status', { text: '完成', level: 'info' });
  yield emit('task_end', { ok: true });
}

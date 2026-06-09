import { reduceAgentEvents } from '../src/poc/agentReducer';
import type { AgentEvent } from '../src/poc/types';

const events: AgentEvent[] = [
  { seq: 1, ts: '', kind: 'task_start', cardId: 'c1', payload: { query: 'q' } },
  { seq: 2, ts: '', kind: 'reply_delta', cardId: 'c1', payload: { text: 'hello ' } },
  { seq: 3, ts: '', kind: 'reply_final', cardId: 'c1', payload: { markdown: 'hello world' } },
  {
    seq: 4,
    ts: '',
    kind: 'a2ui',
    cardId: 'c1',
    payload: {
      block: {
        id: 't1',
        type: 'a2ui',
        component: 'ComparisonTable',
        props: { columns: ['A', 'B'], rows: [['1', '2']] },
      },
    },
  },
  { seq: 5, ts: '', kind: 'task_end', cardId: 'c1', payload: { ok: true } },
];

const state = reduceAgentEvents(events);
const types = state.blocks.map((b) => `${b.type}:${b.component || '-'}`).join(',');
const ok =
  state.done &&
  state.blocks.length >= 3 &&
  types.includes('reply') &&
  types.includes('a2ui:ComparisonTable') &&
  state.query === 'q';

console.log(ok ? 'PASS reducer poc' : 'FAIL reducer poc', { blocks: state.blocks.length, types });
if (!ok) process.exit(1);

import type { AgentEvent, PaletteBlock, ReducerState } from './types';
import { initialReducerState } from './types';

function genId(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 7)}`;
}

function upsertBlock(blocks: PaletteBlock[], block: PaletteBlock): PaletteBlock[] {
  const idx = blocks.findIndex((b) => b.id === block.id);
  if (idx < 0) return [...blocks, block];
  const next = blocks.slice();
  next[idx] = { ...next[idx], ...block };
  return next;
}

function finalizeStreaming(blocks: PaletteBlock[]): PaletteBlock[] {
  return blocks.map((b) =>
    b.state === 'streaming' ? { ...b, state: 'final' as const } : b
  );
}

function statusBlock(event: AgentEvent): PaletteBlock {
  const p = event.payload || {};
  return {
    id: `status_${event.turnId || 1}`,
    type: 'status',
    state: 'final',
    source: 'system',
    turnId: event.turnId || 1,
    seq: event.seq,
    title: String(p.text || '状态'),
    level: String(p.level || 'info'),
    markdown: String(p.text || ''),
  };
}

function replyFromDelta(blocks: PaletteBlock[], event: AgentEvent): PaletteBlock[] {
  const turnId = event.turnId || 1;
  const id = `reply_${turnId}`;
  const delta = String(event.payload?.text || '');
  const existing = blocks.find((b) => b.id === id);
  const markdown = (existing?.markdown || '') + delta;
  const block: PaletteBlock = {
    id,
    type: 'reply',
    state: 'streaming',
    source: 'protocol',
    turnId,
    seq: event.seq,
    markdown,
  };
  return upsertBlock(blocks, block);
}

function replyFromFinal(blocks: PaletteBlock[], event: AgentEvent): PaletteBlock[] {
  const turnId = event.turnId || 1;
  const id = `reply_${turnId}`;
  const block: PaletteBlock = {
    id,
    type: 'reply',
    state: 'final',
    source: 'protocol',
    turnId,
    seq: event.seq,
    markdown: String(event.payload?.markdown || ''),
  };
  return upsertBlock(blocks, block);
}

function a2uiFromEvent(blocks: PaletteBlock[], event: AgentEvent): PaletteBlock[] {
  const raw = event.payload?.block;
  if (!raw || typeof raw !== 'object') return blocks;
  const block = raw as PaletteBlock;
  if (!block.id) block.id = genId('a2ui');
  if (!block.type) block.type = 'a2ui';
  block.state = block.state || 'final';
  block.turnId = block.turnId ?? event.turnId ?? 1;
  block.seq = event.seq;
  return upsertBlock(blocks, block);
}

/** Reduce a single AgentEvent into blocks[] state. */
export function reduceAgentEvent(state: ReducerState, event: AgentEvent): ReducerState {
  const base = { ...state, lastSeq: event.seq };

  switch (event.kind) {
    case 'task_start':
      return {
        ...initialReducerState(),
        cardId: String(event.cardId || 'poc-card'),
        turnId: event.turnId || 1,
        lastSeq: event.seq,
        query: String(event.payload?.query || ''),
        blocks: [
          {
            id: 'status_boot',
            type: 'status',
            state: 'final',
            source: 'system',
            turnId: event.turnId || 1,
            title: '任务开始',
            markdown: `查询：${String(event.payload?.query || '—')}`,
          },
        ],
      };
    case 'status':
      return { ...base, blocks: upsertBlock(state.blocks, statusBlock(event)) };
    case 'reply_delta':
      return { ...base, blocks: replyFromDelta(state.blocks, event) };
    case 'reply_final':
      return { ...base, blocks: replyFromFinal(state.blocks, event) };
    case 'a2ui':
      return { ...base, blocks: a2uiFromEvent(state.blocks, event) };
    case 'task_end':
      return {
        ...base,
        done: true,
        blocks: finalizeStreaming(state.blocks),
      };
    case 'error':
      return {
        ...base,
        done: true,
        blocks: [
          ...state.blocks,
          {
            id: genId('err'),
            type: 'error',
            state: 'final',
            source: 'system',
            markdown: String(event.payload?.message || 'unknown error'),
          },
        ],
      };
    default:
      return base;
  }
}

/** Fold a batch of events in order. */
export function reduceAgentEvents(events: AgentEvent[]): ReducerState {
  return events.reduce(reduceAgentEvent, initialReducerState());
}

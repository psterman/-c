/** POC AgentEvent contract — not wired to production OpenClaw/Hermes. */

export type AgentEventKind =
  | 'task_start'
  | 'status'
  | 'reply_delta'
  | 'reply_final'
  | 'a2ui'
  | 'task_end'
  | 'error';

export interface AgentEvent {
  seq: number;
  ts: string;
  kind: AgentEventKind;
  cardId?: string;
  turnId?: number;
  payload?: Record<string, unknown>;
}

export interface PaletteBlock {
  id: string;
  type: 'plan' | 'status' | 'question' | 'reply' | 'a2ui' | 'error';
  state?: 'streaming' | 'final' | 'stale';
  source?: string;
  turnId?: number;
  seq?: number;
  component?: string;
  markdown?: string;
  title?: string;
  props?: Record<string, unknown>;
  level?: string;
}

export interface ReducerState {
  cardId: string;
  turnId: number;
  blocks: PaletteBlock[];
  lastSeq: number;
  done: boolean;
  query: string;
}

export const initialReducerState = (): ReducerState => ({
  cardId: '',
  turnId: 1,
  blocks: [],
  lastSeq: 0,
  done: false,
  query: '',
});

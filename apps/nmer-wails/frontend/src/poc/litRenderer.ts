import './components/poc-action-chips';
import './components/poc-comparison-table';
import type { PaletteBlock } from './types';

function esc(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function renderMarkdownSimple(md: string): string {
  return esc(md)
    .split(/\n/)
    .map((line) => {
      const t = line.trim();
      if (t.startsWith('## ')) return `<h2>${esc(t.slice(3))}</h2>`;
      if (!t) return '';
      return `<p>${esc(line)}</p>`;
    })
    .join('');
}

function mountA2ui(host: HTMLElement, block: PaletteBlock): HTMLElement {
  const slot = document.createElement('div');
  slot.className = 'poc-block poc-a2ui';
  slot.dataset.blockId = block.id;

  const comp = String(block.component || '');
  if (comp === 'ComparisonTable') {
    const el = document.createElement('poc-comparison-table');
    const props = (block.props || {}) as { columns?: string[]; rows?: string[][] };
    el.columns = props.columns || [];
    el.rows = props.rows || [];
    slot.appendChild(el);
    return slot;
  }
  if (comp === 'ActionChips') {
    const el = document.createElement('poc-action-chips');
    el.cardId = 'poc-card';
    el.blockId = block.id;
    const props = (block.props || {}) as { actions?: unknown[] };
    el.actions = (props.actions || []) as never[];
    slot.appendChild(el);
    return slot;
  }

  slot.innerHTML = `<div class="poc-unknown">未知 A2UI: ${esc(comp)}</div>`;
  return slot;
}

function renderBlock(block: PaletteBlock): HTMLElement {
  const wrap = document.createElement('article');
  wrap.className = `poc-block poc-${block.type}`;
  wrap.dataset.blockId = block.id;
  if (block.state) wrap.dataset.state = block.state;

  if (block.type === 'a2ui') {
    return mountA2ui(wrap, block);
  }
  if (block.type === 'status') {
    wrap.innerHTML = `<div class="poc-status level-${esc(block.level || 'info')}">${esc(block.markdown || block.title || '')}</div>`;
    return wrap;
  }
  if (block.type === 'reply') {
    wrap.innerHTML = `<div class="poc-reply-title">任务回复</div><div class="poc-reply-body">${renderMarkdownSimple(block.markdown || '')}</div>`;
    return wrap;
  }
  if (block.type === 'error') {
    wrap.innerHTML = `<div class="poc-error">${esc(block.markdown || 'error')}</div>`;
    return wrap;
  }
  wrap.textContent = JSON.stringify(block);
  return wrap;
}

/** Render blocks[] into host; returns block count for trace. */
export function renderBlocksToDom(host: HTMLElement, blocks: PaletteBlock[]): number {
  host.innerHTML = '';
  let count = 0;
  for (const block of blocks) {
    host.appendChild(renderBlock(block));
    count += 1;
  }
  return count;
}

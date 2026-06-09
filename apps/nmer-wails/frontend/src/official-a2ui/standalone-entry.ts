import './palette-host-element';

declare global {
  interface Window {
    NmerOfficialA2UI?: {
      version: string;
      fixtures: string[];
    };
  }
}

window.NmerOfficialA2UI = {
  version: 'v0.9',
  fixtures: [
    'happy-six-components',
    'malformed-jsonl',
    'unsupported-component',
    'oversized-surface',
    'callback-timeout',
  ],
};

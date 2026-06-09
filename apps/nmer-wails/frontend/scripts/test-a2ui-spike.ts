import assert from 'node:assert/strict';
import { MessageProcessor } from '@a2ui/web_core/v0_9';
import { basicCatalog } from '@a2ui/lit/v0_9';
import { A2UISpikeRuntime } from '../src/a2ui-spike/runtime';
import {
  happyFixture,
  spikeFixtures,
  timeoutActionFixture,
} from '../src/a2ui-spike/fixtures';

const runtime = new A2UISpikeRuntime();

for (const fixture of spikeFixtures) {
  const result = await runtime.runFixture(fixture);
  assert.equal(result.status, fixture.expected, fixture.id);
  console.log(`PASS ${fixture.id}: ${result.status}`);
}

const processor = new MessageProcessor([basicCatalog]);
const happyMessages = [];
for await (const raw of happyFixture.source.stream()) {
  happyMessages.push(typeof raw === 'string' ? JSON.parse(raw) : raw);
}
processor.processMessages(happyMessages);
const surface = processor.model.getSurface('nmer-a2ui-spike');
assert.ok(surface, 'happy fixture creates a surface');
assert.equal(surface.componentsModel.get('root')?.type, 'Column');
assert.equal(surface.componentsModel.get('submit')?.type, 'Button');
assert.equal(surface.dataModel.get('/question'), '继续完善 CommandPalette');
console.log('PASS official MessageProcessor state assertions');

let actionCount = 0;
const actionRuntime = new A2UISpikeRuntime();
actionRuntime.setActionListener(() => {
  actionCount += 1;
});
const actionFixtureResult = await actionRuntime.runFixture(happyFixture);
assert.equal(actionFixtureResult.status, 'rendered');
const actionSurface = actionRuntime.processor.model.getSurface('nmer-a2ui-spike');
assert.ok(actionSurface);
await actionSurface.dispatchAction(
  {
    event: {
      name: 'safe.follow-up',
      context: { kind: 'safe', depth: 0 },
    },
  },
  'submit',
);
assert.equal(actionCount, 1);
console.log('PASS button action callback');

const timeoutRuntime = new A2UISpikeRuntime();
timeoutRuntime.setActionListener(() => new Promise<void>(() => undefined));
let resolveActionError!: (error: Error) => void;
const actionError = new Promise<Error>(resolve => {
  resolveActionError = resolve;
});
timeoutRuntime.setActionErrorListener(error => resolveActionError(error));
const timeoutResult = await timeoutRuntime.runFixture(timeoutActionFixture);
assert.equal(timeoutResult.status, 'rendered');
const timeoutSurface = timeoutRuntime.processor.model.getSurface('nmer-a2ui-spike');
assert.ok(timeoutSurface);
const originalConsoleError = console.error;
console.error = () => undefined;
try {
  await timeoutSurface.dispatchAction(
    {
      event: {
        name: 'safe.timeout',
        context: { kind: 'safe', depth: 0, timeoutMs: 100 },
      },
    },
    'timeout-button',
  );
} finally {
  console.error = originalConsoleError;
}
assert.match((await actionError).message, /timed out/);
console.log('PASS action timeout');

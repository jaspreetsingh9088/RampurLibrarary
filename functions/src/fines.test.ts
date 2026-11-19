import { test } from 'node:test';
import assert from 'node:assert/strict';
import { addDays, computeFine, daysLate, formatMembershipId } from './fines';

const s = { finePerDay: 5, graceDays: 0, maxFinePerLoan: 500 };

test('no fine when returned on time', () => {
  const due = new Date('2026-01-10T10:00:00Z');
  assert.equal(computeFine(due, new Date('2026-01-10T09:00:00Z'), s), 0);
});

test('fine per started day late', () => {
  const due = new Date('2026-01-10T10:00:00Z');
  assert.equal(daysLate(due, new Date('2026-01-11T09:00:00Z')), 1);
  assert.equal(computeFine(due, new Date('2026-01-13T10:00:00Z'), s), 15);
});

test('grace days and cap', () => {
  const due = new Date('2026-01-01T00:00:00Z');
  assert.equal(computeFine(due, addDays(due, 2), { ...s, graceDays: 2 }), 0);
  assert.equal(computeFine(due, addDays(due, 400), s), 500);
});

test('membership id format', () => {
  assert.equal(formatMembershipId(42), 'RPL-000042');
});

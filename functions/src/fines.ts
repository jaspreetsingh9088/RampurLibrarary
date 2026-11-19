/** Pure helpers for circulation maths. Kept free of Firebase imports so they can be unit tested. */

export interface LibrarySettings {
  loanDays: number;
  maxRenewals: number;
  finePerDay: number;
  graceDays: number;
  maxFinePerLoan: number;
  maxLoansPerMember: number;
  reservationHoldDays: number;
  dueReminderDays: number;
}

export const DEFAULT_SETTINGS: LibrarySettings = {
  loanDays: 14,
  maxRenewals: 2,
  finePerDay: 5,
  graceDays: 0,
  maxFinePerLoan: 500,
  maxLoansPerMember: 3,
  reservationHoldDays: 3,
  dueReminderDays: 2,
};

const DAY_MS = 24 * 60 * 60 * 1000;

/** Whole days `to` is after `from` (0 if not after). */
export function daysLate(dueAt: Date, at: Date): number {
  const diff = at.getTime() - dueAt.getTime();
  if (diff <= 0) return 0;
  return Math.ceil(diff / DAY_MS);
}

/** Fine for a loan returned (or still out) at `at`. */
export function computeFine(dueAt: Date, at: Date, s: Pick<LibrarySettings, 'finePerDay' | 'graceDays' | 'maxFinePerLoan'>): number {
  const late = daysLate(dueAt, at) - s.graceDays;
  if (late <= 0) return 0;
  const fine = late * s.finePerDay;
  return s.maxFinePerLoan > 0 ? Math.min(fine, s.maxFinePerLoan) : fine;
}

export function addDays(d: Date, days: number): Date {
  return new Date(d.getTime() + days * DAY_MS);
}

/** Membership numbers look like RPL-000042. */
export function formatMembershipId(n: number, prefix = 'RPL'): string {
  return `${prefix}-${String(n).padStart(6, '0')}`;
}

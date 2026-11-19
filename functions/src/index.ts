/**
 * Rampur Library — Cloud Functions (2nd gen)
 *
 * Every member-facing notification is written to users/{uid}/notifications/{id};
 * `deliverNotification` turns that document into an FCM push. That gives members an
 * in-app inbox and a push in one place, and every other function just writes a doc.
 */
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp, getFirestore, type DocumentReference } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';
import { DEFAULT_SETTINGS, addDays, computeFine, formatMembershipId, type LibrarySettings } from './fines';

initializeApp();
const db = getFirestore();
setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

const TZ = 'Asia/Kolkata';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function settings(): Promise<LibrarySettings> {
  const snap = await db.doc('settings/library').get();
  return { ...DEFAULT_SETTINGS, ...(snap.data() ?? {}) } as LibrarySettings;
}

type NotificationType =
  | 'welcome' | 'issued' | 'returned' | 'due_soon' | 'overdue' | 'reservation_ready'
  | 'reservation_queued' | 'reservation_expired' | 'renewed' | 'fine' | 'request' | 'general';

async function notify(uid: string, title: string, body: string, type: NotificationType, data: Record<string, string> = {}) {
  await db.collection('users').doc(uid).collection('notifications').add({
    title, body, type, data, read: false, createdAt: FieldValue.serverTimestamp(),
  });
}

function fmtDate(ts: Timestamp | Date): string {
  const d = ts instanceof Timestamp ? ts.toDate() : ts;
  return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', timeZone: TZ });
}

async function audit(action: string, details: Record<string, unknown>) {
  await db.collection('auditLogs').add({ action, ...details, by: 'system', at: FieldValue.serverTimestamp() });
}

/**
 * Give the next available copy of a book to the oldest pending reservation.
 * Holds the copy (decrements availableCopies) and tells the member to collect it.
 */
async function processReservationQueue(bookId: string) {
  const s = await settings();
  const promoted = await db.runTransaction(async (tx) => {
    const bookRef = db.collection('books').doc(bookId);
    const book = await tx.get(bookRef);
    if (!book.exists || (book.get('availableCopies') ?? 0) <= 0) return null;
    const q = await tx.get(
      db.collection('reservations').where('bookId', '==', bookId).where('status', '==', 'pending')
        .orderBy('createdAt', 'asc').limit(1),
    );
    if (q.empty) return null;
    const res = q.docs[0];
    tx.update(bookRef, { availableCopies: FieldValue.increment(-1), updatedAt: FieldValue.serverTimestamp() });
    tx.update(res.ref, {
      status: 'ready',
      readyAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(addDays(new Date(), s.reservationHoldDays)),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { uid: res.get('userId') as string, title: res.get('bookTitle') as string, id: res.id };
  });
  if (promoted) {
    await notify(promoted.uid, 'Your reserved book is ready',
      `"${promoted.title}" is waiting for you at the desk. Please collect it within ${s.reservationHoldDays} days.`,
      'reservation_ready', { reservationId: promoted.id, bookId });
  }
}

// ---------------------------------------------------------------------------
// Members
// ---------------------------------------------------------------------------

/** Assign a membership number and safe defaults when a member profile is created. */
export const onUserCreated = onDocumentCreated('users/{uid}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const s = await settings();
  const counterRef = db.doc('counters/members');
  const number = await db.runTransaction(async (tx) => {
    const c = await tx.get(counterRef);
    const next = (c.get('value') ?? 0) + 1;
    tx.set(counterRef, { value: next }, { merge: true });
    tx.update(snap.ref, {
      membershipId: formatMembershipId(next),
      status: 'active',
      membershipType: 'standard',
      maxLoans: s.maxLoansPerMember,
      outstandingFines: 0,
      createdAt: snap.get('createdAt') ?? FieldValue.serverTimestamp(),
    });
    return next;
  });
  await notify(event.params.uid, 'Welcome to Rampur Library!',
    `Your membership number is ${formatMembershipId(number)}. Show your digital card at the desk to borrow books.`, 'welcome');
});

/** Turn an inbox document into a push notification on all of the member's devices. */
export const deliverNotification = onDocumentCreated('users/{uid}/notifications/{id}', async (event) => {
  const n = event.data?.data();
  if (!n) return;
  const userRef = db.collection('users').doc(event.params.uid);
  const user = await userRef.get();
  const tokens: string[] = user.get('fcmTokens') ?? [];
  if (!tokens.length || user.get('preferences.push') === false) return;

  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: n.title, body: n.body },
    data: { type: String(n.type ?? 'general'), notificationId: event.params.id, ...(n.data ?? {}) },
    android: { priority: 'high', notification: { channelId: 'library_updates', sound: 'default' } },
    apns: { payload: { aps: { sound: 'default', badge: 1 } } },
  });

  const stale: string[] = [];
  res.responses.forEach((r, i) => {
    const code = r.error?.code ?? '';
    if (code.includes('registration-token-not-registered') || code.includes('invalid-registration-token') || code.includes('invalid-argument')) {
      stale.push(tokens[i]);
    }
  });
  if (stale.length) await userRef.update({ fcmTokens: FieldValue.arrayRemove(...stale) });
  logger.info('push sent', { uid: event.params.uid, ok: res.successCount, failed: res.failureCount });
});

/** Admin broadcasts go to the FCM topic every app subscribes to (`all`) or a custom topic. */
export const onBroadcastCreated = onDocumentCreated('broadcasts/{id}', async (event) => {
  const b = event.data?.data();
  if (!b) return;
  const topic = (b.topic as string) || 'all';
  try {
    await getMessaging().send({
      topic,
      notification: { title: b.title, body: b.body, ...(b.imageUrl ? { imageUrl: b.imageUrl } : {}) },
      data: { type: 'broadcast', broadcastId: event.params.id, link: b.link ?? '' },
      android: { priority: 'high', notification: { channelId: 'library_updates' } },
    });
    await event.data!.ref.update({ sentAt: FieldValue.serverTimestamp(), status: 'sent' });
  } catch (e) {
    logger.error('broadcast failed', e);
    await event.data!.ref.update({ status: 'failed', error: String(e) });
  }
});

/** Keep users.outstandingFines in sync with the fines collection. */
export const onFineWritten = onDocumentWritten('fines/{id}', async (event) => {
  const after = event.data?.after.data();
  const before = event.data?.before.data();
  const uid = (after?.userId ?? before?.userId) as string | undefined;
  if (!uid) return;
  const unpaid = await db.collection('fines').where('userId', '==', uid).where('status', '==', 'unpaid').get();
  const total = unpaid.docs.reduce((sum, d) => sum + (Number(d.get('amount')) || 0), 0);
  await db.collection('users').doc(uid).set({ outstandingFines: total }, { merge: true });
  if (!before && after && after.status === 'unpaid') {
    await notify(uid, 'Fine added to your account', `₹${after.amount} — ${after.reason ?? 'late return'}.`, 'fine', { fineId: event.params.id });
  }
});

// ---------------------------------------------------------------------------
// Circulation
// ---------------------------------------------------------------------------

export const onLoanWritten = onDocumentWritten('loans/{id}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after) return;

  if (!before) {
    await notify(after.userId, 'Book issued', `"${after.bookTitle}" is due back on ${fmtDate(after.dueAt)}. Happy reading!`,
      'issued', { loanId: event.params.id, bookId: after.bookId });
    return;
  }

  if (before.status !== 'returned' && after.status === 'returned') {
    await db.collection('users').doc(after.userId).collection('readingHistory').doc(event.params.id).set({
      bookId: after.bookId, bookTitle: after.bookTitle, bookCover: after.bookCover ?? null,
      issuedAt: after.issuedAt, returnedAt: after.returnedAt ?? FieldValue.serverTimestamp(),
    });
    const fine = Number(after.fineAmount ?? 0);
    await notify(after.userId, 'Book returned',
      fine > 0 ? `Thanks for returning "${after.bookTitle}". A late fine of ₹${fine} was added.` : `Thanks for returning "${after.bookTitle}" on time!`,
      'returned', { loanId: event.params.id, bookId: after.bookId });
    await processReservationQueue(after.bookId);
  }

  if (before.status !== 'lost' && after.status === 'lost') {
    await audit('loan_marked_lost', { loanId: event.params.id, bookId: after.bookId, userId: after.userId });
  }
});

/** A reservation for a book that is on the shelf is held immediately; otherwise it joins the queue. */
export const onReservationCreated = onDocumentCreated('reservations/{id}', async (event) => {
  const r = event.data?.data();
  if (!r) return;
  const book = await db.collection('books').doc(r.bookId).get();
  if ((book.get('availableCopies') ?? 0) > 0) {
    await processReservationQueue(r.bookId);
  } else {
    const ahead = await db.collection('reservations').where('bookId', '==', r.bookId).where('status', '==', 'pending').count().get();
    await event.data!.ref.update({ queuePosition: ahead.data().count });
    await notify(r.userId, 'Reservation placed',
      `You are #${ahead.data().count} in the queue for "${r.bookTitle}". We'll notify you when it's ready.`,
      'reservation_queued', { reservationId: event.params.id, bookId: r.bookId });
  }
});

/** When a held copy is released (cancelled / expired) put it back and serve the next in queue. */
export const onReservationUpdated = onDocumentUpdated('reservations/{id}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;
  if (before.status === 'ready' && (after.status === 'cancelled' || after.status === 'expired')) {
    await db.collection('books').doc(after.bookId).update({ availableCopies: FieldValue.increment(1) });
    if (after.status === 'expired') {
      await notify(after.userId, 'Reservation expired', `Your hold on "${after.bookTitle}" has expired.`, 'reservation_expired');
    }
    await processReservationQueue(after.bookId);
  }
});

/** Members renew their own loans from the app. */
export const renewLoan = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const loanId = String(req.data?.loanId ?? '');
  if (!loanId) throw new HttpsError('invalid-argument', 'loanId is required.');
  const s = await settings();
  const loanRef = db.collection('loans').doc(loanId);

  const newDue = await db.runTransaction(async (tx) => {
    const loan = await tx.get(loanRef);
    if (!loan.exists || loan.get('userId') !== uid) throw new HttpsError('not-found', 'Loan not found.');
    if (loan.get('status') !== 'issued') throw new HttpsError('failed-precondition', 'Only active, non-overdue loans can be renewed.');
    if ((loan.get('renewCount') ?? 0) >= s.maxRenewals) throw new HttpsError('failed-precondition', `Renewal limit (${s.maxRenewals}) reached.`);
    const waiting = await tx.get(db.collection('reservations').where('bookId', '==', loan.get('bookId')).where('status', '==', 'pending').limit(1));
    if (!waiting.empty) throw new HttpsError('failed-precondition', 'Another member is waiting for this book, so it cannot be renewed.');
    const user = await tx.get(db.collection('users').doc(uid));
    if ((user.get('outstandingFines') ?? 0) > 0) throw new HttpsError('failed-precondition', 'Please clear outstanding fines before renewing.');
    const due = (loan.get('dueAt') as Timestamp).toDate();
    const next = addDays(due, s.loanDays);
    tx.update(loanRef, { dueAt: Timestamp.fromDate(next), renewCount: FieldValue.increment(1), lastRenewedAt: FieldValue.serverTimestamp() });
    return next;
  });

  await notify(uid, 'Loan renewed', `New due date: ${fmtDate(newDue)}.`, 'renewed', { loanId });
  return { dueAt: newDue.toISOString() };
});

/** Daily: mark overdue loans, accrue fines, send reminders and expire stale holds. */
export const dailyCirculation = onSchedule({ schedule: 'every day 09:00', timeZone: TZ }, async () => {
  const s = await settings();
  const now = new Date();
  const today = now.toISOString().slice(0, 10);

  // 1. Due soon reminders
  const soon = await db.collection('loans').where('status', '==', 'issued')
    .where('dueAt', '<=', Timestamp.fromDate(addDays(now, s.dueReminderDays))).get();
  for (const d of soon.docs) {
    const due = (d.get('dueAt') as Timestamp).toDate();
    if (due < now) {
      await d.ref.update({ status: 'overdue', accruedFine: computeFine(due, now, s), lastReminderOn: today });
      await notify(d.get('userId'), 'Book overdue', `"${d.get('bookTitle')}" was due on ${fmtDate(due)}. Fines of ₹${s.finePerDay}/day apply.`,
        'overdue', { loanId: d.id });
    } else if (d.get('lastReminderOn') !== today) {
      await d.ref.update({ lastReminderOn: today });
      await notify(d.get('userId'), 'Due soon', `"${d.get('bookTitle')}" is due on ${fmtDate(due)}. Renew it in the app if you need more time.`,
        'due_soon', { loanId: d.id });
    }
  }

  // 2. Accrue fines on overdue loans (remind every 3 days)
  const overdue = await db.collection('loans').where('status', '==', 'overdue').get();
  for (const d of overdue.docs) {
    const due = (d.get('dueAt') as Timestamp).toDate();
    const fine = computeFine(due, now, s);
    const days = Math.floor((now.getTime() - due.getTime()) / 86_400_000);
    await d.ref.update({ accruedFine: fine });
    if (days > 0 && days % 3 === 0 && d.get('lastReminderOn') !== today) {
      await d.ref.update({ lastReminderOn: today });
      await notify(d.get('userId'), 'Still overdue', `"${d.get('bookTitle')}" is ${days} days late. Current fine: ₹${fine}.`, 'overdue', { loanId: d.id });
    }
  }

  // 3. Expire held reservations that were not collected
  const expired = await db.collection('reservations').where('status', '==', 'ready').where('expiresAt', '<', Timestamp.fromDate(now)).get();
  for (const d of expired.docs) await d.ref.update({ status: 'expired', updatedAt: FieldValue.serverTimestamp() });

  logger.info('daily circulation done', { reminders: soon.size, overdue: overdue.size, expired: expired.size });
});

// ---------------------------------------------------------------------------
// Catalogue
// ---------------------------------------------------------------------------

/** Recompute a book's average rating when a review changes. */
export const onReviewWritten = onDocumentWritten('books/{bookId}/reviews/{uid}', async (event) => {
  const reviews = await db.collection('books').doc(event.params.bookId).collection('reviews').get();
  const ratings = reviews.docs.map((d) => Number(d.get('rating')) || 0).filter((r) => r > 0);
  const avg = ratings.length ? ratings.reduce((a, b) => a + b, 0) / ratings.length : 0;
  await db.collection('books').doc(event.params.bookId).update({
    ratingAvg: Math.round(avg * 10) / 10, ratingCount: ratings.length,
  });
});

/** Keep category book counts current. */
export const onBookWritten = onDocumentWritten('books/{bookId}', async (event) => {
  const before: string[] = event.data?.before.get('categories') ?? [];
  const after: string[] = event.data?.after.get('categories') ?? [];
  const touched = new Set([...before, ...after].filter((c) => before.includes(c) !== after.includes(c)));
  for (const slug of touched) {
    const count = await db.collection('books').where('categories', 'array-contains', slug).count().get();
    const cats = await db.collection('categories').where('slug', '==', slug).limit(1).get();
    if (!cats.empty) await cats.docs[0].ref.update({ bookCount: count.data().count });
  }
});

/** Tell members when their purchase suggestion is reviewed. */
export const onBookRequestUpdated = onDocumentUpdated('bookRequests/{id}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;
  const msg: Record<string, string> = {
    approved: 'has been approved and will be ordered',
    acquired: 'is now available in the library',
    rejected: 'could not be added this time',
  };
  if (msg[after.status]) {
    await notify(after.userId, 'Book suggestion update', `Your suggestion "${after.title}" ${msg[after.status]}.${after.adminNote ? ' ' + after.adminNote : ''}`, 'request');
  }
});

/** Published events with `notify: true` are announced to everyone. */
export const onEventWritten = onDocumentWritten('events/{id}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after || !after.published || !after.notify || before?.published) return;
  await db.collection('broadcasts').add({
    title: `New event: ${after.title}`,
    body: `${fmtDate(after.startAt)} · ${after.location ?? 'Rampur Library'}`,
    topic: 'all', link: `/events/${event.params.id}`, imageUrl: after.imageUrl ?? null,
    createdAt: FieldValue.serverTimestamp(), createdBy: 'system',
  });
});

// ---------------------------------------------------------------------------
// Staff & accounts
// ---------------------------------------------------------------------------

/** Admins grant or revoke staff roles. Accepts uid, email or phone (+91...). */
export const setStaffRole = onCall(async (req) => {
  if (req.auth?.token.admin !== true) throw new HttpsError('permission-denied', 'Admins only.');
  const { uid, email, phone, role } = (req.data ?? {}) as { uid?: string; email?: string; phone?: string; role?: string };
  if (!['admin', 'librarian', 'none'].includes(String(role))) throw new HttpsError('invalid-argument', 'role must be admin, librarian or none.');
  const auth = getAuth();
  let user;
  try {
    user = uid ? await auth.getUser(uid) : email ? await auth.getUserByEmail(email) : phone ? await auth.getUserByPhoneNumber(phone) : null;
  } catch {
    user = null;
  }
  if (!user) throw new HttpsError('not-found', 'No account with those details. The person must sign in once first.');
  if (user.uid === req.auth.uid && role !== 'admin') throw new HttpsError('failed-precondition', 'You cannot remove your own admin role.');
  await auth.setCustomUserClaims(user.uid, { admin: role === 'admin', librarian: role === 'librarian' });
  await db.collection('staff').doc(user.uid).set({
    uid: user.uid, email: user.email ?? null, phone: user.phoneNumber ?? null, name: user.displayName ?? null,
    role, updatedAt: FieldValue.serverTimestamp(), updatedBy: req.auth.uid,
  }, { merge: true });
  await db.collection('auditLogs').add({ action: 'set_staff_role', target: user.uid, role, by: req.auth.uid, at: FieldValue.serverTimestamp() });
  return { uid: user.uid, role };
});

/** In-app account deletion (required by App Store / Play policies). */
export const deleteMyAccount = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const active = await db.collection('loans').where('userId', '==', uid).where('status', 'in', ['issued', 'overdue']).limit(1).get();
  if (!active.empty) throw new HttpsError('failed-precondition', 'Please return all borrowed books before deleting your account.');
  const fines = await db.collection('fines').where('userId', '==', uid).where('status', '==', 'unpaid').limit(1).get();
  if (!fines.empty) throw new HttpsError('failed-precondition', 'Please clear outstanding fines before deleting your account.');

  const userRef = db.collection('users').doc(uid);
  await db.recursiveDelete(userRef as DocumentReference);
  const pending = await db.collection('reservations').where('userId', '==', uid).where('status', 'in', ['pending', 'ready']).get();
  for (const r of pending.docs) await r.ref.update({ status: 'cancelled', updatedAt: FieldValue.serverTimestamp() });
  await getAuth().deleteUser(uid);
  await audit('account_deleted', { uid });
  return { ok: true };
});

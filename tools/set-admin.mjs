#!/usr/bin/env node
// Bootstrap the first admin account.
//
//   1. Create the user in Firebase Console → Authentication → Add user (email + password)
//   2. Download a service-account key (Project settings → Service accounts)
//   3. cd functions && GOOGLE_APPLICATION_CREDENTIALS=../service-account.json node ../tools/set-admin.mjs admin@example.com
//
// After this, more staff can be added from the admin panel (Staff page).
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const [emailOrPhone, role = 'admin'] = process.argv.slice(2);
if (!emailOrPhone) {
  console.error('Usage: node tools/set-admin.mjs <email|+91phone> [admin|librarian|none]');
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const auth = getAuth();
const user = emailOrPhone.startsWith('+')
  ? await auth.getUserByPhoneNumber(emailOrPhone)
  : await auth.getUserByEmail(emailOrPhone);

await auth.setCustomUserClaims(user.uid, { admin: role === 'admin', librarian: role === 'librarian' });
await getFirestore().collection('staff').doc(user.uid).set(
  { uid: user.uid, email: user.email ?? null, phone: user.phoneNumber ?? null, role, updatedAt: FieldValue.serverTimestamp(), updatedBy: 'cli' },
  { merge: true },
);
console.log(`✔ ${emailOrPhone} (${user.uid}) is now: ${role}. Sign out and back in to refresh the token.`);
process.exit(0);

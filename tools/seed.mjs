#!/usr/bin/env node
// Seed Firestore with library settings, categories and a starter set of books.
//
//   cd functions && GOOGLE_APPLICATION_CREDENTIALS=../service-account.json node ../tools/seed.mjs
//
// Safe to re-run: documents are written with fixed ids (merge).
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const slugify = (s) => s.toLowerCase().replace(/[^a-z0-9\s-]/g, ' ').trim().replace(/[\s-]+/g, '-') || 'book';
function keywords(title, authors, isbn) {
  const out = new Set();
  for (const text of [title, ...authors]) {
    for (const w of text.toLowerCase().split(/[^a-z0-9ऀ-ॿ]+/)) {
      for (let i = 1; i <= Math.min(w.length, 15); i++) out.add(w.slice(0, i));
    }
  }
  if (isbn) out.add(isbn.toLowerCase());
  return [...out].sort();
}

await db.doc('settings/library').set({
  name: 'Rampur Library',
  tagline: 'Read. Learn. Grow.',
  address: 'Rampur, Uttar Pradesh, India',
  phone: '',
  email: '',
  openingHours: 'Mon–Sat · 9:00 AM – 7:00 PM',
  loanDays: 14, maxRenewals: 2, finePerDay: 5, graceDays: 0, maxFinePerLoan: 500,
  maxLoansPerMember: 3, reservationHoldDays: 3, dueReminderDays: 2, currency: '₹',
}, { merge: true });

const categories = [
  ['Fiction', '📖'], ['Biography', '🧑‍🏫'], ['History', '🏛️'], ['Science', '🔬'], ['Self-help', '🌱'],
  ['Children', '🧸'], ['Hindi Literature', '🪔'], ['Urdu Literature', '🌙'], ['Competitive Exams', '🎯'], ['Religion & Philosophy', '🕉️'],
];
for (const [i, [name, icon]] of categories.entries()) {
  await db.doc(`categories/${slugify(name)}`).set({ name, slug: slugify(name), icon, order: i }, { merge: true });
}

const books = [
  ['Wings of Fire', ['A. P. J. Abdul Kalam', 'Arun Tiwari'], '9788173711466', 'Universities Press', 1999, ['biography'], 'English', 3],
  ['Godaan', ['Munshi Premchand'], '9788171822028', 'Rajpal & Sons', 1936, ['hindi-literature', 'fiction'], 'Hindi', 2],
  ['The Discovery of India', ['Jawaharlal Nehru'], '9780143031031', 'Penguin', 1946, ['history'], 'English', 2],
  ['Gitanjali', ['Rabindranath Tagore'], '9788171676088', 'Rupa', 1910, ['fiction'], 'English', 1],
  ['A Brief History of Time', ['Stephen Hawking'], '9780553380163', 'Bantam', 1988, ['science'], 'English', 2],
  ['Atomic Habits', ['James Clear'], '9780735211292', 'Avery', 2018, ['self-help'], 'English', 3],
  ['The Guide', ['R. K. Narayan'], '9780143039648', 'Penguin', 1958, ['fiction'], 'English', 2],
  ['Panchatantra', ['Vishnu Sharma'], '9788184820325', 'Penguin', 300, ['children'], 'English', 2],
  ['Indian Polity', ['M. Laxmikanth'], '9789355322510', 'McGraw Hill', 2023, ['competitive-exams'], 'English', 4],
  ['Diwan-e-Ghalib', ['Mirza Ghalib'], '9788171678495', 'Rekhta', 1841, ['urdu-literature'], 'Urdu', 1],
  ['Bhagavad Gita As It Is', ['A. C. Bhaktivedanta Swami Prabhupada'], '9788184818185', 'BBT', 1972, ['religion-philosophy'], 'English', 2],
  ['Malgudi Days', ['R. K. Narayan'], '9780143039655', 'Penguin', 1943, ['fiction', 'children'], 'English', 2],
];
for (const [title, authors, isbn, publisher, year, cats, language, copies] of books) {
  const id = `seed-${isbn}`;
  await db.doc(`books/${id}`).set({
    title, subtitle: '', authors, isbn, publisher, publishedYear: year, categories: cats, language,
    description: '', coverUrl: `https://covers.openlibrary.org/b/isbn/${isbn}-L.jpg`, pages: null,
    totalCopies: copies, availableCopies: copies, shelfLocation: '', tags: [], featured: true,
    ratingAvg: 0, ratingCount: 0, ebookUrl: '', price: null,
    slug: `${slugify(title)}-${id.slice(0, 6)}`, searchKeywords: keywords(title, authors, isbn),
    createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}
console.log(`✔ Seeded settings, ${categories.length} categories and ${books.length} books.`);
process.exit(0);

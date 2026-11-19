/**
 * Server-side data access for the public website.
 *
 * Uses the Firestore *lite* client (REST, no realtime) from server components. The
 * catalogue, categories, events and settings are publicly readable by the security
 * rules, so no secrets are needed. If Firebase isn't configured yet, every function
 * returns empty data so the site still builds and renders.
 */
import { getApps, initializeApp, type FirebaseApp } from 'firebase/app';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  limit as qLimit,
  orderBy,
  query,
  where,
  type DocumentData,
  type Firestore,
  type QueryConstraint,
} from 'firebase/firestore/lite';

export const SITE_URL = (process.env.NEXT_PUBLIC_SITE_URL || 'https://rampurlibrary.vercel.app').replace(/\/$/, '');

export interface Book {
  id: string;
  slug: string;
  title: string;
  subtitle: string;
  authors: string[];
  isbn: string;
  publisher: string;
  publishedYear: number | null;
  categories: string[];
  language: string;
  description: string;
  coverUrl: string;
  pages: number | null;
  totalCopies: number;
  availableCopies: number;
  shelfLocation: string;
  ratingAvg: number;
  ratingCount: number;
  featured: boolean;
  updatedAt: string | null;
}

export interface Category {
  id: string;
  name: string;
  slug: string;
  icon: string;
  bookCount: number;
}

export interface LibraryEvent {
  id: string;
  title: string;
  description: string;
  imageUrl: string;
  startAt: string;
  endAt: string | null;
  location: string;
}

export interface Settings {
  name: string;
  tagline: string;
  address: string;
  phone: string;
  email: string;
  openingHours: string;
  loanDays: number;
  maxRenewals: number;
  finePerDay: number;
  maxLoansPerMember: number;
  reservationHoldDays: number;
  currency: string;
  androidAppUrl: string;
  iosAppUrl: string;
}

export const DEFAULT_SETTINGS: Settings = {
  name: 'Rampur Library',
  tagline: 'Read. Learn. Grow.',
  address: '',
  phone: '',
  email: '',
  openingHours: 'Mon–Sat · 9:00 AM – 7:00 PM',
  loanDays: 14,
  maxRenewals: 2,
  finePerDay: 5,
  maxLoansPerMember: 3,
  reservationHoldDays: 3,
  currency: '₹',
  androidAppUrl: '',
  iosAppUrl: '',
};

let db: Firestore | null | undefined;

function firestore(): Firestore | null {
  if (db !== undefined) return db;
  const apiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  if (!apiKey || !projectId) {
    db = null;
    return db;
  }
  const app: FirebaseApp = getApps()[0] ?? initializeApp({ apiKey, projectId, authDomain: `${projectId}.firebaseapp.com` });
  db = getFirestore(app);
  return db;
}

export const isConfigured = () => firestore() !== null;

function toIso(v: unknown): string | null {
  if (!v) return null;
  if (typeof v === 'object' && v !== null && 'toDate' in v && typeof (v as { toDate: () => Date }).toDate === 'function') {
    return (v as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof v === 'string') return v;
  return null;
}

const str = (v: unknown, d = '') => (typeof v === 'string' ? v : d);
const num = (v: unknown, d = 0) => (typeof v === 'number' ? v : Number(v ?? d) || d);
const arr = (v: unknown) => (Array.isArray(v) ? v.map(String) : []);

function toBook(id: string, d: DocumentData): Book {
  return {
    id,
    slug: str(d.slug) || id,
    title: str(d.title, 'Untitled'),
    subtitle: str(d.subtitle),
    authors: arr(d.authors),
    isbn: str(d.isbn),
    publisher: str(d.publisher),
    publishedYear: d.publishedYear ? num(d.publishedYear) : null,
    categories: arr(d.categories),
    language: str(d.language, 'English'),
    description: str(d.description),
    coverUrl: str(d.coverUrl),
    pages: d.pages ? num(d.pages) : null,
    totalCopies: num(d.totalCopies, 1),
    availableCopies: num(d.availableCopies),
    shelfLocation: str(d.shelfLocation),
    ratingAvg: num(d.ratingAvg),
    ratingCount: num(d.ratingCount),
    featured: d.featured === true,
    updatedAt: toIso(d.updatedAt),
  };
}

async function safe<T>(fallback: T, fn: (db: Firestore) => Promise<T>): Promise<T> {
  const f = firestore();
  if (!f) return fallback;
  try {
    return await fn(f);
  } catch (e) {
    console.error('[data]', e);
    return fallback;
  }
}

async function books(...constraints: QueryConstraint[]): Promise<Book[]> {
  return safe([], async (f) => {
    const snap = await getDocs(query(collection(f, 'books'), ...constraints));
    return snap.docs.map((d) => toBook(d.id, d.data()));
  });
}

export async function getSettings(): Promise<Settings> {
  return safe(DEFAULT_SETTINGS, async (f) => {
    const snap = await getDoc(doc(f, 'settings', 'library'));
    return { ...DEFAULT_SETTINGS, ...(snap.data() as Partial<Settings> | undefined) };
  });
}

export const getNewArrivals = (n = 12) => books(orderBy('createdAt', 'desc'), qLimit(n));
export const getFeatured = (n = 8) => books(where('featured', '==', true), orderBy('createdAt', 'desc'), qLimit(n));
export const getPopular = (n = 8) => books(orderBy('ratingCount', 'desc'), qLimit(n));
export const getCatalogue = (n = 60) => books(orderBy('title'), qLimit(n));
export const getCategoryBooks = (slug: string, n = 60) =>
  books(where('categories', 'array-contains', slug), orderBy('createdAt', 'desc'), qLimit(n));

export async function getBookBySlug(slug: string): Promise<Book | null> {
  const bySlug = await books(where('slug', '==', slug), qLimit(1));
  if (bySlug.length) return bySlug[0];
  return safe(null, async (f) => {
    const snap = await getDoc(doc(f, 'books', slug));
    return snap.exists() ? toBook(snap.id, snap.data()) : null;
  });
}

/** Same prefix-keyword search the apps use (see library_core/utils.dart). */
export async function searchBooks(q: string, n = 40): Promise<Book[]> {
  const words = q.toLowerCase().split(/[^a-z0-9ऀ-ॿ]+/).filter(Boolean);
  if (!words.length) return [];
  const digits = q.replace(/[^0-9xX]/g, '');
  const token = digits.length >= 10 ? digits.toLowerCase() : [...words].sort((a, b) => b.length - a.length)[0].slice(0, 15);
  const found = await books(where('searchKeywords', 'array-contains', token), qLimit(n * 2));
  if (digits.length >= 10) return found.slice(0, n);
  return found
    .filter((b) => {
      const hay = `${b.title} ${b.subtitle} ${b.authors.join(' ')}`.toLowerCase();
      return words.every((w) => hay.includes(w));
    })
    .slice(0, n);
}

export async function getCategories(): Promise<Category[]> {
  return safe([], async (f) => {
    const snap = await getDocs(query(collection(f, 'categories'), orderBy('order')));
    return snap.docs.map((d) => {
      const x = d.data();
      return { id: d.id, name: str(x.name), slug: str(x.slug, d.id), icon: str(x.icon), bookCount: num(x.bookCount) };
    });
  });
}

export async function getEvents(n = 20): Promise<LibraryEvent[]> {
  return safe([], async (f) => {
    const snap = await getDocs(query(collection(f, 'events'), where('published', '==', true), orderBy('startAt', 'desc'), qLimit(n)));
    return snap.docs.map((d) => {
      const x = d.data();
      return {
        id: d.id,
        title: str(x.title),
        description: str(x.description),
        imageUrl: str(x.imageUrl),
        startAt: toIso(x.startAt) ?? new Date().toISOString(),
        endAt: toIso(x.endAt),
        location: str(x.location),
      };
    });
  });
}

export async function getSitemapBooks(): Promise<Pick<Book, 'slug' | 'updatedAt'>[]> {
  return (await books(orderBy('title'), qLimit(5000))).map((b) => ({ slug: b.slug, updatedAt: b.updatedAt }));
}

export const bookUrl = (b: Pick<Book, 'slug'>) => `/books/${encodeURIComponent(b.slug)}`;

export function formatDate(iso: string | null, withTime = false): string {
  if (!iso) return '';
  return new Date(iso).toLocaleString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    ...(withTime ? { hour: 'numeric', minute: '2-digit' } : {}),
    timeZone: 'Asia/Kolkata',
  });
}

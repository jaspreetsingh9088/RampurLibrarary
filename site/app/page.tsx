import Link from 'next/link';
import { BookGrid } from '@/components/BookCard';
import { SearchBar } from '@/components/SearchBar';
import { formatDate, getCategories, getEvents, getFeatured, getNewArrivals, getPopular, getSettings } from '@/lib/data';

export const revalidate = 300;

export default async function Home() {
  const [s, featured, arrivals, popular, categories, events] = await Promise.all([
    getSettings(),
    getFeatured(6),
    getNewArrivals(12),
    getPopular(6),
    getCategories(),
    getEvents(6),
  ]);
  const upcoming = events.filter((e) => new Date(e.endAt ?? e.startAt) > new Date()).reverse().slice(0, 3);

  return (
    <>
      <section className="bg-gradient-to-br from-brand to-brand-dark text-white">
        <div className="container-x py-16 sm:py-24">
          <p className="font-semibold tracking-wide text-gold uppercase">{s.tagline}</p>
          <h1 className="mt-3 max-w-3xl text-4xl font-extrabold leading-tight sm:text-5xl">Welcome to {s.name}</h1>
          <p className="mt-4 max-w-2xl text-lg text-slate-200">
            Search thousands of books, see what&apos;s on the shelf right now, and reserve your next read from your phone.
          </p>
          <div className="mt-8 max-w-2xl">
            <SearchBar large />
          </div>
          <div className="mt-6 flex flex-wrap gap-3 text-sm">
            <Link href="/download" className="rounded-full bg-white/10 px-4 py-2 hover:bg-white/20">📱 Get the member app</Link>
            <Link href="/about" className="rounded-full bg-white/10 px-4 py-2 hover:bg-white/20">🕘 {s.openingHours}</Link>
          </div>
        </div>
      </section>

      {categories.length > 0 && (
        <section className="container-x mt-12" aria-labelledby="cats">
          <h2 id="cats" className="text-2xl font-bold text-slate-900">Browse by category</h2>
          <div className="mt-4 flex flex-wrap gap-2">
            {categories.map((c) => (
              <Link key={c.id} href={`/categories/${c.slug}`} className="rounded-full border border-slate-200 bg-white px-4 py-2 text-sm font-medium shadow-sm hover:border-brand hover:text-brand">
                {c.icon || '📚'} {c.name}{c.bookCount ? <span className="text-slate-400"> · {c.bookCount}</span> : null}
              </Link>
            ))}
          </div>
        </section>
      )}

      {featured.length > 0 && (
        <section className="container-x mt-12" aria-labelledby="featured">
          <h2 id="featured" className="mb-5 text-2xl font-bold text-slate-900">Librarian&apos;s picks</h2>
          <BookGrid books={featured} />
        </section>
      )}

      <section className="container-x mt-12" aria-labelledby="new">
        <div className="mb-5 flex items-end justify-between">
          <h2 id="new" className="text-2xl font-bold text-slate-900">New arrivals</h2>
          <Link href="/books" className="text-sm font-semibold text-brand hover:underline">Full catalogue →</Link>
        </div>
        <BookGrid books={arrivals} empty="The catalogue is being set up — check back soon." />
      </section>

      {popular.length > 0 && popular.some((b) => b.ratingCount > 0) && (
        <section className="container-x mt-12" aria-labelledby="popular">
          <h2 id="popular" className="mb-5 text-2xl font-bold text-slate-900">Most reviewed by members</h2>
          <BookGrid books={popular} />
        </section>
      )}

      {upcoming.length > 0 && (
        <section className="container-x mt-12" aria-labelledby="events">
          <div className="mb-5 flex items-end justify-between">
            <h2 id="events" className="text-2xl font-bold text-slate-900">Upcoming events</h2>
            <Link href="/events" className="text-sm font-semibold text-brand hover:underline">All events →</Link>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            {upcoming.map((e) => (
              <article key={e.id} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                <p className="text-sm font-semibold text-gold">{formatDate(e.startAt, true)}</p>
                <h3 className="mt-1 font-bold text-slate-900">{e.title}</h3>
                <p className="mt-2 line-clamp-3 text-sm text-slate-600">{e.description}</p>
              </article>
            ))}
          </div>
        </section>
      )}

      <section className="container-x mt-16">
        <div className="grid items-center gap-8 rounded-3xl bg-white p-8 shadow-sm ring-1 ring-slate-200 sm:grid-cols-2 sm:p-12">
          <div>
            <h2 className="text-3xl font-extrabold text-slate-900">Your library card, in your pocket</h2>
            <ul className="mt-4 space-y-2 text-slate-600">
              <li>✅ Log in with your mobile number — no passwords</li>
              <li>✅ Reserve books and get notified when they&apos;re ready</li>
              <li>✅ Renew loans and get due-date reminders</li>
              <li>✅ Digital membership card with QR code</li>
            </ul>
            <Link href="/download" className="mt-6 inline-block rounded-xl bg-brand px-6 py-3 font-semibold text-white hover:bg-brand-dark">Download the app</Link>
          </div>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/logo.png" alt={`${s.name} app`} width={260} height={260} className="mx-auto rounded-3xl shadow-xl" />
        </div>
      </section>
    </>
  );
}

import type { Metadata } from 'next';
import { JsonLd } from '@/components/JsonLd';
import { SITE_URL, formatDate, getEvents, getSettings } from '@/lib/data';

export const revalidate = 300;
export const metadata: Metadata = {
  title: 'Events & workshops',
  description: 'Story time, book clubs, author talks and workshops at the library.',
  alternates: { canonical: '/events' },
};

export default async function EventsPage() {
  const [events, s] = await Promise.all([getEvents(40), getSettings()]);
  const now = new Date();
  const upcoming = events.filter((e) => new Date(e.endAt ?? e.startAt) >= now).reverse();
  const past = events.filter((e) => new Date(e.endAt ?? e.startAt) < now);
  return (
    <div className="container-x py-10">
      <JsonLd
        data={upcoming.map((e) => ({
          '@context': 'https://schema.org',
          '@type': 'Event',
          name: e.title,
          description: e.description,
          startDate: e.startAt,
          ...(e.endAt ? { endDate: e.endAt } : {}),
          eventAttendanceMode: 'https://schema.org/OfflineEventAttendanceMode',
          eventStatus: 'https://schema.org/EventScheduled',
          location: { '@type': 'Place', name: e.location || s.name, address: s.address || e.location || s.name },
          ...(e.imageUrl ? { image: e.imageUrl } : {}),
          organizer: { '@type': 'Library', name: s.name, url: SITE_URL },
          isAccessibleForFree: true,
        }))}
      />
      <h1 className="text-3xl font-extrabold text-slate-900">Events & workshops</h1>
      {events.length === 0 && <p className="mt-6 text-slate-500">No events scheduled yet. Follow us in the app to hear first.</p>}
      {upcoming.length > 0 && <h2 className="mt-8 text-xl font-bold">Upcoming</h2>}
      <div className="mt-4 grid gap-5 sm:grid-cols-2">
        {upcoming.map((e) => (
          <article key={e.id} className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            {e.imageUrl && <img src={e.imageUrl} alt="" loading="lazy" className="aspect-video w-full object-cover" />}
            <div className="p-5">
              <p className="text-sm font-semibold text-gold">{formatDate(e.startAt, true)}{e.endAt ? ` – ${formatDate(e.endAt, true)}` : ''}</p>
              <h3 className="mt-1 text-lg font-bold text-slate-900">{e.title}</h3>
              {e.location && <p className="text-sm text-slate-500">📍 {e.location}</p>}
              <p className="mt-3 whitespace-pre-line text-slate-600">{e.description}</p>
            </div>
          </article>
        ))}
      </div>
      {past.length > 0 && (
        <>
          <h2 className="mt-12 text-xl font-bold">Past events</h2>
          <ul className="mt-3 divide-y divide-slate-200 rounded-2xl bg-white ring-1 ring-slate-200">
            {past.map((e) => (
              <li key={e.id} className="flex justify-between gap-4 p-4 text-sm"><span className="font-medium">{e.title}</span><span className="text-slate-500">{formatDate(e.startAt)}</span></li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}

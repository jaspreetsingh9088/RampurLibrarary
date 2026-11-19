import type { Metadata } from 'next';
import { getSettings } from '@/lib/data';

export const revalidate = 600;
export const metadata: Metadata = {
  title: 'Visit, membership & borrowing rules',
  description: 'Opening hours, address, how to become a member and the library borrowing rules.',
  alternates: { canonical: '/about' },
};

export default async function AboutPage() {
  const s = await getSettings();
  return (
    <div className="container-x py-10">
      <h1 className="text-3xl font-extrabold text-slate-900">Visit {s.name}</h1>
      <div className="mt-8 grid gap-6 md:grid-cols-2">
        <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
          <h2 className="text-xl font-bold">Opening hours & contact</h2>
          <p className="mt-3">🕘 {s.openingHours}</p>
          {s.address && <p className="mt-2">📍 {s.address}</p>}
          {s.phone && <p className="mt-2">📞 <a className="text-brand hover:underline" href={`tel:${s.phone}`}>{s.phone}</a></p>}
          {s.email && <p className="mt-2">✉️ <a className="text-brand hover:underline" href={`mailto:${s.email}`}>{s.email}</a></p>}
          {s.address && (
            <iframe
              title="Map"
              className="mt-5 h-64 w-full rounded-xl border-0"
              loading="lazy"
              referrerPolicy="no-referrer-when-downgrade"
              src={`https://maps.google.com/maps?q=${encodeURIComponent(s.address)}&output=embed`}
            />
          )}
        </section>
        <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
          <h2 className="text-xl font-bold">Becoming a member</h2>
          <ol className="mt-3 list-decimal space-y-2 pl-5 text-slate-700">
            <li>Download the app and sign in with your mobile number (OTP).</li>
            <li>Complete your profile — you&apos;ll get a membership number instantly.</li>
            <li>Show the QR code on your digital card at the desk to borrow books.</li>
          </ol>
          <p className="mt-3 text-sm text-slate-500">No smartphone? Visit the desk and staff will register you.</p>
          <h2 className="mt-8 text-xl font-bold">Borrowing rules</h2>
          <ul className="mt-3 list-disc space-y-1 pl-5 text-slate-700">
            <li>Borrow up to {s.maxLoansPerMember} books at a time</li>
            <li>Loan period: {s.loanDays} days</li>
            <li>Renew up to {s.maxRenewals} times if nobody is waiting</li>
            <li>Late fine: {s.currency}{s.finePerDay} per day per book</li>
            <li>Reserved books are held for {s.reservationHoldDays} days</li>
          </ul>
        </section>
      </div>
    </div>
  );
}

import type { Metadata } from 'next';
import { getSettings } from '@/lib/data';

export const metadata: Metadata = { title: 'Terms of use', alternates: { canonical: '/terms' } };

export default async function Terms() {
  const s = await getSettings();
  return (
    <div className="container-x prose-lite max-w-3xl py-10">
      <h1 className="mb-6 text-3xl font-extrabold text-slate-900">Terms of use</h1>
      <p>By using the {s.name} app or website you agree to these terms and to the library&apos;s borrowing rules.</p>
      <h2>Membership</h2>
      <p>Each membership is personal. Keep your phone secure — anyone with access to your signed-in app can show your membership card.</p>
      <h2>Borrowing</h2>
      <ul>
        <li>You may borrow up to {s.maxLoansPerMember} books for {s.loanDays} days each.</li>
        <li>Late returns are charged {s.currency}{s.finePerDay} per day. Lost or damaged books must be replaced or paid for.</li>
        <li>Reserved books not collected within {s.reservationHoldDays} days are released to the next member.</li>
      </ul>
      <h2>Reviews and suggestions</h2>
      <p>Keep reviews respectful. The library may remove content that is offensive or unrelated to the book.</p>
      <h2>Suspension</h2>
      <p>The library may suspend memberships for unpaid dues, repeated late returns or misuse.</p>
    </div>
  );
}

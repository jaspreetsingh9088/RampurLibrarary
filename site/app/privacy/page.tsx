import type { Metadata } from 'next';
import { getSettings } from '@/lib/data';

export const metadata: Metadata = { title: 'Privacy policy', alternates: { canonical: '/privacy' } };

export default async function Privacy() {
  const s = await getSettings();
  return (
    <div className="container-x prose-lite max-w-3xl py-10">
      <h1 className="mb-6 text-3xl font-extrabold text-slate-900">Privacy policy</h1>
      <p>This policy explains what {s.name} (&quot;we&quot;) collects through the member app and website, and how it is used.</p>
      <h2>What we collect</h2>
      <ul>
        <li>Your mobile number, used to sign you in with a one-time password (OTP).</li>
        <li>Profile details you choose to add: name, email, address, date of birth, gender, photo and favourite genres.</li>
        <li>Library records: books borrowed and returned, reservations, fines, reviews and book suggestions.</li>
        <li>A device notification token, so we can send due-date reminders and library news.</li>
        <li>Anonymous usage statistics (Firebase Analytics) to improve the app.</li>
      </ul>
      <h2>How we use it</h2>
      <p>Only to run the library: managing your membership, loans, reservations and fines, and sending you service notifications. We do not sell your data or use it for advertising.</p>
      <h2>Where it is stored</h2>
      <p>Data is stored securely in Google Firebase. Access is limited to you and authorised library staff.</p>
      <h2>Your choices</h2>
      <ul>
        <li>Turn push notifications off in the app&apos;s settings.</li>
        <li>Edit your profile at any time.</li>
        <li>Delete your account from Settings → Delete my account (after returning books and clearing dues).</li>
      </ul>
      <h2>Contact</h2>
      <p>Questions? {s.email ? <>Email <a className="text-brand" href={`mailto:${s.email}`}>{s.email}</a>{s.phone ? ' or call ' : ''}</> : null}{s.phone ? s.phone : null}{!s.email && !s.phone ? 'Please ask at the library desk.' : '.'}</p>
    </div>
  );
}

import type { Metadata } from 'next';
import { getSettings } from '@/lib/data';

export const revalidate = 600;
export const metadata: Metadata = {
  title: 'Download the member app',
  description: 'Get the library app for Android and iPhone: OTP login, reservations, renewals, reminders and a digital membership card.',
  alternates: { canonical: '/download' },
};

const RELEASES = 'https://github.com/jaspreetsingh9088/RampurLibrarary/releases/latest';

export default async function DownloadPage() {
  const s = await getSettings();
  const android = s.androidAppUrl || RELEASES;
  return (
    <div className="container-x py-12 text-center">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/logo.png" alt="" width={110} height={110} className="mx-auto rounded-3xl shadow-lg" />
      <h1 className="mt-6 text-4xl font-extrabold text-slate-900">{s.name} app</h1>
      <p className="mx-auto mt-3 max-w-xl text-lg text-slate-600">Search, reserve, renew and get reminders — your library card lives on your phone.</p>
      <div className="mt-8 flex flex-wrap justify-center gap-4">
        <a href={android} className="rounded-xl bg-slate-900 px-6 py-4 text-left text-white hover:bg-slate-700">
          <span className="block text-xs">Download for</span><span className="text-lg font-bold">Android</span>
        </a>
        {s.iosAppUrl ? (
          <a href={s.iosAppUrl} className="rounded-xl bg-slate-900 px-6 py-4 text-left text-white hover:bg-slate-700">
            <span className="block text-xs">Download on the</span><span className="text-lg font-bold">App Store</span>
          </a>
        ) : (
          <span className="rounded-xl bg-slate-200 px-6 py-4 text-left text-slate-500">
            <span className="block text-xs">iPhone</span><span className="text-lg font-bold">Coming soon</span>
          </span>
        )}
      </div>
      <p className="mt-6 text-sm text-slate-500">Android: if your phone asks, allow installing apps from your browser.</p>
    </div>
  );
}

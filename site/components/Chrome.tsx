import Link from 'next/link';
import type { Settings } from '@/lib/data';

export function Header({ settings }: { settings: Settings }) {
  return (
    <header className="sticky top-0 z-20 border-b border-slate-200 bg-white/90 backdrop-blur">
      <nav className="container-x flex h-16 items-center justify-between" aria-label="Main">
        <Link href="/" className="flex items-center gap-2 font-extrabold text-brand">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/logo.png" alt="" width={36} height={36} className="rounded-lg" />
          <span>{settings.name}</span>
        </Link>
        <div className="flex items-center gap-1 text-sm font-medium sm:gap-4">
          <Link href="/books" className="rounded-lg px-2 py-1 hover:bg-slate-100">Catalogue</Link>
          <Link href="/events" className="hidden rounded-lg px-2 py-1 hover:bg-slate-100 sm:inline">Events</Link>
          <Link href="/about" className="hidden rounded-lg px-2 py-1 hover:bg-slate-100 sm:inline">Visit</Link>
          <Link href="/download" className="rounded-lg bg-brand px-3 py-1.5 text-white hover:bg-brand-dark">Get the app</Link>
        </div>
      </nav>
    </header>
  );
}

export function Footer({ settings }: { settings: Settings }) {
  return (
    <footer className="mt-16 bg-brand-dark text-slate-300">
      <div className="container-x grid gap-8 py-10 sm:grid-cols-3">
        <div>
          <p className="text-lg font-bold text-white">{settings.name}</p>
          <p className="mt-1 text-sm">{settings.tagline}</p>
          {settings.address && <p className="mt-3 text-sm">{settings.address}</p>}
        </div>
        <div className="text-sm">
          <p className="font-semibold text-white">Opening hours</p>
          <p className="mt-1">{settings.openingHours}</p>
          {settings.phone && <p className="mt-3">📞 <a href={`tel:${settings.phone}`} className="hover:text-white">{settings.phone}</a></p>}
          {settings.email && <p>✉️ <a href={`mailto:${settings.email}`} className="hover:text-white">{settings.email}</a></p>}
        </div>
        <ul className="space-y-1 text-sm">
          <li><Link href="/books" className="hover:text-white">Browse the catalogue</Link></li>
          <li><Link href="/events" className="hover:text-white">Events & workshops</Link></li>
          <li><Link href="/about" className="hover:text-white">Membership & rules</Link></li>
          <li><Link href="/download" className="hover:text-white">Download the app</Link></li>
          <li><Link href="/privacy" className="hover:text-white">Privacy policy</Link></li>
          <li><Link href="/terms" className="hover:text-white">Terms of use</Link></li>
        </ul>
      </div>
      <p className="border-t border-white/10 py-4 text-center text-xs">© {new Date().getFullYear()} {settings.name}. All rights reserved.</p>
    </footer>
  );
}

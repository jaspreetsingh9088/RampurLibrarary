import type { Metadata, Viewport } from 'next';
import './globals.css';
import { Footer, Header } from '@/components/Chrome';
import { JsonLd } from '@/components/JsonLd';
import { SITE_URL, getSettings } from '@/lib/data';

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const s = await getSettings();
  const description = `${s.name} — search the catalogue, check availability, reserve books and renew loans online. ${s.tagline}`;
  return {
    metadataBase: new URL(SITE_URL),
    title: { default: `${s.name} · ${s.tagline}`, template: `%s · ${s.name}` },
    description,
    applicationName: s.name,
    keywords: ['Rampur library', 'public library Rampur', 'library catalogue', 'borrow books', 'library membership', 'books Rampur'],
    alternates: { canonical: '/' },
    openGraph: { type: 'website', siteName: s.name, title: s.name, description, url: SITE_URL, images: [{ url: '/og.png', width: 1200, height: 630 }], locale: 'en_IN' },
    twitter: { card: 'summary_large_image', title: s.name, description, images: ['/og.png'] },
    icons: { icon: '/favicon.png', apple: '/apple-touch-icon.png' },
    robots: { index: true, follow: true, googleBot: { index: true, follow: true, 'max-image-preview': 'large' } },
    verification: process.env.GOOGLE_SITE_VERIFICATION ? { google: process.env.GOOGLE_SITE_VERIFICATION } : undefined,
  };
}

export const viewport: Viewport = { themeColor: '#1e4d6b', width: 'device-width', initialScale: 1 };

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const s = await getSettings();
  return (
    <html lang="en">
      <body className="flex min-h-screen flex-col">
        <JsonLd
          data={{
            '@context': 'https://schema.org',
            '@type': 'Library',
            name: s.name,
            url: SITE_URL,
            logo: `${SITE_URL}/logo.png`,
            image: `${SITE_URL}/og.png`,
            ...(s.address ? { address: s.address } : {}),
            ...(s.phone ? { telephone: s.phone } : {}),
            ...(s.email ? { email: s.email } : {}),
            openingHours: s.openingHours,
            potentialAction: {
              '@type': 'SearchAction',
              target: { '@type': 'EntryPoint', urlTemplate: `${SITE_URL}/books?q={search_term_string}` },
              'query-input': 'required name=search_term_string',
            },
          }}
        />
        <Header settings={s} />
        <main className="flex-1">{children}</main>
        <Footer settings={s} />
      </body>
    </html>
  );
}

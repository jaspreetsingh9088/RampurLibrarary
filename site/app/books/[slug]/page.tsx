import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { BookGrid, Cover } from '@/components/BookCard';
import { JsonLd } from '@/components/JsonLd';
import { SITE_URL, bookUrl, getBookBySlug, getCategories, getCategoryBooks, getSettings } from '@/lib/data';

export const revalidate = 600;

type Props = { params: Promise<{ slug: string }> };

// Pages are rendered on first request, then cached and revalidated (ISR).
export async function generateStaticParams() {
  return [];
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const book = await getBookBySlug(decodeURIComponent(slug));
  if (!book) return { title: 'Book not found', robots: { index: false } };
  const by = book.authors.length ? ` by ${book.authors.join(', ')}` : '';
  const description = (book.description || `${book.title}${by} is available to borrow at the library.`).slice(0, 160);
  return {
    title: `${book.title}${by}`,
    description,
    alternates: { canonical: bookUrl(book) },
    openGraph: {
      type: 'book',
      title: `${book.title}${by}`,
      description,
      url: `${SITE_URL}${bookUrl(book)}`,
      images: book.coverUrl ? [{ url: book.coverUrl, alt: book.title }] : [{ url: '/og.png' }],
      ...(book.isbn ? { isbn: book.isbn } : {}),
      authors: book.authors,
    },
    twitter: { card: 'summary_large_image' },
  };
}

export default async function BookPage({ params }: Props) {
  const { slug } = await params;
  const book = await getBookBySlug(decodeURIComponent(slug));
  if (!book) notFound();
  const [settings, categories, related] = await Promise.all([
    getSettings(),
    getCategories(),
    book.categories[0] ? getCategoryBooks(book.categories[0], 13) : Promise.resolve([]),
  ]);
  const catName = (s: string) => categories.find((c) => c.slug === s)?.name ?? s;
  const more = related.filter((b) => b.id !== book.id).slice(0, 6);

  return (
    <div className="container-x py-10">
      <JsonLd
        data={[
          {
            '@context': 'https://schema.org',
            '@type': 'Book',
            name: book.title,
            ...(book.subtitle ? { alternativeHeadline: book.subtitle } : {}),
            author: book.authors.map((a) => ({ '@type': 'Person', name: a })),
            ...(book.isbn ? { isbn: book.isbn } : {}),
            ...(book.publisher ? { publisher: { '@type': 'Organization', name: book.publisher } } : {}),
            ...(book.publishedYear ? { datePublished: String(book.publishedYear) } : {}),
            ...(book.pages ? { numberOfPages: book.pages } : {}),
            inLanguage: book.language,
            ...(book.coverUrl ? { image: book.coverUrl } : {}),
            ...(book.description ? { description: book.description } : {}),
            url: `${SITE_URL}${bookUrl(book)}`,
            ...(book.ratingCount > 0
              ? { aggregateRating: { '@type': 'AggregateRating', ratingValue: book.ratingAvg, ratingCount: book.ratingCount, bestRating: 5, worstRating: 1 } }
              : {}),
            offers: {
              '@type': 'Offer',
              price: 0,
              priceCurrency: 'INR',
              availability: book.availableCopies > 0 ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock',
              seller: { '@type': 'Library', name: settings.name },
              description: 'Free to borrow for library members',
            },
          },
          {
            '@context': 'https://schema.org',
            '@type': 'BreadcrumbList',
            itemListElement: [
              { '@type': 'ListItem', position: 1, name: 'Home', item: SITE_URL },
              { '@type': 'ListItem', position: 2, name: 'Catalogue', item: `${SITE_URL}/books` },
              { '@type': 'ListItem', position: 3, name: book.title, item: `${SITE_URL}${bookUrl(book)}` },
            ],
          },
        ]}
      />
      <nav className="text-sm text-slate-500" aria-label="Breadcrumb">
        <Link href="/" className="hover:text-brand">Home</Link> › <Link href="/books" className="hover:text-brand">Catalogue</Link> › <span>{book.title}</span>
      </nav>

      <article className="mt-6 grid gap-10 md:grid-cols-[260px_1fr]">
        <div className="mx-auto w-52 md:w-full"><Cover book={book} /></div>
        <div>
          <h1 className="text-3xl font-extrabold leading-tight text-slate-900 sm:text-4xl">{book.title}</h1>
          {book.subtitle && <p className="mt-1 text-lg text-slate-600">{book.subtitle}</p>}
          <p className="mt-2 text-lg font-semibold text-brand">{book.authors.join(', ') || 'Unknown author'}</p>

          <div className="mt-4 flex flex-wrap items-center gap-2 text-sm">
            <span className={`rounded-full px-3 py-1 font-semibold ${book.availableCopies > 0 ? 'bg-green-100 text-green-800' : 'bg-orange-100 text-orange-800'}`}>
              {book.availableCopies > 0 ? `${book.availableCopies} of ${book.totalCopies} available` : 'All copies on loan'}
            </span>
            {book.ratingCount > 0 && <span className="rounded-full bg-amber-100 px-3 py-1 font-semibold text-amber-800">★ {book.ratingAvg.toFixed(1)} ({book.ratingCount} reviews)</span>}
            {book.shelfLocation && <span className="rounded-full bg-slate-100 px-3 py-1">Shelf {book.shelfLocation}</span>}
          </div>

          {book.description && <div className="prose-lite mt-6 max-w-none whitespace-pre-line text-slate-700">{book.description}</div>}

          <dl className="mt-6 grid grid-cols-2 gap-x-6 gap-y-3 text-sm sm:grid-cols-3">
            {book.publisher && (<div><dt className="text-slate-500">Publisher</dt><dd className="font-medium">{book.publisher}</dd></div>)}
            {book.publishedYear && (<div><dt className="text-slate-500">Published</dt><dd className="font-medium">{book.publishedYear}</dd></div>)}
            {book.pages && (<div><dt className="text-slate-500">Pages</dt><dd className="font-medium">{book.pages}</dd></div>)}
            <div><dt className="text-slate-500">Language</dt><dd className="font-medium">{book.language}</dd></div>
            {book.isbn && (<div><dt className="text-slate-500">ISBN</dt><dd className="font-medium">{book.isbn}</dd></div>)}
            {book.categories.length > 0 && (
              <div>
                <dt className="text-slate-500">Category</dt>
                <dd className="font-medium">
                  {book.categories.map((c, i) => (
                    <span key={c}>{i > 0 && ', '}<Link href={`/categories/${c}`} className="text-brand hover:underline">{catName(c)}</Link></span>
                  ))}
                </dd>
              </div>
            )}
          </dl>

          <div className="mt-8 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
            <p className="font-semibold text-slate-900">{book.availableCopies > 0 ? 'Want to borrow it?' : 'Join the waiting list'}</p>
            <p className="mt-1 text-sm text-slate-600">
              Members can reserve this book in the app and pick it up at the desk. Loans last {settings.loanDays} days and can be renewed up to {settings.maxRenewals} times.
            </p>
            <Link href="/download" className="mt-4 inline-block rounded-xl bg-brand px-5 py-2.5 font-semibold text-white hover:bg-brand-dark">Reserve in the app</Link>
          </div>
        </div>
      </article>

      {more.length > 0 && (
        <section className="mt-14">
          <h2 className="mb-5 text-2xl font-bold text-slate-900">More in {catName(book.categories[0])}</h2>
          <BookGrid books={more} />
        </section>
      )}
    </div>
  );
}

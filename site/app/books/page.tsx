import type { Metadata } from 'next';
import Link from 'next/link';
import { BookGrid } from '@/components/BookCard';
import { SearchBar } from '@/components/SearchBar';
import { getCatalogue, getCategories, searchBooks } from '@/lib/data';

export const revalidate = 300;

type Props = { searchParams: Promise<{ q?: string }> };

export async function generateMetadata({ searchParams }: Props): Promise<Metadata> {
  const { q } = await searchParams;
  return q
    ? { title: `Search results for “${q}”`, robots: { index: false, follow: true } }
    : { title: 'Library catalogue', description: 'Browse every book in the library, check availability and reserve online.', alternates: { canonical: '/books' } };
}

export default async function BooksPage({ searchParams }: Props) {
  const { q = '' } = await searchParams;
  const [books, categories] = await Promise.all([q ? searchBooks(q, 60) : getCatalogue(120), getCategories()]);
  return (
    <div className="container-x py-10">
      <nav className="text-sm text-slate-500" aria-label="Breadcrumb"><Link href="/" className="hover:text-brand">Home</Link> › Catalogue</nav>
      <h1 className="mt-2 text-3xl font-extrabold text-slate-900">{q ? `Results for “${q}”` : 'Library catalogue'}</h1>
      <div className="mt-5 max-w-2xl"><SearchBar defaultValue={q} /></div>
      {categories.length > 0 && (
        <div className="mt-5 flex flex-wrap gap-2">
          {categories.map((c) => (
            <Link key={c.id} href={`/categories/${c.slug}`} className="rounded-full border border-slate-200 bg-white px-3 py-1 text-sm hover:border-brand hover:text-brand">{c.name}</Link>
          ))}
        </div>
      )}
      <p className="mt-6 mb-4 text-sm text-slate-500">{books.length} book{books.length === 1 ? '' : 's'}{q ? ' found' : ''}</p>
      <BookGrid books={books} empty={q ? 'No books matched. Try another word, or suggest the book from the app.' : 'The catalogue is being set up.'} />
    </div>
  );
}

import Link from 'next/link';
import { bookUrl, type Book } from '@/lib/data';

export function Cover({ book, className = '' }: { book: Pick<Book, 'title' | 'coverUrl'>; className?: string }) {
  if (book.coverUrl) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={book.coverUrl} alt={`Cover of ${book.title}`} loading="lazy" width={300} height={440} className={`aspect-[3/4.4] w-full rounded-lg object-cover shadow-sm ${className}`} />;
  }
  return (
    <div className={`flex aspect-[3/4.4] w-full items-center justify-center rounded-lg bg-gradient-to-br from-brand to-brand-dark p-3 text-center text-sm font-bold text-white shadow-sm ${className}`}>
      {book.title}
    </div>
  );
}

export function BookCard({ book }: { book: Book }) {
  return (
    <Link href={bookUrl(book)} className="group block" title={book.title}>
      <Cover book={book} className="transition group-hover:-translate-y-1 group-hover:shadow-lg" />
      <h3 className="mt-2 line-clamp-2 text-sm font-semibold text-slate-900 group-hover:text-brand">{book.title}</h3>
      <p className="line-clamp-1 text-xs text-slate-500">{book.authors.join(', ') || 'Unknown author'}</p>
      <p className={`mt-1 text-xs font-semibold ${book.availableCopies > 0 ? 'text-green-700' : 'text-orange-600'}`}>
        {book.availableCopies > 0 ? `${book.availableCopies} available` : 'On loan'}
      </p>
    </Link>
  );
}

export function BookGrid({ books, empty = 'No books yet.' }: { books: Book[]; empty?: string }) {
  if (!books.length) return <p className="rounded-xl border border-dashed border-slate-300 p-8 text-center text-slate-500">{empty}</p>;
  return (
    <div className="grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6">
      {books.map((b) => (
        <BookCard key={b.id} book={b} />
      ))}
    </div>
  );
}

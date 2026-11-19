import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { BookGrid } from '@/components/BookCard';
import { getCategories, getCategoryBooks } from '@/lib/data';

export const revalidate = 600;

type Props = { params: Promise<{ slug: string }> };

// Pages are rendered on first request, then cached and revalidated (ISR).
export async function generateStaticParams() {
  return [];
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const cat = (await getCategories()).find((c) => c.slug === slug);
  const name = cat?.name ?? slug;
  return {
    title: `${name} books`,
    description: `Browse ${name.toLowerCase()} books available to borrow at the library.`,
    alternates: { canonical: `/categories/${slug}` },
  };
}

export default async function CategoryPage({ params }: Props) {
  const { slug } = await params;
  const [cats, books] = await Promise.all([getCategories(), getCategoryBooks(slug, 120)]);
  const cat = cats.find((c) => c.slug === slug);
  if (!cat && books.length === 0) notFound();
  return (
    <div className="container-x py-10">
      <nav className="text-sm text-slate-500" aria-label="Breadcrumb">
        <Link href="/" className="hover:text-brand">Home</Link> › <Link href="/books" className="hover:text-brand">Catalogue</Link> › {cat?.name ?? slug}
      </nav>
      <h1 className="mt-2 mb-8 text-3xl font-extrabold text-slate-900">{cat?.icon} {cat?.name ?? slug}</h1>
      <BookGrid books={books} />
    </div>
  );
}

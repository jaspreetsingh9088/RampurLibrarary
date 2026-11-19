import Link from 'next/link';
import { SearchBar } from '@/components/SearchBar';

export default function NotFound() {
  return (
    <div className="container-x py-20 text-center">
      <p className="text-6xl">📕</p>
      <h1 className="mt-4 text-3xl font-extrabold text-slate-900">Page not found</h1>
      <p className="mt-2 text-slate-600">That page may have been moved. Try searching the catalogue:</p>
      <div className="mx-auto mt-6 max-w-xl"><SearchBar /></div>
      <Link href="/" className="mt-6 inline-block text-brand hover:underline">← Back home</Link>
    </div>
  );
}

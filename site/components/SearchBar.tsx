export function SearchBar({ defaultValue = '', large = false }: { defaultValue?: string; large?: boolean }) {
  return (
    <form action="/books" method="get" role="search" className="flex w-full gap-2">
      <label htmlFor="q" className="sr-only">Search books</label>
      <input
        id="q"
        name="q"
        type="search"
        defaultValue={defaultValue}
        placeholder="Search by title, author or ISBN"
        className={`w-full rounded-xl border border-slate-300 bg-white px-4 text-slate-900 shadow-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/30 ${large ? 'py-4 text-lg' : 'py-2.5'}`}
      />
      <button type="submit" className={`rounded-xl bg-gold font-semibold text-slate-900 shadow-sm hover:brightness-95 ${large ? 'px-6 text-lg' : 'px-4'}`}>
        Search
      </button>
    </form>
  );
}

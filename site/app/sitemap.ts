import type { MetadataRoute } from 'next';
import { SITE_URL, getCategories, getSitemapBooks } from '@/lib/data';

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [books, cats] = await Promise.all([getSitemapBooks(), getCategories()]);
  const now = new Date();
  return [
    { url: SITE_URL, lastModified: now, changeFrequency: 'daily', priority: 1 },
    { url: `${SITE_URL}/books`, lastModified: now, changeFrequency: 'daily', priority: 0.9 },
    { url: `${SITE_URL}/events`, lastModified: now, changeFrequency: 'weekly', priority: 0.7 },
    { url: `${SITE_URL}/about`, changeFrequency: 'monthly', priority: 0.6 },
    { url: `${SITE_URL}/download`, changeFrequency: 'monthly', priority: 0.6 },
    { url: `${SITE_URL}/privacy`, changeFrequency: 'yearly', priority: 0.2 },
    { url: `${SITE_URL}/terms`, changeFrequency: 'yearly', priority: 0.2 },
    ...cats.map((c) => ({ url: `${SITE_URL}/categories/${c.slug}`, changeFrequency: 'weekly' as const, priority: 0.7 })),
    ...books.map((b) => ({
      url: `${SITE_URL}/books/${encodeURIComponent(b.slug)}`,
      lastModified: b.updatedAt ? new Date(b.updatedAt) : undefined,
      changeFrequency: 'weekly' as const,
      priority: 0.8,
    })),
  ];
}

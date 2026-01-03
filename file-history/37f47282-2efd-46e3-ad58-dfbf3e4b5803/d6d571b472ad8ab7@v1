'use client';

/**
 * Supporti Page (Wave 4)
 * Consolidated archive for all learning materials
 * Route: /supporti
 */

import { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { SupportiView } from './components/supporti-view';

function SupportiContent() {
  const searchParams = useSearchParams();

  // Extract filter params from URL
  const type = searchParams.get('type') || undefined;
  const subject = searchParams.get('subject') || undefined;
  const maestro = searchParams.get('maestro') || undefined;
  const source = searchParams.get('source') || undefined;

  return (
    <SupportiView
      initialType={type}
      initialSubject={subject}
      initialMaestro={maestro}
      initialSource={source}
    />
  );
}

export default function SupportiPage() {
  return (
    <main className="h-full">
      <Suspense fallback={
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin w-8 h-8 border-2 border-primary border-t-transparent rounded-full" />
        </div>
      }>
        <SupportiContent />
      </Suspense>
    </main>
  );
}

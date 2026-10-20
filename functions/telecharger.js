// Sert le dernier APK publié sous l'adresse du site (kounadia.pages.dev/telecharger).
export async function onRequest() {
  const r = await fetch('https://github.com/barroapk/kounadia-app/releases/latest/download/kounadia.apk', { redirect: 'follow' });
  if (!r.ok) return new Response('Téléchargement indisponible, réessaie dans un instant.', { status: 502 });
  const h = new Headers({
    'Content-Type': 'application/vnd.android.package-archive',
    'Content-Disposition': 'attachment; filename="kounadia.apk"',
    'Cache-Control': 'no-store',
  });
  const len = r.headers.get('Content-Length');
  if (len) h.set('Content-Length', len);
  return new Response(r.body, { headers: h });
}

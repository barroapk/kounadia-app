// Sert l'APK de KOUNADIA V2 (essai) sous l'adresse du site (kounadia.pages.dev/telecharger-v2).
// Publication à part (« v2-apk ») : le lien de KOUNADIA (/telecharger) ne change pas.
export async function onRequest() {
  const r = await fetch('https://github.com/barroapk/kounadia-app/releases/download/v2-apk/kounadia-v2.apk', { redirect: 'follow' });
  if (!r.ok) return new Response('Téléchargement indisponible, réessaie dans un instant.', { status: 502 });
  const h = new Headers({
    'Content-Type': 'application/vnd.android.package-archive',
    'Content-Disposition': 'attachment; filename="kounadia-v2.apk"',
    'Cache-Control': 'no-store',
  });
  const len = r.headers.get('Content-Length');
  if (len) h.set('Content-Length', len);
  return new Response(r.body, { headers: h });
}

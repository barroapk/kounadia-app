{{flutter_js}}
{{flutter_build_config}}
// Pas de « service worker » : l'app se met à jour toute seule à chaque ouverture.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const s = document.getElementById('splash');
    if (s) s.remove();
  },
});

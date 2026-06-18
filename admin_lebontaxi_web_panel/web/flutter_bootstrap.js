{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Supprimer l'indicateur de chargement HTML une fois le moteur initialisé
    const loader = document.getElementById('loading-indicator');
    if (loader) {
      loader.remove();
    }

    await appRunner.runApp();
  }
});

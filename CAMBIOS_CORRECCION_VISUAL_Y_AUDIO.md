# Correcciones del 15 de noviembre
- La key normal ahora abre PantherAssignedPatchesView en lugar de ContentView, que ocultaba el botón Telegram y el menú esperado.
- Se añadió botón Telegram visible arriba a la derecha, logo Panther iOS, tarjetas neón y cierre de sesión visible.
- La sesión de audio se configura en modo playback para que los audios puedan sonar aun con el interruptor de silencio activo.
- Las voces de activación/desactivación siguen reproduciéndose después de que la operación termine correctamente; si la aplicación del patch falla no se reproduce la voz de éxito.
- La voz welcome_baby se reproduce al pulsar Cerrar sesión.
- Los cuatro paquetes offline y la API de keys se conservan.
- El diseño es una aproximación SwiftUI a las referencias; no es pixel-perfect.
- Sin Xcode en este entorno: compilación y reproducción en iPhone pendientes de verificar.

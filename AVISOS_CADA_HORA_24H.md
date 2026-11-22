# Avisos de vencimiento cada hora

- Se eliminó el recordatorio único y se programan hasta 24 notificaciones locales, una cada hora durante las últimas 24 horas de cada key.
- Si el servidor devuelve una fecha de vencimiento nueva con más de 24 horas, se cancelan los avisos anteriores y se programan para el nuevo período.
- La fecha de vencimiento se actualiza al activar y revalidar la key; si el servidor la renueva pero la app no vuelve a comunicarse con él, las notificaciones locales previamente programadas **no se pueden cancelar a distancia**. Para garantizar cancelación inmediata incluso con la app cerrada, se necesita implementar push APNs desde el servidor y lógica de sincronización apropiada.
- Si la key es permanente, no hay avisos. Si se cierra sesión, se cancelan los pendientes.
- Los avisos requieren permiso de notificaciones. iOS puede limitar su entrega por Concentración, resumen de notificaciones o configuración del usuario.
- La imagen de pantera se adjunta al aviso; iOS controla su presentación, no puede imponerse como fondo de banner.
- No se ha ejecutado una compilación Xcode ni una prueba en dispositivo.

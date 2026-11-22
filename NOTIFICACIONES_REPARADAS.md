# Cambios de notificaciones
- Al introducir el código correcto en la calculadora aparece una pantalla Panther con imagen y explicación. Después de Continuar, iOS muestra el diálogo oficial si no se solicitó antes.
- Las notificaciones pueden presentarse como banner con la app abierta gracias a UNUserNotificationCenterDelegate.
- La actualización de avisos ya no elimina la bienvenida.
- Se evita reprogramar cada 30 segundos si el vencimiento no cambió.
- La renovación con una fecha nueva cancela y reprograma los avisos pendientes cuando la app consulta el servidor.
- iOS puede limitar entregas según permisos, Focus, resumen programado y ajustes del usuario.
- Para cancelación inmediata mientras la app está cerrada hace falta backend/APNs.
- No se ha compilado con Xcode aquí; ejecutar GitHub Actions para verificar.

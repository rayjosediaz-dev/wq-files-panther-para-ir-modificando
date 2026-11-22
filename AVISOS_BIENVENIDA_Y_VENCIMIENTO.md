# Avisos de Panther iOS

- Al activar correctamente una key: notificación local «¡Gracias por preferir Panther iOS!».
- En las últimas 24 horas: avisos horarios existentes.
- Al vencer: «Tu key [key] ha vencido. Compra otra key o renuévala con @Panther ios en Telegram.».
- Renovación/revalidación: cancela y reprograma los avisos según la fecha nueva cuando la app recibe la nueva fecha.
- Key permanente: sin avisos de vencimiento.
- Al cerrar sesión manualmente: se cancelan los avisos.
- Se adjunta la imagen `PantherLaunch` a las notificaciones cuando iOS lo permite. iOS controla la apariencia y no permite imponer un fondo personalizado en el banner.

**Limitación:** Si la key se renueva en el servidor con la app cerrada, los avisos locales no pueden cancelarse hasta que la app revalide la nueva fecha. Para cancelación inmediata es necesario APNs y un servidor que envíe y administre notificaciones push. Las notificaciones requieren autorización del usuario. El contenido de la key en pantalla bloqueada puede exponerla a quien vea el teléfono. No se ha probado compilación Xcode en este entorno.

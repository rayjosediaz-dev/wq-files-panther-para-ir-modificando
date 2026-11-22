# Notificaciones Panther iOS — estado de implementación

- Pantalla previa al permiso solo la primera vez que se introduce el código de calculadora (UserDefaults).
- Si se elige «Ahora no», se permite continuar sin bloquear el uso de la app. iOS no permite mostrar de nuevo su diálogo si ya se rechazó; el usuario puede habilitarlo en Ajustes.
- Mensaje de bienvenida solo una vez por key nueva en la instalación, usando huella SHA-256 de la key. No se vuelve a emitir al restaurar sesión.
- Se mantienen los recordatorios locales de 24 horas y vencimiento.
- **No se han implementado notificaciones push APNs**. Para recibir cambios inmediatos de duración desde Admin con la app cerrada, hace falta implementar registro de token APNs en Panther iOS, almacenamiento de tokens en servidor, proveedor APNs configurado con credenciales de Apple y emisión desde el backend cuando cambie una key. Una IPA por sí sola no puede garantizar esto.
- Sin Xcode disponible: compilación no verificada.

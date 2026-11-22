# Actualización automática de duración de key

- Mientras el usuario esté conectado, la app consulta `POST /api/activate` a Lovable cada 30 segundos.
- Si el administrador amplía la fecha `expires_at`, el contador se actualiza sin reiniciar la app.
- Si el servidor indica que venció, se revocó o no autoriza la key, vuelve a la pantalla de acceso.
- El contador visual sigue descontándose cada segundo y detecta vencimiento local sin esperar la siguiente consulta.
- Al volver a primer plano se consulta el servidor de nuevo.
- No se cambiaron los archivos de patches ni el diseño.

Nota: para ver el tiempo aumentado, el teléfono debe tener conexión y el servidor devolver la nueva fecha de vencimiento.

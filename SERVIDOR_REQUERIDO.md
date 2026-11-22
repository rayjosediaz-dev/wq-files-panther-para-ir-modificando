# Contrato requerido para Panther Keygarden

La app conserva `POST /api/activate` y `POST /api/patches`, con JSON `{ "key": "...", "device_id": "..." }`.

La descarga nueva utiliza `POST /api/patches/{id}/download` con el mismo JSON. El servidor debe validar la key y el dispositivo, comprobar que el patch está publicado y devolver los bytes `.3105` (Content-Type: application/octet-stream). **No devuelva JSON ni una redirección** para este endpoint.

`POST /api/patches` debe responder `{ "ok": true, "patches": [{"id":"...","name":"...","version":"1.0","category":"..."}] }` y excluir patches despublicados. La app consulta cada 30 segundos mientras el menú está abierto.

Configure `PantherAPIBaseURL` en `ThreeOneOSFive/Info.plist` con la URL HTTPS real antes de compilar. El proyecto original usa una URL de Lovable que no se ha verificado.

Los `.3105` originales ya no forman parte de la app. Conserve copias de seguridad y súbalos desde el panel del servidor. Los patches que el usuario ya había importado anteriormente en el almacenamiento local de su dispositivo no se borran automáticamente.

No se pudo compilar aquí: Xcode requiere macOS. Tampoco se pudo probar contra el servidor, que aún no está disponible. No se modificaron los componentes de explotación ni el motor de aplicación de patches.

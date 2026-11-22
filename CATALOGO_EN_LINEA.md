# Catálogo en línea para usuarios con keys normales

La aplicación llama a `POST /api/patches` con la key y device_id tras el inicio de sesión y al pulsar «Actualizar». Los archivos publicados se muestran en la pantalla Patches y pueden abrirse con el visor de paquetes 3105.

## Requisito del servidor Lovable

El servidor actual puede filtrar los patches por key. Para el nuevo comportamiento, debe validar la key y el dispositivo, y luego devolver **el mismo catálogo publicado para usuarios normales**, independientemente de la key concreta. No debe devolver las herramientas o paquetes privados del administrador.

Ejemplo de respuesta:

```json
{"ok":true,"role":"user","patches":[{"id":"id-unico","name":"Cuello.3105","description":"Paquete publicado","version":"1.0","category":"neck","download_url":"https://servidor/descarga-autorizada"}]}
```

Las descargas deben requerir autorización o usar URLs firmadas de corta duración. Solo los administradores deben poder publicar archivos, mediante una interfaz y un endpoint de subida separados que **no existen en el contrato actual proporcionado**. La aplicación no crea ese endpoint ni sube archivos por sí misma.

No se ha compilado ni probado en iPhone. El visor prepara workspaces privados de Panther iOS; no modifica aplicaciones de terceros.

# Panther iOS — catálogo remoto

- Se eliminaron cuatro paquetes cifrados offline del proyecto y del target Xcode.
- Se deshabilitó su instalación automática.
- El menú neón lista únicamente los patches devueltos por la API para la key activa; no hay cuatro filas precargadas.
- Al pulsar Encender, la app descarga el .3105 autorizado, lo importa y aplica mediante el servicio existente. Al pulsar Apagar, restaura el recibo existente.
- URL de API: https://panther-servidor.onrender.com
- ATENCIÓN: el cliente original usa /api/activate, /api/patches y /api/patches/{id}/download con respuestas específicas (ok, role, menus, etc.). Es indispensable comprobar que el backend desplegado implemente exactamente esos endpoints y estructuras. No se ha comprobado esa compatibilidad.
- La aplicación no elimina automáticamente cambios ya aplicados al despublicar un patch en el servidor.
- Patches antiguos importados en instalaciones previas pueden permanecer en el almacenamiento local, aunque ya no aparecen en el menú remoto.
- La aplicación requiere acceso autorizado a los archivos de destino y el servicio de aplicación puede fallar por restricciones de iOS.
- El proyecto no ha sido compilado con Xcode en este entorno.

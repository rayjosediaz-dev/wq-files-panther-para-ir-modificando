# Conectar Panther iOS — pasos finales

El servidor API y la app ya incluyen rutas compatibles:
- POST /v1/activate {key,device_id}
- POST /v1/patches {key,device_id}
- POST /admin/login {key}
- GET /admin/state
- POST /admin/generate-keys {count}
- POST /admin/reset-key {key}
- POST /admin/patches {patches}

## Publicar (requiere tu autorización y tu cuenta Cloudflare)
1. Instala Node.js y ejecuta `npm install -g wrangler`.
2. Entra a `cloudflare` y ejecuta `wrangler login`.
3. Ejecuta `wrangler d1 create panther-ios-test`.
4. Copia el `database_id` devuelto a `cloudflare/wrangler.toml`.
5. Ejecuta `wrangler d1 execute panther-ios-test --remote --file=schema.sql`.
6. Ejecuta `wrangler secret put ADMIN_KEY`. Introduce una clave fuerte privada para el panel. Si insistes en `Naruto00`, recuerda que es insegura para internet.
7. Ejecuta `wrangler deploy`.
8. Copia la dirección HTTPS que aparece en pantalla.
9. Abre `ThreeOneOSFive/Info.plist` y cambia `PantherAPIBaseURL` por esa dirección, sin barra final.
10. Compila la app en Xcode y comprueba las claves desde un iPhone.

El panel web está en la raíz de tu Worker.
No publiques keys, credenciales o archivos de estado en GitHub público.
Esta es una implementación de PRUEBA: no se garantiza seguridad de producción, disponibilidad continua ni compilación IPA hasta probarla.
Cloudflare impone cuotas gratuitas. Las keys se guardan en D1; no hay límite fijo de 3,000 en la lógica.
El identificador iOS identifierForVendor puede cambiar al reinstalar todas las apps del mismo proveedor; no es un ID permanente del teléfono.
Los patches son entradas de catálogo y no archivos ejecutables instalados a distancia.

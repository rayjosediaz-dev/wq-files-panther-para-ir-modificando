# Panther iOS — Cloudflare Workers + D1 (prueba)

1. Crea una cuenta en https://dash.cloudflare.com/ y configura Wrangler en tu equipo con `npm install -g wrangler` y `wrangler login`.
2. En la carpeta `cloudflare`, ejecuta `wrangler d1 create panther-ios-test`.
3. Copia el `database_id` devuelto a `wrangler.toml` en lugar de `REEMPLAZAR_ID_D1`.
4. Ejecuta `wrangler d1 execute panther-ios-test --remote --file=schema.sql`.
5. Ejecuta `wrangler secret put ADMIN_KEY` e introduce una contraseña nueva y fuerte (no publiques Naruto00 en internet).
6. Ejecuta `wrangler deploy`. Copia la dirección HTTPS `https://...workers.dev`.
7. Sustituye `https://TU-SERVIDOR-PANTHER.example.com` en `ThreeOneOSFive/App.swift` por la URL HTTPS de tu Worker; después compila la app iOS.

El panel web está en la raíz de la URL del Worker. Las keys se generan desde el panel; no se incluyen claves de prueba prepublicadas.
Las operaciones de generar 10,000 claves pueden superar los límites de CPU/consultas del plan gratuito: usa lotes pequeños (100 o menos).
Esta implementación es de prueba, no está desplegada ni verificada en un iPhone. Para producción, añade control de acceso más robusto, límites de intentos, auditoría y transacciones para actualización del catálogo.
D1 y Workers gratuitos tienen cuotas. La identificación por identifierForVendor no es un identificador físico permanente.

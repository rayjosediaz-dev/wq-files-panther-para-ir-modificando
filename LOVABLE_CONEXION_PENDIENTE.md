# Panther iOS — configuración Lovable (pendiente de verificar)

Se configuró `PantherAPIBaseURL` en `ThreeOneOSFive/Info.plist` a:
`https://panther-keygarden.lovable.app`

**IMPORTANTE:** Esta URL NO confirma que exista una API pública funcional. La ruta `/api` devuelve HTTP 404. El código iOS todavía solicita `POST /v1/activate` y `POST /v1/patches`, rutas del servidor Cloudflare anterior, y espera respuestas JSON `{ "role": "patches" | "admin" }` y `{ "patches": [...] }`. No se ha verificado que Lovable ofrezca estas rutas, por lo que las keys aún NO están conectadas funcionalmente.

Para completar la integración, comparte la documentación de endpoints que aparece en la pestaña API de Lovable: URL de activación, validación y patches, métodos HTTP, formato de solicitud y respuesta, y esquema de autenticación (sin compartir secretos). Después hay que adaptar `ThreeOneOSFive/App.swift` a esos contratos y probar la compilación en Xcode y las solicitudes reales.

La carpeta `cloudflare/` se conserva como referencia de la versión anterior; NO se usa automáticamente con Lovable.
No subas claves privadas ni credenciales a GitHub.

# Panther iOS — configuración

- Un solo proyecto Xcode: `ThreeOneOSFive.xcodeproj`.
- El login de Panther está en `ThreeOneOSFive/App.swift`. La app exige una respuesta del servidor `/v1/activate` con `{ "role": "patches" }` o `{ "role": "admin" }`.
- La URL de API por defecto está en `PantherSession.apiBase` y apunta a Lovable. Cambia esa URL si migras a Lovable.
- Para usuarios con rol `patches`, la app presenta únicamente una lista de configuraciones asignadas. No ejecuta código remoto ni importa automáticamente archivos.
- El servidor debe implementar `POST /v1/patches` y devolver `{ "patches": [{ "id": "tema-verde", "name": "Tema verde", "enabled": true, "description": "..." }] }` solo después de validar la key y su dispositivo. Este endpoint **no está implementado en este ZIP**.
- La vinculación a un dispositivo y los permisos deben verificarse en el servidor. `identifierForVendor` puede cambiar si se desinstalan todas las apps del mismo proveedor.
- La key de administrador **no** se incluye en el código. El servidor debe verificarla.
- No se ha comprobado una compilación en Xcode (este entorno no tiene macOS/Xcode). Revisa el resultado de Actions y los registros de errores.
- El proyecto original establece iOS 16.0 como versión mínima. Para soportar iOS 15, hace falta adaptar las vistas que requieren iOS 16 y probarlas; no se ha declarado compatibilidad falsa.
- El proyecto original incluye código de acceso avanzado al sistema. No se ha modificado ese código ni se garantiza que funcione en versiones nuevas de iOS.
- No guardes tokens, claves de administrador ni certificados privados en GitHub.

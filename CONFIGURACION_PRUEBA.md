# Panther iOS independiente — modo prueba

- Se retiró la URL de Lovable del cliente iOS y se sustituyó por `https://TU-SERVIDOR-PANTHER.example.com`. Reemplázala con la URL HTTPS real del servidor antes de compilar.
- `panther-server/claves_prueba.csv`: 3000 claves de prueba, cada una válida 30 días desde la primera activación.
- `panther-server/keys.json`: base de claves; el servidor guarda fecha y dispositivo en este archivo.
- `panther-server/server.py`: API independiente, sin dependencias externas. Ejecutar con `python3 server.py`. Necesita hosting persistente, HTTPS y backups.
- Administrador de prueba: `Naruto00`, permanente mientras el servidor conserve esa configuración. Para producción configurar `PANTHER_ADMIN_KEY` con un secreto fuerte.
- Una clave se vincula al identificador `identifierForVendor` del dispositivo; no garantiza vinculación permanente a un teléfono físico después de ciertas reinstalaciones.
- Los parches se publican editando `panther-server/patches.json`; la app los consulta al sincronizar, no los ejecuta remotamente.
- El proyecto Xcode original y sus funciones se conservaron. No se ha compilado ni probado en iOS.
- No publiques `keys.json`, `claves_prueba.csv` ni secretos en repositorios públicos de GitHub.
- Este ZIP es para pruebas: el backend no tiene panel administrativo, control de abuso ni infraestructura de producción.

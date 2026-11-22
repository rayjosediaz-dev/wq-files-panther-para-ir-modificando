Corrección de activación Panther iOS

- Se cambió POST /api/activate por POST /v1/activate en inicio de sesión y revalidación.
- Confirmado por los registros de Render: /api/activate devuelve 404.
- Los endpoints del catálogo y descarga requieren revisión adicional de método, autenticación y respuesta antes de considerarlos funcionales.
- El esquema de respuesta de /v1/activate también debe comprobarse frente al modelo PantherActivationResponse.
- No se ha compilado con Xcode ni probado en iPhone.

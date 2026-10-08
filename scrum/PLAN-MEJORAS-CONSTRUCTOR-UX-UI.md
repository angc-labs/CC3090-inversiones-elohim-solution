# Plan de mejoras UX/UI del constructor

Fecha: 22 de septiembre de 2026. Alcance: constructor, tienda renderizada y contratos que conectan ambos. Resultado: backlog de implementación; no se modificó código funcional.

## Alcance y grado de certeza

Revisión estática del código local de frontend y backend. No se inició una sesión de usuario, no se ejecutaron peticiones contra producción y no se midió rendimiento ni se validó visualmente en navegador. Los problemas de lógica y contratos se apoyan en el código; los objetivos visuales y de rendimiento son propuestas que deberán comprobarse. No se puede garantizar ausencia de regresiones hasta ejecutar la matriz de aceptación.

Se conservaron los cambios locales preexistentes. Este documento se guarda en `scrum` del repositorio principal; frontend, backend y docs son submódulos.

Prioridades: **P0** = seguridad o integridad de datos; **P1** = flujo principal del constructor; **P2** = calidad y eficiencia tras estabilizarlo. Los límites y tiempos propuestos son criterios de producto iniciales, no límites actuales del sistema.

## Evidencia y archivos de implementación

Las referencias E1–E12 se utilizan en las tareas. Las líneas corresponden a la copia revisada y pueden cambiar.

| Ref. | Archivo / símbolo | Hallazgo |
|---|---|---|
| E1 | [Página del constructor](../frontend/src/app/portal/store-builder/page.tsx), `handlePublishConfig` (729), efecto de `activeStore` (151), carga de tiendas (104) | Guarda y publica en una única operación. La respuesta modifica `activeStore` y vuelve a cargar la configuración; puede reemplazar cambios hechos durante la petición. No hay historial ni indicador de cambios pendientes. |
| E2 | [Panel izquierdo](../frontend/src/components/features/portal/constructor/ConstructorLeftPanel.tsx), `importConfig` (120) | Importa JSON comprobando principalmente que exista `pages` o `sections`; no normaliza exhaustivamente antes de usarlo. Ya existen importación, exportación, temas y creación de páginas: mejorarlos, no duplicarlos. |
| E3 | [Panel derecho](../frontend/src/components/features/portal/constructor/ConstructorRightPanel.tsx) | Propiedades por tipo de sección; varios labels de 9 px sin asociación explícita con input. Subidas repetidas en distintos campos. |
| E4 | [Vista del constructor](../frontend/src/components/features/portal/constructor/ConstructorPreview.tsx), `simulatedMocks` (286), selector de tamaños (105) | Catálogo ficticio de tres productos. Renderizador separado del público. Ancho simulado con clases; no representa un viewport independiente. Dominio ilustrativo fijo `.dmhub.com`. |
| E5 | [Tienda pública](../frontend/src/app/preview/[id]/page.tsx), carga (336), `active_tenant_id` (460), render de secciones (642) | Otro renderizador, productos reales, carrito y pagos. Escribe la tienda visitada en una clave global del origen. |
| E6 | [Cliente HTTP](../frontend/src/lib/api/client.ts), `buildAuthHeaders` (111); [API administrativa](../frontend/src/lib/api/admin.ts), `getTiendas` (106), `getIntegraciones` (530), `actualizarConfiguracionVisual` (553) | Tenant implícito por subdominio o localStorage; JSON de escritura como objeto, lectura de configuración como string. |
| E7 | [TiendasController](../backend/src/ElohimShop.API/Controllers/TiendasController.cs); [MediaController](../backend/src/ElohimShop.API/Controllers/MediaController.cs); [V1ControllerBase](../backend/src/ElohimShop.API/Controllers/V1ControllerBase.cs) | No aparecen atributos de autorización en estos controladores/base. Verificar tenant no equivale a comprobar permiso de edición. |
| E8 | [PlatformService](../backend/src/ElohimShop.Infrastructure/Platform/PlatformService.cs), `ActualizarConfiguracionVisualAsync` (184), `ObtenerIntegracionesAsync` (1440), `EliminarMediaAsync` (252) | Guarda JSON crudo sin validación de estructura; devuelve secretos de Stripe, Cloudinary y SMTP al solicitar integraciones. Eliminar media es un stub que devuelve éxito si el ID no está vacío. |
| E9 | [Program.cs](../backend/src/ElohimShop.API/Program.cs) (233); [TenantResolverMiddleware](../backend/src/ElohimShop.API/Middleware/TenantResolverMiddleware.cs); [BetterAuthSessionMiddleware](../backend/src/ElohimShop.Infrastructure/Auth/BetterAuthSessionMiddleware.cs) | Orden: autenticación → tenant → sesión Better Auth → autorización. La validación posterior de sesión considera `X-Tenant-ID`; revisar también slug/host y usuario sin sesión. No se encontró política fallback en Program. |
| E10 | [Cloudinary](../frontend/src/lib/cloudinary.ts); [DTOs](../backend/src/ElohimShop.Application/Platform/PlatformDtos.cs) | Firma en backend y subida directa desde navegador; el secreto no es necesario para esa subida. |
| E11 | [SettingsTab](../frontend/src/components/features/portal/SettingsTab.tsx), `getIntegraciones` (110) | Configuración también depende del DTO con secretos; cambiar su contrato exige migrar este consumidor junto al constructor. |
| E12 | [Next config](../frontend/next.config.ts); [middleware frontend](../frontend/src/middleware.ts) | `/portal/constructor` reescribe a `/portal/store-builder`; `/api/*` se reenvía al backend configurado; subdominios se reescriben a `/preview/{slug}`. |

## Endpoints existentes y dependencias

### Uso directo del constructor

En navegador las peticiones internas usan `/api/...` en el mismo origen. `buildAuthHeaders` añade `Authorization: Bearer <token>` cuando se suministra token y selecciona `X-Tenant-Slug` por subdominio o `X-Tenant-ID` desde localStorage. Esto describe al cliente actual, no una garantía de autorización del servidor.

| ID | Método y ruta | Cuándo / consumidor | Contrato actual y precaución |
|---|---|---|---|
| C1 | `GET /api/v1/tiendas` | Al abrir constructor, `getTiendas` | Array de `TiendaDto`; incluye configuración visual. Sin email reconocido el servicio devuelve array vacío. No existe un GET de configuración separado usado por el constructor. |
| C2 | `GET /api/v1/tiendas/integraciones` | Al establecer tienda activa, `getIntegraciones` | Exige tenant en controlador. DTO con `cloudinaryCloudName`, `cloudinaryApiKey`, **`cloudinaryApiSecret`, `stripeSecretKey`, `smtpPassword`**, entre otros. Constructor comprueba presencia de secreto para habilitar subida. Prioridad P0. |
| C3 | `PUT /api/v1/tiendas/configuracion-visual` | Botón «Guardar y Publicar» | Body `{ "configuracionVisual": { ... } }`. Respuesta 200 `TiendaDto`; `configuracionVisual` es JSON serializado como string. Sustituye la configuración visible públicamente. Falta tenant → 400 en controlador. |
| C4 | `GET /api/v1/media/cloudinary-signature?publicId=...&timestamp=...` | Antes de subir logo, fondo o bloque imagen | Parámetro opcional adicional `folder`, actualmente no enviado por el helper. Respuesta `{signature,timestamp,apiKey,cloudName}`; no modificar algoritmo ni parámetros firmados unilateralmente. |
| C5 | `POST https://api.cloudinary.com/v1_1/{cloudName}/image/upload` | `uploadToCloudinary` | Multipart: `file`, `api_key`, `timestamp`, `public_id`, `signature`, `signature_algorithm=sha256`. Se consume `secure_url`. No es una ruta del backend local. |

El constructor no carga productos reales ni llama a carrito/pagos desde su simulador actual. «Ver Tienda (Live)» abre la tienda publicada; no transmite la configuración aún sin guardar.

### Dependencias indirectas que deben seguir funcionando

| Método y ruta | Uso |
|---|---|
| `GET /api/v1/tiendas/{idOrSlug}` | Obtiene tienda y diseño publicado en `/preview/{id}` y subdominio. Conservar lectura pública; nunca incluir borradores privados. |
| `GET /api/v1/productos` | Catálogo de la tienda; candidato a reutilizar en simulación con contexto explícito. Actualmente devuelve array, no envoltorio paginado. |
| `GET /api/v1/sucursales` | Sucursales cargadas por la tienda. |
| `GET /api/v1/carrito` | Carga de carrito. |
| `POST /api/v1/carrito/articulos` | Agregar producto. |
| `PUT /api/v1/carrito/articulos/{id}` | Actualizar cantidad. |
| `DELETE /api/v1/carrito/articulos/{id}` | Retirar producto. |
| `GET /api/v1/metodos-pago/config-stripe` | Clave pública de Stripe para la sesión. |
| `GET`, `POST /api/v1/metodos-pago`; `DELETE /api/v1/metodos-pago/{id}` | Tarjetas guardadas y su gestión. |
| `POST /api/v1/metodos-pago/contra-entrega` | Flujo de pago contra entrega. |
| `POST /api/v1/pagos/create-intent`; `GET /api/v1/pagos/{paymentIntentId}/status` | Inicio y consulta de pago. |
| `POST /api/v1/reservaciones` | Registro de reservación. |

Estos wrappers están en `frontend/src/lib/api/{admin,carrito,pago,reservacion}.ts` y los controladores homónimos de `backend/src/ElohimShop.API/Controllers`. `POST /api/v1/pagos/webhook` es una dependencia servidor-a-servidor de pagos, no una llamada del constructor.

Rutas relacionadas que **no se usan directamente** al editar: `POST /api/v1/tiendas/integraciones` (Settings), `POST /api/v1/tiendas` (crear tienda), `PUT /api/v1/tiendas/actualizar` (metadatos), `GET /api/v1/tiendas/valida-slug/{slug}` y `DELETE /api/v1/media?publicId=...`. Esta última existe pero su servicio no elimina el archivo real.

### Contrato de configuración a preservar

La lectura actual admite configuraciones históricas con `sections` y configuraciones con `pages`, `currentPageId` y `theme`. Las páginas contienen `id`, `name`, `isHome`, `sections`; las secciones contienen `id`, `type`, `name`, `properties`. Los tipos gestionados incluyen `announcement`, `header`, `hero`, `products`, `richtext`, `custom`, `cart`, `footer`.

Reglas de migración: mantener IDs y propiedades desconocidas durante carga/guardado; no convertir silenciosamente un JSON inválido en una plantilla y sobrescribirlo; no convertir automáticamente `currentPageId` (estado histórico) en la página que debe abrirse públicamente. Definir inicio con `isHome` y separar la selección temporal del editor. Mantener adaptador para `sections` mientras existan lectores antiguos.

## Tareas de frontend

### FE-01 · P0 · Fijar el contexto de tienda por petición

- **Problema:** otra pestaña del mismo origen puede cambiar `active_tenant_id` y dirigir el guardado a una tienda distinta de la visible (E1, E5, E6).
- **Implementación:** extender helpers con contexto explícito `{tenantId}`; enviarlo desde `activeStore.id` para integraciones, firma y guardado. No enviar ID y slug contradictorios. Usar el ID resuelto de la ruta pública para catálogo/carrito. Mantener fallback de los helpers para consumidores todavía no migrados. Claves de caché y borrador deben incluir usuario y tienda.
- **Aceptación:** abrir editor A y preview B en pestañas del mismo origen, cambiar localStorage y guardar A; la petición lleva A y solo A cambia. Una respuesta tardía de B nunca actualiza el estado de A.
- **API / dependencias:** C1–C4, sin renombrar rutas; coordinar BE-01. Probar que navegación pública no queda vinculada al tenant administrativo.

### FE-02 · P1 · Tipar y normalizar el documento visual

- **Implementación:** extraer `VisualConfig`, `Page`, unión de tipos de sección y `normalizeVisualConfig` a módulo compartido por editor y storefront. Centralizar defaults y acciones en un reducer o store específico. Validar importación antes de reemplazar estado; mostrar errores con ruta, por ejemplo `pages[1].sections[2].properties.columns`.
- **Aceptación:** cargar fixtures históricos `sections`, multipágina y tema ausente sin perder datos; rechazar IDs duplicados, páginas mal formadas y tipos incompatibles sin borrar el diseño actual. Importar/exportar vuelve al mismo documento normalizado.
- **API / dependencias:** mantener body objeto y respuesta string de C3; coordinar esquema BE-03. E1–E5.

### FE-03 · P1 · Evitar pérdida de trabajo y añadir historial

- **Implementación:** guardar snapshot confirmado, estado `dirty`, pila de deshacer/rehacer de 50 acciones y aviso al salir/cambiar tienda con cambios. Agrupar escritura consecutiva en una acción. Recuperación local por usuario/tienda después de 1 s de inactividad; capturar errores de almacenamiento. No guardar tokens ni secretos. Retención propuesta de recuperación: 7 días; limpiar al cerrar sesión.
- **Aceptación:** editar → recargar → ofrecer recuperar o descartar; eliminar página/sección → deshacer restaura contenido, menú y orden; deshacer/rehacer nunca escribe en API. Si se edita durante un guardado, la respuesta solo confirma el snapshot enviado y conserva los cambios posteriores como pendientes.
- **API / dependencias:** ninguna ruta nueva para historial local. FE-01 y FE-02. No llamar C3 desde autoguardado: hoy publica.

### FE-04 · P1 · Separar borrador, vista previa y publicación

- **Implementación:** barra con tienda activa, página, estado de guardado y acciones diferenciadas: «Guardar borrador», «Vista previa» y «Publicar». Renombrar enlace actual a «Ver tienda publicada» y construir dominio desde configuración compartida. Previsualizar datos locales sin guardarlos públicamente. Antes de publicar, mostrar páginas modificadas y errores bloqueantes; conservar la edición si falla.
- **Aceptación:** guardar borrador no modifica la tienda pública; publicar una vez activa exactamente la revisión seleccionada; error de red conserva el borrador; conflicto ofrece recargar o conservar/exportar la copia local, sin sobrescritura automática. Mensajes persistentes además de toast.
- **API / dependencias:** depende de BE-04/BE-05 y FE-03 para habilitar guardado remoto. Mientras no estén disponibles, mantener publicación manual C3 y mostrar recuperación local con ese nombre.

### FE-05 · P1 · Compartir renderizador y probar tamaños reales

- **Implementación:** extraer secciones visuales reutilizables de E4/E5; inyectar datos y callbacks según modo `editor`/`storefront`. Capa de selección solo en editor. Aislar viewport, por ejemplo mediante iframe local con documento controlado, para que media queries respondan a 390, 768 y 1440 px; escalar vista si el espacio disponible es menor.
- **Aceptación:** misma configuración, productos y ancho generan el mismo contenido y estilos en preview/publicado para todos los tipos de sección. En modo editor ningún clic dispara reservas, pagos o escrituras de carrito; en tienda pública esos callbacks continúan funcionando. Comparación visual reproducible en los tres tamaños.
- **API / dependencias:** no cambiar rutas de compra. FE-02; aislar cuidadosamente lógica de sesión/pagos durante extracción.

### FE-06 · P1 · Mostrar productos reales y vacíos útiles

- **Implementación:** selector «Productos reales / Ejemplos»; usar ejemplos solo con etiqueta visible. Cargar catálogo con tenant explícito y caché por tienda usando SWR ya instalado. Separar estados cargando/error/sin productos/sin resultados; ofrecer acceso a gestión de productos. No crear productos de ejemplo en backend.
- **Aceptación:** editar tienda A nunca muestra datos cacheados de B; precio, imagen y nombre coinciden con catálogo; vacío no muestra productos ficticios como si fueran reales; escribir texto del hero no vuelve a pedir catálogo.
- **API / dependencias:** reutiliza `GET /api/v1/productos`, que el simulador actual no llama. FE-01/FE-05. No cambiar el array de respuesta.

### FE-07 · P1 · Ordenar navegación y propiedades para editar más rápido

- **Implementación:** conservar tres zonas: árbol de páginas/secciones, lienzo, inspector. Inspector con grupos «Contenido», «Diseño» y «Avanzado»; controles básicos primero. Al seleccionar en lienzo, abrir inspector en pantallas pequeñas y enfocar título de sección. Añadir subir/bajar, duplicar con ID nuevo y eliminación reversible. Indicar «Compartida entre páginas» en header/footer y anuncios compartidos; definir qué anuncios son globales en el modelo.
- **Aceptación:** ordenar una sección funciona con ratón, tacto y teclado; header/footer respetan restricciones por tipo, no solo por ID literal. Duplicar no produce IDs repetidos; editar una sección local no cambia otra página; la selección siempre apunta a una sección existente tras importar/eliminar/cambiar de página.
- **API / dependencias:** sin nuevas rutas. FE-02/FE-03. Si se añade ocultación, solo habilitar el control cuando ambos renderizadores respeten la misma propiedad.

### FE-08 · P1 · Legibilidad, accesibilidad y estados del constructor

- **Implementación:** labels/ayuda a 12–14 px y campos a 14–16 px como base propuesta; asociar `label/htmlFor`, nombres accesibles a iconos, foco visible y estados que no dependan solo del color. Drawers/modales con Escape, foco contenido y retorno al disparador. Distinguir carga, falta de permisos, error con reintento y ausencia de tiendas. Reemplazar temporizador de hidratación por estado real del store de autenticación.
- **Aceptación:** recorrido completo de edición con teclado; sin scroll horizontal del shell a 390 px; acciones esenciales accesibles a zoom 200%; «sin tiendas» solo tras carga exitosa vacía y CTA real al portal. Contraste WCAG AA verificado y objetivos de interacción de 44 px cuando sea posible, mínimo AA de 24 px o sus excepciones.
- **API / dependencias:** interpretar errores existentes sin cambiar endpoints. E1–E4. W3C exige alternativa al arrastre y especifica mínimos de tamaño: [WCAG 2.2](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/).

### FE-09 · P2 · Unificar subida de imágenes

- **Implementación:** un componente para logo, hero e imagen de bloque: miniatura, validación, estado «Subiendo», reintentar y reemplazar. Propuesta inicial: JPG/PNG/WebP hasta 5 MiB; reflejar política real de BE-06. Capturar tienda, página, sección y campo al iniciar; resolver subida al destino original, no a la selección más reciente. Si se elimina destino, no aplicarla a otra sección.
- **Aceptación:** doble clic no duplica subida; error conserva imagen anterior; cambiar sección mientras sube no coloca imagen en el destino equivocado; uso de teclado y mensaje si integración no está configurada. Añadir texto alternativo cuando corresponda en ambos renderizadores.
- **API / dependencias:** C4/C5; FE-01, BE-02 y BE-06. No exponer secreto para habilitar botón.

### FE-10 · P2 · Medir y reducir trabajo de renderizado

- **Implementación:** fixture de 10 páginas × 20 secciones; registrar React Profiler antes/después al escribir y mover secciones. Separar estado de selección/documento, suscripciones por sección y memorizar componentes según medición. Redimensionar imágenes para el tamaño mostrado y cargar diferidamente las fuera de vista.
- **Aceptación:** sin peticiones por cada pulsación ni remount del lienzo al seleccionar. Meta inicial: p95 inferior a 100 ms entre edición y actualización visible en equipo/navegador de referencia documentado; si no se alcanza, adjuntar medición y cuello de botella. Mantener dimensiones de imágenes para evitar saltos.
- **API / dependencias:** FE-02/FE-05; no agregar librerías de animación para solucionar problemas de estado o rendimiento.

## Tareas de backend

### BE-01 · P0 · Autorizar por operación y tienda resuelta

- **Implementación:** exigir sesión válida y permiso administrativo sobre la tienda en escritura visual, integraciones y firma/eliminación de medios. Resolver identidad y tenant y, después, comprobar membresía/rol sobre el tenant efectivo; cubrir ID, slug y host, no solo una cabecera. Mantener lectura pública de tienda/catálogo por separado. Política propuesta: administrador de tienda o superadmin autorizado; cliente, cajero y logística no editan diseño salvo permiso explícito futuro.
- **Aceptación:** sin sesión → 401 en operaciones privadas; cliente/staff sin permiso/administrador de otra tienda → 403 sin lecturas secretas ni escritura. Administrador miembro de dos tiendas puede editar ambas explícitamente. Repetir matriz con Bearer/cookie e ID/slug/host, token expirado y headers contradictorios. Validar en backend directo, no únicamente detrás de Next.
- **API / compatibilidad:** conservar rutas; el cambio de permitir a rechazar accesos indebidos es intencional. No conservar ese comportamiento por compatibilidad. E7–E9. Aplicar autorización sobre el recurso, no únicamente un atributo de rol: [Microsoft](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/resource-based?view=aspnetcore-10.0).

### BE-02 · P0 · Sacar secretos de respuestas HTTP

- **Implementación:** respuesta administrativa de estado con `hasCloudinaryCredentials`, `hasStripeCredentials`, `hasSmtpCredentials` y campos públicos necesarios. Constructor consume booleanos. Migrar Settings para campos secretos de solo escritura: omitir significa conservar; borrar requiere acción explícita. No enviar valores secretos ni versiones enmascaradas como credenciales reales.
- **Aceptación:** ninguna respuesta del constructor/Settings contiene secreto Cloudinary, Stripe o contraseña SMTP. Guardar solamente nombre de nube no borra los secretos guardados. Subida firmada y pagos siguen funcionando. Revisar si hubo exposición previa y rotar credenciales afectadas según evidencias, sin volcarlas en logs.
- **API / compatibilidad:** C2 cambia de forma coordinada con E11 y constructor; desplegar adaptador/frontend compatible antes de retirar campos. No dejar un endpoint legado con secretos accesible para mantener compatibilidad. C4 conserva clave pública, nube y firma necesarias. [Cloudinary documenta la firma en servidor](https://cloudinary.com/documentation/upload_images).

### BE-03 · P1 · Validar y versionar configuración visual

- **Implementación:** esquema de documento con `schemaVersion`; normalizador de v0 (`sections` o `pages` sin versión). Validar estructura, IDs únicos por ámbito, una página de inicio, referencias de navegación, tipos/properties, colores y URLs sin esquemas ejecutables. Límites iniciales propuestos: 512 KiB, 20 páginas, 50 secciones/página y 100 bloques/sección; inventariar diseños existentes antes de aplicarlos. Preservar extensiones desconocidas seguras.
- **Aceptación:** documento válido histórico se normaliza sin pérdida; entrada inválida responde 400 con `{error, errors, traceId}` y rutas de campos; tamaño excesivo 413; no modifica configuración anterior. Misma batería de fixtures en frontend/backend. No rechazar silenciosamente tiendas que exceden nuevos límites: migración explícita.
- **API / compatibilidad:** C3 mantiene `{configuracionVisual: objeto}` y devuelve `TiendaDto` con configuración string. `error` se conserva porque `apiRequest` ya lo interpreta. FE-02 depende de acordar este esquema.

### BE-04 · P1 · Persistir borradores y revisiones publicadas

- **Implementación:** almacenamiento separado por tienda para borrador y revisiones, con autor y fecha. Operaciones transaccionales de publicar/restaurar; una restauración crea revisión nueva. Migración copia configuración actual como primera revisión publicada y borrador inicial.
- **Contrato propuesto, NO existente:** `GET/PUT /api/v1/tiendas/configuracion-visual/borrador`; `POST /api/v1/tiendas/configuracion-visual/publicar` con `{draftRevision}`; `GET /api/v1/tiendas/configuracion-visual/versiones`; `POST /api/v1/tiendas/configuracion-visual/restaurar` con `{revisionId}`. Lectura de borrador: `{configuracionVisual: objeto, revision, schemaVersion, updatedAt}`; listado de versiones solo metadatos.
- **Aceptación:** guardar borrador no cambia `GET /tiendas/{idOrSlug}`; publicar hace visible solo una revisión validada en transacción; fallo conserva publicación anterior; otro tenant no consulta ni restaura revisiones. Autor/fecha provienen del servidor.
- **API / compatibilidad:** mantener C3 como publicar directamente para clientes antiguos durante transición, creando también revisión y participando en control de concurrencia. No cambiarlo silenciosamente a «guardar borrador». BE-01/BE-03.

### BE-05 · P1 · Evitar sobrescrituras concurrentes

- **Implementación:** revisión monotónica y comparación atómica en base de datos para borradores/publicación; devolver ETag y aceptar `If-Match`. Revisión desactualizada → 412 con revisión actual, sin sobrescribir. Para clientes nuevos, precondición ausente → 428. Publicación idempotente de la misma revisión/clave para recuperarse de timeout.
- **Aceptación:** dos clientes cargan r1; A guarda r2; B intenta guardar r1 y recibe conflicto; r2 permanece. Reintentar publicación tras timeout no crea dos revisiones. C3 legado incrementa revisión e invalida ediciones abiertas.
- **API / compatibilidad:** habilitar requerimiento de precondición en rutas nuevas; C3 acepta temporalmente cliente antiguo sin ETag, con limitación documentada: no puede garantizarse concurrencia entre dos clientes legados. Retirarlo del editor nuevo y cerrar transición con política explícita. BE-04 → FE-04.

### BE-06 · P1 · Controlar ciclo de vida de medios

- **Implementación:** validar firma y tenant, generar ID/namespace desde servidor o validar pertenencia, ventana de timestamp y límites de frecuencia. Asegurar que helper envía exactamente parámetros firmados y usa timestamp devuelto. Aplicar tipos/tamaño mediante configuración de subida del proveedor y comprobación posterior, no confiar solo en validación del navegador. Registrar `publicId`, tenant, dimensiones, URL y referencias.
- **Aceptación:** no firmar ni borrar recursos de otra tienda; archivos fuera de política se rechazan; firma válida permite subir logo. Eliminar de verdad mediante proveedor y devolver éxito solo tras confirmación; no borrar imágenes usadas por publicación o revisiones retenidas. Cancelar un campo no elimina inmediatamente un recurso compartido.
- **API / compatibilidad:** C4/C5 y `DELETE /media`; coordinar cualquier nuevo parámetro firmado con frontend. Mantener helper que devuelve URL o adaptarlo sin romper consumidores existentes. BE-01/BE-02; tareas de limpieza automática posteriores a registro de referencias.

### BE-07 · P2 · Reducir consultas y registrar fallos útiles

- **Implementación:** sustituir bucle `MapTiendaAsync` por proyección/batch; hoy lista tiendas y consulta tienda/credenciales por cada elemento. Respuestas de error uniformes para integración no configurada, documento inválido y conflictos; logs con traceId, tenant, usuario, revisión y duración, sin tokens/secretos/documentos completos.
- **Aceptación:** listar 1 o 50 tiendas usa número de consultas constante, objetivo máximo 2 para la carga de datos tras autorización; DTO estable. Forzar fallo de proveedor permite correlacionar UI y servidor sin secretos. Medir latencia antes/después; no introducir caché de borradores compartida ni cachear respuestas de credenciales.
- **API / compatibilidad:** C1/C3/C4; conservar `error` y contratos de éxito. Optimización separada de paginación, que cambiaría consumidores si sustituyera arrays por objetos.

## Secuencia de entrega

1. **Base de regresión:** capturar fixtures sin secretos de diseños actuales, contratos y flujo de publicación manual. Preparar dos tiendas, dos administradores, cliente y superadmin de prueba.
2. **Integridad y acceso:** BE-01 + FE-01 y BE-02 con migración coordinada de Settings. Verificar que lectores públicos siguen accesibles.
3. **Editor estable:** acordar BE-03 + FE-02; después FE-03, FE-07 y FE-08. Ya aporta mejoras sin depender de nuevas APIs de borrador.
4. **Publicación fiable:** BE-04 + BE-05; después FE-04 bajo bandera de funcionalidad por tienda. Probar migración y volver al editor anterior sin borrar revisiones.
5. **Fidelidad:** FE-05 + FE-06; después BE-06/FE-09 y mediciones FE-10/BE-07.

Cada tarea debe entregarse con cambios, evidencia de sus criterios de aceptación y lista explícita de contratos afectados. Las migraciones son aditivas; rollback de interfaz no debe desactivar autorización ni volver a exponer secretos.

## Matriz mínima para demostrar que no se rompen endpoints

| Caso | Resultado requerido |
|---|---|
| Contrato C1 y lectura pública | Campos y tipos históricos presentes; configuración como string JSON; listado solo de tiendas permitidas. |
| Contrato C3 | Body objeto aceptado, 200 con `TiendaDto`; lectura posterior refleja publicación. No doble serialización. |
| Aislamiento A/B | Pestañas, cambio de tienda y respuestas fuera de orden nunca mezclan datos ni peticiones. |
| Autorización | Casos de BE-01 pasan con ID/slug/host y sesión Bearer/cookie, incluyendo anonimato y expiración. |
| Integraciones | DTO público/administrativo no devuelve secretos; editar Settings preserva campos secretos omitidos. |
| Configuración histórica | Fixtures de solo `sections`, multipágina y campos adicionales siguen renderizando y sobreviven round-trip. |
| Escritura durante guardado | Nueva edición permanece pendiente cuando llega confirmación de snapshot anterior. |
| Borrador vs publicado | Cambios privados no aparecen a visitante anónimo; publicación y restauración son atómicas. |
| Concurrencia | Segundo escritor desactualizado recibe 412; no sobrescribe. Reintento de publicar es idempotente. |
| Subida | Firma + POST proveedor completan y `secure_url` se conserva tras publicar; fallo no reemplaza imagen válida. Usar cuenta de pruebas. |
| Fidelidad | Capturas en 390/768/1440 px comparan preview/publicado con mismos datos y sin adornos de selección. |
| Compra | Catálogo → producto → carrito → cantidad → reservación/contra entrega/tarjeta de prueba sigue funcionando; editor no dispara estas operaciones. |
| Rutas | `/portal/constructor`, `/portal/store-builder`, `/preview/{id}` y subdominio continúan llegando a sus pantallas. |
| Accesibilidad | Editar, reordenar, guardar y cerrar modales solo con teclado; foco, etiquetas, zoom y contraste verificados. |

Automatización propuesta: pruebas de componentes con Jest/Testing Library ya instalados; contratos e integración ASP.NET con base de pruebas; pruebas de navegador para flujos A/B y comparación visual. Las pruebas actuales encontradas cubren otras áreas, pero no se encontraron suites específicas del constructor. Este plan no afirma que las pruebas propuestas ya se hayan ejecutado.

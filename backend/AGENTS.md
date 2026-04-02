# Backend

Define cómo debe trabajar un agente de código dentro de `backend/`.
Objetivo: arquitectura limpia, cambios trazables y validaciones técnicas consistentes.

---

## 1. Alcance

- Ruta objetivo: `backend/`
- Solución: `ElohimShop.slnx`
- Stack: ASP.NET Core + C# + Entity Framework Core + PostgreSQL
- Framework: `.NET 10` (`net10.0`)

---

## 2. Estructura de capas

| Proyecto | Responsabilidad |
|---|---|
| `src/ElohimShop.Domain` | Entidades y reglas de negocio puras. No depende de nadie. |
| `src/ElohimShop.Application` | Casos de uso, DTOs, contratos. Depende solo de `Domain`. |
| `src/ElohimShop.Infrastructure` | EF Core, repositorios, servicios externos. Implementa contratos de `Application`. |
| `src/ElohimShop.API` | Endpoints HTTP, DI, configuración. Referencia `Application` e `Infrastructure`. |

**Regla de dependencia — nunca violar:**
```
Domain ← Application ← Infrastructure ← API
```
Si necesitas una referencia en sentido contrario, para. Algo está mal en el diseño.

---

## 3. Contexto del negocio

Elohim Shop es una plataforma de comercio electrónico para Inversiones Elohim S.A.
Los flujos principales son:

- Registro e inicio de sesión de clientes
- Catálogo de productos sincronizado con inventario legado (.NET)
- Reservación de productos en línea para recoger en tienda
- Validación de reservaciones por cajero mediante código QR
- Reportes de ventas y stock para administradores

Tener este contexto presente al evaluar qué capa debe contener cada lógica.

---

## 4. Convenciones de C#
```csharp
// Clases, interfaces, métodos → PascalCase
public class ReservacionService { }
public interface IReservacionRepository { }
public async Task<Reservacion> ObtenerPorIdAsync(string id) { }

// Variables y parámetros → camelCase
var reservacionEncontrada = await _repo.ObtenerPorIdAsync(id);

// DTOs → sufijo Dto
public class CrearReservacionDto { }

// Interfaces → prefijo I
public interface IClienteRepository { }
```

**Reglas adicionales:**
- Habilitar y respetar nullability: `<Nullable>enable</Nullable>`
- Inyección de dependencias siempre por constructor
- Propagar `CancellationToken` en operaciones I/O
- Métodos cortos con una sola responsabilidad
- Cero lógica de dominio en controllers

---

## 5. Reglas de controllers

Los controllers solo reciben, delegan y responden. Nada más.
```csharp
// Bien
[HttpPost]
public async Task<IActionResult> Crear(
    [FromBody] CrearReservacionDto dto,
    CancellationToken ct)
{
    var resultado = await _crearReservacionUseCase.EjecutarAsync(dto, ct);
    return Ok(resultado);
}

// Mal — lógica de negocio en el controller
[HttpPost]
public async Task<IActionResult> Crear([FromBody] CrearReservacionDto dto)
{
    var reservacion = new Reservacion { ClienteId = dto.ClienteId };
    _context.Reservaciones.Add(reservacion);
    await _context.SaveChangesAsync();
    return Ok(reservacion);
}
```

- Validar entrada antes de procesar
- Retornar códigos HTTP correctos y consistentes
- Estandarizar respuestas de error para facilitar debugging del frontend
- No romper contratos de rutas o payloads sin requerimiento explícito

---

## 6. Datos y EF Core

- Definir entidades y mapeos con Fluent API en `Infrastructure/Persistence/Configurations/`
- No exponer entidades de dominio directamente como respuesta HTTP
- Controlar cambios de esquema con migraciones versionadas
- Nunca hardcodear credenciales o connection strings en código

**Comandos de migración (desde `backend/`):**
```bash
# Crear migración
dotnet ef migrations add NombreDescriptivo \
  --project src/ElohimShop.Infrastructure \
  --startup-project src/ElohimShop.API

# Aplicar migración
dotnet ef database update \
  --project src/ElohimShop.Infrastructure \
  --startup-project src/ElohimShop.API
```

Nunca editar manualmente archivos dentro de `Migrations/`.

---

## 7. Configuración y ambientes

Archivos relevantes:
- `backend/src/ElohimShop.API/appsettings.json`
- `backend/src/ElohimShop.API/appsettings.Development.json`

Reglas:
- Leer secretos desde variables de entorno, nunca desde archivos commiteados
- Mantener llaves de configuración consistentes entre ambientes
- Nunca registrar secretos en logs

**Variables de entorno esperadas:**
```bash
ConnectionStrings__DefaultConnection=Host=db;Port=5432;Database=elohim;Username=postgres;Password=...
ASPNETCORE_ENVIRONMENT=Development
```

---

## 8. Seguridad mínima obligatoria

- No registrar secretos en logs bajo ninguna circunstancia
- Validar autorización y autenticación en todos los endpoints sensibles
- Sanitizar entradas para prevenir inyecciones
- Mantener paquetes en versiones soportadas

---

## 9. Comandos de trabajo (desde `backend/`)
```bash
# Restaurar paquetes
dotnet restore ElohimShop.slnx

# Compilar
dotnet build ElohimShop.slnx

# Ejecutar API
dotnet run --project src/ElohimShop.API/ElohimShop.API.csproj

# Ejecutar pruebas (cuando existan)
dotnet test ElohimShop.slnx
```

---

## 10. Flujo recomendado para un cambio

1. Identificar capas afectadas y contratos existentes
2. Implementar en orden: `Domain` → `Application` → `Infrastructure` → `API`
3. Ajustar configuración y wiring de DI en `API`
4. Compilar: `dotnet build ElohimShop.slnx`
5. Validar comportamiento contra el contenedor de PostgreSQL si hay cambios de BD
6. Reportar impacto técnico y riesgos

---

## 11. Definition of Done

Una tarea backend se considera completa cuando:

- [ ] `dotnet build` pasa sin errores nuevos
- [ ] El comportamiento funcional solicitado está implementado
- [ ] No se rompen contratos HTTP sin aviso explícito
- [ ] Secretos y configuración necesaria están documentados en `.env.example`
- [ ] Se reportan riesgos, deuda técnica o pendientes identificados

---

## 12. Qué debe incluir la respuesta del agente

- **Resumen** del cambio realizado
- **Archivos modificados** con ruta completa
- **Comandos ejecutados** y su resultado
- **Impacto** en arquitectura, datos y contratos HTTP
- **Siguientes pasos** sugeridos (si aplica)

---

## 13. Qué NO hacer

- ❌ Lógica de negocio en controllers
- ❌ Referencias de `Domain` o `Application` hacia `Infrastructure` o `API`
- ❌ Credenciales o connection strings en código
- ❌ Editar archivos de migración manualmente
- ❌ Introducir librerías nuevas sin justificación clara
- ❌ Mezclar refactors grandes con cambios funcionales en una misma tarea
- ❌ `Console.WriteLine` de debug en código final
# RailRunService — Backend Structure & Conventions

## Architecture

**Clean Architecture** + **CQRS** (MediatR). 4 layers:

```
OSDM-Src/DotNetServices/RailRunService/
├── .API/            → Controllers, middleware, Program.cs
├── .Application/    → Commands, Queries, DTOs, interfaces
├── .Domain/         → Entities (pure, no dependencies)
└── .Infrastructure/ → DbContext, EF configs, repos, DI, services
```

**Stack**: .NET 8, EF Core + SQL Server, MediatR, AutoMapper, MassTransit + RabbitMQ, Ardalis.Specification

**Layer rules**: API → Application → Domain ← Infrastructure. Domain references nothing.

---

## API Endpoints

| Controller | Route | Methods |
|------------|-------|---------|
| Compositions | `api/compositions` | GET (list+pagination), GET `{id}`, POST, PUT `{id}`, DELETE `{id}`, POST `{id}/set-status` |
| Carriages | `api/compositions/{compositionId}/wagons` | GET, POST, PUT `{carriageId}`, DELETE `{carriageId}`, PUT `reorder` |
| Seats | `api/carriages/{carriageId}/seats` | GET (all), GET `{seatNumber}`, POST `block`, POST `unblock`, POST `sell`, POST `release`, GET `{seatNumber}/history`, POST `{seatNumber}/audit`, DELETE `{seatNumber}/audit` |
| Trains | `api/trains` | GET (?search=) |
| WagonTypes | `api/wagon-types` | GET (?travelClass=&compartmentType=) |
| CoachLayouts | `api/coach-layouts` | GET `?seriesName=`, GET `{id}` |
| Stations | `api/stations` | GET |

### Base Controller

All inherit `RailRunControllerBase` which provides:
- `HandleResult<T>(Result<T>)` → maps Result to HTTP response
- ErrorKind mapping: NotFound→404, Conflict→409, Validation→400, default→500

### Controller Pattern

```csharp
[ApiController]
[Route("api/[resource]")]
[Produces("application/json")]
public class XxxController : RailRunControllerBase
{
    private readonly IMediator _mediator;

    [HttpPost]
    public async Task<ActionResult<Result<T>>> Create([FromBody] CreateXxxDto dto)
    {
        var result = await _mediator.Send(new CreateXxxCommand { Dto = dto });
        return HandleResult(result);
    }
}
```

### Status Change

```
POST /api/compositions/{id}/set-status
Body: { "status": "ACTIVE" }   // uppercase: DRAFT, ACTIVE, ARCHIVED
```

---

## CQRS — Commands & Queries

**Pattern**: Command class + Handler class in the **same file**. Handler returns `Result<T>`.

### Compositions
| File | Returns | Purpose |
|------|---------|---------|
| CreateComposition.cs | Result\<CompositionDetailDto\> | Create with DRAFT status. Validates dates, operationDays, conflict check |
| UpdateComposition.cs | Result\<CompositionDetailDto\> | Partial update (all fields optional) |
| DeleteComposition.cs | Result | Cascade: deletes carriages, seats, audit logs, blocks |
| SetCompositionStatus.cs | Result\<CompositionDetailDto\> | Updates status string (uppercase) |
| GetCompositions.cs | Result\<PaginatedResult\<CompositionDto\>\> | Filters: trainNumber, status, dateFrom/dateTo. Pagination |
| GetCompositionById.cs | Result\<CompositionDetailDto\> | With carriages, resolves station names |

### Carriages
| File | Returns | Purpose |
|------|---------|---------|
| AddCarriage.cs | Result\<CompositionCarriageDto\> | Validates wagon type, stations, placard uniqueness |
| UpdateCarriage.cs | Result\<CompositionCarriageDto\> | Partial update |
| DeleteCarriage.cs | Result | Simple delete |
| ReorderCarriages.cs | Result\<List\<CompositionCarriageDto\>\> | Updates SequenceNumber for listed carriages |
| GetCarriages.cs | Result\<List\<CompositionCarriageDto\>\> | All carriages for composition, ordered by sequence |

### Seats
| File | Returns | Purpose |
|------|---------|---------|
| BlockSeats.cs | Result\<BlockSeatsResponseDto\> | Creates BlockedSeat record (JSON seat list) |
| UnblockSeats.cs | Result\<UnblockSeatsResponseDto\> | Supports partial unblock |
| SellSeats.cs | Result\<SellSeatsResponseDto\> | Creates/updates SeatAvailability → SOLD |
| ReleaseSeats.cs | Result\<ReleaseSeatsResponseDto\> | Resets SOLD → AVAILABLE |
| GetSeatStates.cs | Result\<List\<SeatStateDto\>\> | All seats with status: BLOCKED > SOLD > AVAILABLE |

### Nomenclatures
| File | Returns | Purpose |
|------|---------|---------|
| GetWagonTypes.cs | Result\<List\<WagonTypeDto\>\> | Optional filters: travelClass, compartmentType |
| GetTrains.cs | Result\<List\<TrainDto\>\> | Search by trainNumber (contains) |
| GetCoachLayoutById.cs | Result\<CoachLayoutDto\> | Layout with all seat definitions |
| GetCoachLayoutBySeries.cs | Result\<CoachLayoutDto\> | By wagon series name |

---

## Domain Entities

### Composition
| Property | Type | Notes |
|----------|------|-------|
| Id | long | PK |
| TrainNumber | string | max 20 |
| TrainScheduleId | long? | |
| ValidFrom / ValidTo | DateOnly | |
| OperationDays | string | 7 chars "1111100" (Mon-Sun) |
| Status | string | max 10, default "DRAFT" |
| AllocationRules | string? | |
| Version | int | default 1 |
| CreatedBy | long? | |
| CreatedAt / UpdatedAt | DateTime | sysutcdatetime() |

### CompositionCarriage
| Property | Type | Notes |
|----------|------|-------|
| Id | long | PK |
| CompositionId | long | FK → Composition |
| WagonTypeId | long | FK → WagonType |
| SequenceNumber | int | position in train |
| PlacardNumber | string | max 50 |
| UicNumber | string? | max 12 |
| StartStationUic / EndStationUic | string | max 7, UIC code |
| OperationType | string | NORMAL\|ATTACH\|DETACH\|TRANSFER |
| LinkedTrainNumber | string? | max 20 |
| IsActive | bool | default true |

### WagonType
| Property | Type | Notes |
|----------|------|-------|
| Id | long | PK |
| SeriesName | string | max 50, e.g. "21-43" |
| TravelClass | string | max 10: First, Second, Sleeper |
| DefaultCapacity | int | |
| CompartmentType | string | max 15: compartment, open, sleeper |
| Features | string? | JSON |
| ManufacturerCode | string? | max 50 |

### CoachLayout
| Property | Type | Notes |
|----------|------|-------|
| Id | long | PK |
| WagonTypeId | long | FK → WagonType |
| GridWidth / GridLength | int | |
| DeckCount | int | default 1 |
| RendererType | string | ROWS\|COLUMNS |
| OsdmLayoutJson | string | full layout JSON |

### SeatDefinition
| Property | Type | Notes |
|----------|------|-------|
| Id | long | PK |
| LayoutId | long | FK → CoachLayout |
| SeatNumber | string | max 10 |
| GridX / GridY | int | |
| AccommodationType | string | seat\|couchette\|berth |
| Attributes | string? | JSON |
| IsPhysicallyPresent | bool | default true |

### SeatAvailability
| Property | Type | Notes |
|----------|------|-------|
| Id | long | PK |
| CompCarriageId | long | FK → CompositionCarriage |
| SeatDefId | long | FK → SeatDefinition |
| TravelDate | DateOnly | |
| SegmentStartUic / SegmentEndUic | string | max 7 |
| Status | string | AVAILABLE\|SOLD\|LOCKED |
| ReservationId | long? | |
| PriceSnapshot | decimal? | (10,2) |
| LockedAt | DateTime? | |
| LockedBy | long? | |

### BlockedSeat
| Property | Type | Notes |
|----------|------|-------|
| Id | long | PK |
| CompCarriageId | long | FK |
| SeatNumbersJson | string | JSON array ["11","12"] |
| BlockType | string | max 20: maintenance, defect, reserved |
| ReasonDescription | string | |
| BlockedBy | long | |
| BlockedAt | DateTime | sysutcdatetime() |
| ActiveFrom / ActiveTo | DateOnly? | validity period |

### SeatAuditLog
| Property | Type | Notes |
|----------|------|-------|
| Id | long | PK |
| CompCarriageId | long | FK |
| SeatNumber | string | max 10 |
| Action | string | max 20: BLOCK, SELL, RELEASE |
| PerformedBy | string? | max 100 |
| Details | string? | max 500 |
| Timestamp | DateTime | sysutcdatetime() |

### AttributesDictionary
| Property | Type | Notes |
|----------|------|-------|
| Id | int | PK |
| Code | string | max 50, UNIQUE |
| DescriptionBg / DescriptionEn | string? | max 255 |
| IconUrl | string? | max 255 |
| OsdmMapping | string? | max 50 |

### Entity Relationships

```
Composition 1──M CompositionCarriage M──1 WagonType 1──M CoachLayout 1──M SeatDefinition
                      │                                                        │
                      ├──M BlockedSeat                                         │
                      ├──M SeatAuditLog                                        │
                      └──M SeatAvailability M──1───────────────────────────────┘
```

---

## Infrastructure

### DbContext

- 9 DbSets, collation `Latin1_General_100_CI_AI_SC`
- Entity configs in `Infrastructure/Data/Configurations/{Entity}Configuration.cs`
- All FKs use `DeleteBehavior.ClientSetNull` (cascade handled manually in delete commands)
- ASCII collation for code/status fields via `IsUnicode(false)`
- All datetime defaults: `sysutcdatetime()`

### Key Indexes

| Table | Index | Type |
|-------|-------|------|
| Compositions | (TrainNumber, ValidFrom, ValidTo, Status) | Filter |
| Compositions | (TrainNumber, ValidFrom, ValidTo) | UNIQUE |
| CompositionCarriages | (CompositionId, SequenceNumber) | Order |
| SeatDefinitions | (LayoutId, SeatNumber) | Lookup |
| SeatAvailability | (TravelDate, CompCarriageId, Status) | Availability |
| SeatAuditLog | (CompCarriageId, SeatNumber) | History |
| AttributesDictionary | Code | UNIQUE |

### DI Registration (ServiceCollectionExtensions)

```csharp
AddInfrastructureServices(config):
  1. SqlServerSettings from config/env
  2. AddDbContext<SqlDbContext>(UseSqlServer)
  3. AddHealthChecks().AddDbContextCheck<SqlDbContext>()
  4. IRepository<,> → BaseSqlRepository<,>                 // generic CRUD (auto-SaveChanges)
  5. IReadOnlyRepository<,> → BaseSqlReadOnlyRepository<,> // read-only
  6. IUnitOfWork → UnitOfWork                              // atomic SaveChanges
  7. Custom aggregate repos (ICompositionRepository, IWagonTypeRepository,
     ICoachLayoutRepository, IBlockedSeatRepository, ISampleRepository)
  8. MediatR (scans Application assembly)
  9. AddRabbitMQMessageBus() + IEventPublisher → MassTransitEventPublisher
 10. AddMemoryCache() + IStopPlaceService → StopPlaceService
```

### Aggregate Repositories + UnitOfWork

**Problem**: The generic `BaseSqlRepository<T, TKey>` calls `SaveChangesAsync` **inside every** `AddAsync` / `UpdateAsync` / `DeleteAsync` / `AddRangeAsync` / `DeleteRangeAsync`. Any handler that writes to more than one entity (create parent+child, delete aggregate, replace collection) ends up with multiple independent transactions — a partial failure leaves the DB inconsistent.

**Rule**: when a single logical operation writes to **more than one table**, do not use the generic repo. Use an aggregate-specific custom repo whose `Add`/`Remove`/`RemoveRange` methods only mutate the change tracker, and commit once via `IUnitOfWork.SaveChangesAsync`.

**Existing aggregate repositories:**

| Interface | Purpose | Used by |
|-----------|---------|---------|
| `ICompositionRepository` | Load composition graph (carriages, audit logs, seat availabilities, blocks); `Remove`, `RemoveRange` | `DeleteComposition` |
| `IWagonTypeRepository` | `GetAggregateByIdAsync` with `Include(CoachLayouts).ThenInclude(SeatDefinitions)`; `RemoveAggregate` | `DeleteWagonType` |
| `ICoachLayoutRepository` | `GetByIdWithSeatsAsync`; `ReplaceSeatDefinitions` (RemoveRange + AddRange) | `SaveSeatDefinitions` |
| `IBlockedSeatRepository` | `RemoveRange`, `UpdateRange` | seat unblock flows |

**Implementation template** (`Infrastructure/Repositories/{Xxx}Repository.cs`):

```csharp
public class XxxRepository : IXxxRepository
{
    private readonly SqlDbContext _context;
    public XxxRepository(SqlDbContext context) => _context = context;

    public async Task<Aggregate?> GetAggregateByIdAsync(long id, CancellationToken ct = default)
        => await _context.Aggregates
            .Include(a => a.Children).ThenInclude(c => c.GrandChildren)
            .FirstOrDefaultAsync(a => a.Id == id, ct);

    public void RemoveAggregate(Aggregate a)
    {
        foreach (var c in a.Children)
            _context.GrandChildren.RemoveRange(c.GrandChildren);
        _context.Children.RemoveRange(a.Children);
        _context.Aggregates.Remove(a);
    }
}
```

**Handler template**:

```csharp
var agg = await _xxxRepo.GetAggregateByIdAsync(id, ct);
if (agg == null) return Result.Fail("Not found.", ErrorKind.NotFound);

_xxxRepo.RemoveAggregate(agg);
await _unitOfWork.SaveChangesAsync(ct);   // single transaction for all writes
```

**Create via navigation property** (instead of FK id + second insert): set `Child.Parent = parent` on an untracked parent. EF traverses the graph and inserts both in one `SaveChanges`. Example in `CreateWagonType.cs`:

```csharp
var wagonType = new WagonType { ... };           // not added to any repo yet
var emptyLayout = new CoachLayout
{
    WagonType = wagonType,                       // nav prop — not WagonTypeId
    GridWidth = DefaultGridWidth, ...
};
await _coachLayoutRepo.AddAsync(emptyLayout);    // cascades insert of wagonType
// wagonType.Id is populated post-save
```

**When to use which repo:**

| Scenario | Use |
|----------|-----|
| Single-entity CRUD (`AddAsync`/`UpdateAsync`/`DeleteAsync` touches one row, one table) | Generic `IRepository<T, long>` |
| Read-only query | Generic `IReadOnlyRepository<T, long>` or custom repo's `Get*Async` |
| Multi-entity write (delete aggregate, replace child collection, create parent+child graph) | Custom `IXxxRepository` + `IUnitOfWork` |

**Anti-pattern** — chaining `AddAsync` / `DeleteAsync` on generic repos for related entities:

```csharp
// BAD — three separate transactions, partial-failure risk:
foreach (var layout in layouts)
{
    var seats = await _seatDefRepo.FindAsync(sd => sd.LayoutId == layout.Id);
    foreach (var seat in seats) await _seatDefRepo.DeleteAsync(seat.Id);
    await _coachLayoutRepo.DeleteAsync(layout.Id);
}
await _wagonTypeRepo.DeleteAsync(request.Id);
```

### StopPlaceService

Resolves UIC station codes → names via MassTransit request to NomenclatureService.
- Cache: `IMemoryCache` with 12-hour TTL (`FrozenDictionary<string, StopPlaceItem>`)
- Graceful fallback: returns UIC code if NomenclatureService is unreachable

---

## DTOs — Validation Rules

### CreateCompositionDto
- TrainNumber: `[Required, MaxLength(20)]`
- ValidFrom / ValidTo: `[Required]`, ValidFrom ≤ ValidTo
- OperationDays: `[Required, Regex("^[01]{7}$")]`, at least one '1'
- AllocationRules: optional

### AddCarriageDto
- WagonTypeId: `[Required]`
- SequenceNumber: `[Required]`
- PlacardNumber: `[Required, MaxLength(50)]`
- UicNumber: `[MaxLength(12)]`
- StartStationUic / EndStationUic: `[Required, MaxLength(7)]`
- OperationType: `[Regex("NORMAL|ATTACH|DETACH|TRANSFER")]`
- LinkedTrainNumber: `[MaxLength(20)]`

### BlockSeatsDto
- SeatNumbers: `[Required, MinLength(1)]`
- BlockType: `[Required, MaxLength(20)]`
- Reason: `[Required, MaxLength(500)]`
- ActiveFrom / ActiveTo: optional DateOnly

### UpdateXxxDto — all fields optional (partial update)

---

## Conventions

### File Naming

| What | Convention | Example |
|------|-----------|---------|
| Commands | `{Verb}{Entity}.cs` | `CreateComposition.cs` |
| Queries | `Get{Entity}[By{Filter}].cs` | `GetCompositionById.cs` |
| DTOs | `{Entity}Dto.cs` / `{Verb}{Entity}Dto.cs` | `CompositionDetailDto.cs` |
| Response DTOs | `{Action}{Entity}ResponseDto.cs` | `BlockSeatsResponseDto.cs` |
| Configurations | `{Entity}Configuration.cs` | `CompositionConfiguration.cs` |
| Controllers | `{Entities}Controller.cs` (plural) | `CompositionsController.cs` |

### Code Patterns

1. **Command + Handler in same file** — never separate
2. **Repository choice** — generic `IRepository<T, long>` for single-entity CRUD; custom `IXxxRepository` + `IUnitOfWork` for multi-entity writes (see *Aggregate Repositories + UnitOfWork*)
3. **One logical operation = one `SaveChangesAsync`** — never chain generic-repo writes for related entities; use the change tracker + `IUnitOfWork` so a partial failure rolls back
4. **Create graphs via navigation property** — set `Child.Parent = parent` on the child rather than saving parent first and copying the Id; EF inserts both in one `SaveChanges`
5. **Return `Result<T>`** — never throw exceptions for business errors
6. **DataAnnotations on DTOs** + business rules in handler
7. **Station names via `IStopPlaceService`** — never hardcode
8. **FK delete behavior**: `ClientSetNull` on all FKs — cascade deletes are done manually via the aggregate repo (load children via `Include`, `RemoveRange` them, `Remove` parent, one `SaveChanges`)
9. **Status strings uppercase**: "DRAFT", "ACTIVE", "ARCHIVED"
10. **OperationDays**: 7-char binary "1111100" = Mon-Fri
11. **Request/response DTOs live under `*.API/DTOs/`** — never declared inside controller files

### Result Pattern

```csharp
Result<T>.Ok(data);                              // success → 200
Result<T>.Fail("msg", ErrorKind.NotFound);        // → 404
Result<T>.Fail("msg", ErrorKind.Conflict);        // → 409
Result<T>.Fail("msg");                            // → 400
```

### Adding New Feature Checklist

1. Entity in `Domain/Entities/`
2. DbSet + `IEntityTypeConfiguration` in `Infrastructure/Data/`
3. Application DTOs in `Application/DTOs/{Feature}/`; API request/response DTOs in `API/DTOs/`
4. Commands/Queries in `Application/Features/{Feature}/` (Command + Handler in the same file)
5. If the handler writes to **more than one table**, add a custom `IXxxRepository` in `Application/Interfaces/` and implementation in `Infrastructure/Repositories/` — do **not** chain generic-repo writes
6. Controller in `API/Controllers/` (inherit `RailRunControllerBase`)
7. Register any new repo/service in `ServiceCollectionExtensions`
8. Migration: `dotnet ef migrations add {Name} --project .Infrastructure --startup-project .API`

---

## Program.cs Pipeline (exact order)

```
1. Azure Key Vault (optional)
2. Services:
   AddControllers, AddSwaggerGen, AddHttpClient, AddProblemDetails
   AddInfrastructureServices(config)
   AddAutoMapperConfiguration()
   JWT Bearer auth (Jwt:Secret, Jwt:Issuer, Jwt:Audience)
   AddAuthorization
3. Logging: ClearProviders → AddConsole → AddDebug
4. Build
5. Pipeline:
   UseSwagger + SwaggerUI
   MapHealthChecks("/health/db")
   AddMiddleware() → UserEmailMiddleware
   UseHttpsRedirection
   UseAuthentication + UseAuthorization
   MapControllers
6. Run
```

### Middleware

- `UserEmailMiddleware` — reads `X-User-Email` header → `HttpContext.Items["UserEmail"]`

---

## Configuration

| Setting | Source | Default |
|---------|--------|---------|
| SQL Connection | env `SqlServer:ConnectionString` > appsettings | localhost:14430 |
| JWT | `Jwt:Secret`, `Jwt:Issuer`, `Jwt:Audience` | — |
| HTTP Port | launchSettings | 5170 |
| HTTPS Port | launchSettings | 7155 |
| Docker Ports | dockerfile | 8080/8081 |

## Build & Run

```bash
dotnet build RailRunService.API/RailRunService.API.csproj
dotnet run --project RailRunService.API/RailRunService.API.csproj
dotnet ef migrations add {Name} --project RailRunService.Infrastructure --startup-project RailRunService.API
dotnet ef database update --project RailRunService.Infrastructure --startup-project RailRunService.API
```

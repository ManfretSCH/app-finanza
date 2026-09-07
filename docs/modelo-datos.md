# Modelo de datos

Base de datos **PostgreSQL 16**. Seis tablas, todas colgando de `users`.

## Diagrama entidad-relación

```mermaid
erDiagram
    users ||--o{ accounts     : "posee"
    users ||--o{ categories   : "personaliza"
    users ||--o{ transactions : "registra"
    users ||--o{ budgets      : "define"
    users ||--o{ goals        : "establece"
    accounts   ||--o{ transactions : "agrupa"
    categories ||--o{ transactions : "clasifica"
    categories ||--o{ budgets      : "limita"

    users {
        int      id PK
        string   email UK
        string   nombre
        string   password_hash
        datetime created_at
    }
    accounts {
        int      id PK
        int      user_id FK
        string   nombre
        enum     tipo "ahorro|corriente|tarjeta|efectivo"
        numeric  saldo_inicial
        string   moneda
        bool     activa
        datetime created_at
    }
    categories {
        int    id PK
        int    user_id FK "NULL = predefinida del sistema"
        string nombre
        enum   tipo "ingreso|gasto"
        string icono
        string color
    }
    transactions {
        int      id PK
        int      user_id FK
        int      account_id FK
        int      category_id FK
        enum     tipo "ingreso|gasto"
        numeric  monto
        string   descripcion
        date     fecha
        string   etiquetas
        datetime created_at
    }
    budgets {
        int     id PK
        int     user_id FK
        int     category_id FK
        numeric monto_limite
        int     mes
        int     anio
    }
    goals {
        int     id PK
        int     user_id FK
        string  nombre
        numeric monto_objetivo
        numeric monto_actual
        date    fecha_objetivo
        enum    estado "activa|completada|cancelada"
    }
```

## Decisiones de diseño

**El saldo de una cuenta no se guarda como columna.** Se calcula al vuelo:

```
saldo = saldo_inicial + SUM(ingresos) - SUM(gastos)
```

Si se guardara como campo mutable habría que actualizarlo en cada alta, edición y baja de transacción, y bastaría un error para que quedara desfasado del historial. Calcularlo garantiza que el saldo y los movimientos siempre coincidan.

**Los montos usan `Numeric(14,2)`, no `float`.** Los números de punto flotante arrastran errores de redondeo (`0.1 + 0.2 != 0.3`), inaceptable cuando se trata de dinero.

**Toda tabla tiene `user_id`.** Cada consulta filtra por el usuario extraído del token JWT, de modo que un usuario nunca puede leer ni modificar datos de otro (RNF-002).

**Las categorías predefinidas tienen `user_id = NULL`.** Se cargan una sola vez con el script de seed y son visibles para todos; las categorías personalizadas del usuario conviven con ellas en la misma tabla (RF-003).

**Restricción única en presupuestos:** `(user_id, category_id, mes, anio)` — no puede haber dos presupuestos para la misma categoría en el mismo mes (RF-004).

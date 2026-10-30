# Modelo de datos

Base de datos **PostgreSQL 16**. Ocho tablas: usuarios, cuentas, movimientos, presupuestos, metas de ahorro y sus catálogos.

## Diagrama entidad-relación

```mermaid
erDiagram
    users ||--o{ accounts : posee
    users ||--o{ account_types : personaliza
    account_types ||--o{ accounts : clasifica
    users ||--o{ categories : personaliza
    users ||--o{ transactions : registra
    users ||--o{ recurring_movements : configura
    users ||--o{ budgets : define
    users ||--o{ savings_goals : establece
    accounts ||--o{ transactions : agrupa
    categories ||--o{ transactions : clasifica
    categories ||--o{ recurring_movements : clasifica
    categories ||--o{ budgets : limita
    recurring_movements o|--o{ transactions : genera

    users {
        int id PK
        string email UK
        string nombre
        string password_hash
        datetime created_at
    }
    account_types {
        int id PK
        int user_id FK "NULL = sistema"
        string nombre
        string icono
    }
    accounts {
        int id PK
        int user_id FK
        int account_type_id FK
        string nombre
        numeric saldo_inicial
        string moneda
        bool activa
        datetime created_at
    }
    categories {
        int id PK
        int user_id FK "NULL = sistema"
        string nombre
        enum tipo "ingreso|gasto"
        string icono
        string color
    }
    transactions {
        int id PK
        int user_id FK
        int account_id FK
        int category_id FK
        int recurring_id FK "nullable"
        enum tipo "ingreso|gasto"
        numeric monto
        string descripcion
        date fecha
        string etiquetas
        datetime created_at
    }
    recurring_movements {
        int id PK
        int user_id FK
        int account_id FK
        int category_id FK
        enum tipo "ingreso|gasto"
        numeric monto
        int dia_del_mes
        date fecha_inicio
        date fecha_fin "nullable"
        bool activo
    }
    budgets {
        int id PK
        int user_id FK
        int category_id FK
        int mes
        int anio
        numeric limite
        datetime created_at
    }
    savings_goals {
        int id PK
        int user_id FK
        string nombre
        string descripcion
        numeric monto_objetivo
        numeric monto_actual
        date fecha_objetivo
        enum estado "activa|completada|cancelada"
        datetime created_at
    }
```

## Decisiones de diseño

**El saldo de una cuenta no se guarda como columna.** Se calcula al vuelo:

```
saldo = saldo_inicial + SUM(ingresos) - SUM(gastos)
```

Así, el saldo refleja siempre el historial de movimientos.

**Los montos usan `Numeric(14,2)`, no `float`.** Se evitan errores de redondeo en operaciones de dinero.

**Las consultas filtran por el usuario del token JWT.** Los datos de una persona no quedan accesibles para otra (RNF-002).

**Los tipos de cuenta y categorías predefinidos** tienen `user_id = NULL`; los personalizados pertenecen a un usuario.

**Los presupuestos son mensuales y únicos por categoría y usuario.** La restricción `(user_id, category_id, anio, mes)` impide duplicados. El gasto real y el porcentaje se calculan con las transacciones del período; los avisos se activan al 80 % y al 100 % del límite.

**Las metas guardan el objetivo, el monto ahorrado, la fecha objetivo y el estado.** El progreso se calcula como `monto_actual / monto_objetivo` y se limita al 100 % para la presentación.

**Los movimientos fijos generan transacciones reales.** Cada transacción conserva `recurring_id` para indicar su origen; al quitar la plantilla se mantiene el historial ya generado.

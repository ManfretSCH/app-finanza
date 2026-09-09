# Requerimientos del sistema

Transcripción del **Hito 3 – Análisis de Requerimientos y Diagramación del Sistema**.
Cada requerimiento indica en qué módulo del cronograma (Hito 2) se implementa.

## Requerimientos funcionales

| ID | Nombre | Descripción | Módulo |
|---|---|---|---|
| RF-001 | Gestión de cuentas | Crear, editar, eliminar y listar cuentas bancarias o de ahorro. Cada cuenta tiene tipo, saldo inicial y moneda. Los tipos son una tabla editable: las cuatro predefinidas del sistema más las que cree el usuario. | 1 |
| RF-002 | Registro de transacciones | Registrar ingresos y gastos con monto, categoría, descripción, fecha, cuenta asociada y etiquetas personalizadas. | 1 |
| RF-003 | Categorización de gastos | Categorías predefinidas (Alimentación, Transporte, Salud, Entretenimiento, etc.) con posibilidad de crear categorías personalizadas. | 1 |
| RF-004 | Gestión de presupuestos | Presupuestos mensuales por categoría, con alertas al alcanzar el 80 % y el 100 % del límite. | 2 |
| RF-005 | Metas de ahorro | Metas con fecha objetivo y monto, con seguimiento visual del progreso mediante gráficos. | 2 |
| RF-006 | Reportes y análisis | Resumen mensual (ingresos, gastos, balance), promedio de gasto diario, gasto día por día, distribución de gastos e ingresos por categoría, y tendencia mensual del año. | 3 |
| RF-007 | Gestión de usuarios | Registro, autenticación y gestión de perfil. Exportación del informe mensual en PDF y CSV. | 1 y 3 |

### Requerimientos agregados después del Hito 3

Estos no estaban en el análisis original. Se agregaron durante el desarrollo y se documentan acá para dejar constancia del cambio de alcance.

| ID | Nombre | Descripción | Módulo |
|---|---|---|---|
| RF-008 | Movimientos fijos | Registrar una sola vez un gasto o ingreso que se repite todos los meses (alquiler, cuotas, sueldo) y que el sistema genere el movimiento de cada mes automáticamente. | 2 |

**Por qué se agregó:** cargar a mano todos los meses lo que ya se sabe que se va a pagar es la parte más tediosa de una app de finanzas, y la que hace que la gente la abandone.

**Cómo se resolvió:** se guarda una plantilla y el servidor genera los movimientos que falten cuando el usuario abre la app. Son transacciones reales, así que el saldo, los filtros, los informes y la exportación funcionan sin saber nada de esto. No hace falta ningún proceso programado corriendo en el servidor, que la capa gratuita de Render no incluye.

## Requerimientos no funcionales

| ID | Nombre | Cómo se cumple |
|---|---|---|
| RNF-001 | Rendimiento | Índices en las columnas de filtrado (`user_id`, `fecha`, `category_id`); los listados se devuelven paginados y los totales se calculan en la base de datos, no en la app. Los archivos exportables también se generan en el servidor. |
| RNF-002 | Seguridad | Contraseñas hasheadas con bcrypt (nunca en texto plano), autenticación por JWT firmado, y cada consulta filtrada por el usuario del token para que nadie acceda a datos ajenos. |

## Casos de uso

Los cinco diagramas del Hito 3 están en [`diagramas/`](diagramas/):

| Diagrama | Casos de uso |
|---|---|
| [01 – Autenticación](diagramas/01-autenticacion.png) | Registrarse, Iniciar sesión, Cerrar sesión, Recuperar contraseña, Cambiar contraseña |
| [02 – Gestión de cuentas](diagramas/02-cuentas.png) | Crear cuenta, Editar cuenta, Ver cuentas, Eliminar cuenta, Ver saldo |
| [03 – Transacciones](diagramas/03-transacciones.png) | Registrar ingreso, Registrar gasto, Editar transacción, Ver transacciones, Filtrar por categoría |
| [04 – Presupuestos](diagramas/04-presupuestos.png) | Crear presupuesto, Editar presupuesto, Ver presupuestos, Recibir alertas, Ver progreso |
| [05 – Reportes y metas](diagramas/05-reportes-metas.png) | Crear meta de ahorro, Ver metas, Ver reportes mensuales, Exportar datos, Ver gráficos |

**Actor único:** Usuario. El sistema no contempla un rol de administrador.

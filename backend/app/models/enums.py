"""Enumeraciones compartidas por los modelos.

El tipo de cuenta no esta aca a proposito: es una tabla (account_types) para
que el usuario pueda crear los suyos, igual que con las categorias.
"""

import enum


class TipoMovimiento(str, enum.Enum):
    """Se usa para categorias y para transacciones."""

    INGRESO = "ingreso"
    GASTO = "gasto"


class EstadoMeta(str, enum.Enum):
    ACTIVA = "activa"
    COMPLETADA = "completada"
    CANCELADA = "cancelada"

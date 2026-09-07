"""Enumeraciones compartidas por los modelos."""

import enum


class TipoCuenta(str, enum.Enum):
    AHORRO = "ahorro"
    CORRIENTE = "corriente"
    TARJETA = "tarjeta"
    EFECTIVO = "efectivo"


class TipoMovimiento(str, enum.Enum):
    """Se usa tanto para categorias como para transacciones."""

    INGRESO = "ingreso"
    GASTO = "gasto"


class EstadoMeta(str, enum.Enum):
    ACTIVA = "activa"
    COMPLETADA = "completada"
    CANCELADA = "cancelada"

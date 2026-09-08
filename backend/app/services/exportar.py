"""Generacion de los archivos exportables (RF-006, RF-007).

El CSV es la lista de movimientos, para abrir en una planilla.
El PDF es el informe del mes ya armado, para imprimir o mandar.
"""

import csv
import io
from datetime import date
from decimal import Decimal

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models import Transaction, User
from app.models.enums import TipoMovimiento
from app.services import reports

MESES = [
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
]


def nombre_de_archivo(mes: int, anio: int, extension: str) -> str:
    return f"finanzas-{anio}-{mes:02d}.{extension}"


def _movimientos_del_mes(db: Session, user_id: int, mes: int, anio: int) -> list[Transaction]:
    desde, hasta = reports.rango_del_mes(mes, anio)
    return list(
        db.scalars(
            select(Transaction)
            .where(
                Transaction.user_id == user_id,
                Transaction.fecha >= desde,
                Transaction.fecha <= hasta,
            )
            .options(selectinload(Transaction.category), selectinload(Transaction.account))
            .order_by(Transaction.fecha, Transaction.id)
        ).all()
    )


def _monto_es(valor: Decimal) -> str:
    """Formatea un monto al estilo local: 1.234.567,89."""
    entero, _, decimales = f"{valor:.2f}".partition(".")
    negativo = entero.startswith("-")
    entero = entero.lstrip("-")
    grupos = []
    while len(entero) > 3:
        grupos.insert(0, entero[-3:])
        entero = entero[:-3]
    grupos.insert(0, entero)
    resultado = f"{'.'.join(grupos)},{decimales}"
    return f"-{resultado}" if negativo else resultado


# ---------------------------------------------------------------- CSV


def generar_csv(db: Session, user_id: int, mes: int, anio: int) -> bytes:
    """Lista de movimientos del mes.

    Se usa punto y coma como separador y coma decimal porque es lo que espera
    Excel configurado en espanol; con comas como separador abriria todo en una
    sola columna. El BOM al principio es lo que hace que Excel reconozca UTF-8
    y muestre bien los acentos al abrir el archivo con doble clic.
    """
    salida = io.StringIO()
    escritor = csv.writer(salida, delimiter=";", lineterminator="\r\n")

    escritor.writerow(["Fecha", "Tipo", "Categoría", "Cuenta", "Monto", "Descripción"])

    movimientos = _movimientos_del_mes(db, user_id, mes, anio)
    for m in movimientos:
        escritor.writerow([
            m.fecha.strftime("%d/%m/%Y"),
            m.tipo.value.capitalize(),
            m.category.nombre if m.category else "",
            m.account.nombre if m.account else "",
            _monto_es(Decimal(m.monto)),
            m.descripcion or "",
        ])

    resumen = reports.resumen_mensual(db, user_id, mes, anio)
    escritor.writerow([])
    escritor.writerow(["Total ingresos", "", "", "", _monto_es(resumen["ingresos"]), ""])
    escritor.writerow(["Total gastos", "", "", "", _monto_es(resumen["gastos"]), ""])
    escritor.writerow(["Balance", "", "", "", _monto_es(resumen["balance"]), ""])

    return "﻿".encode() + salida.getvalue().encode("utf-8")


# ---------------------------------------------------------------- PDF


def _tabla(
    datos: list[list[str]], anchos: list[float], alinear_derecha: list[int]
) -> Table:
    """Tabla con la primera fila como encabezado y las columnas de montos a la derecha."""
    tabla = Table(datos, colWidths=[a * mm for a in anchos], repeatRows=1)
    estilo = [
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8F0EB")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#1B4D38")),
        ("LINEBELOW", (0, 0), (-1, 0), 0.6, colors.HexColor("#2E7D5B")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F7FAF8")]),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]
    for columna in alinear_derecha:
        estilo.append(("ALIGN", (columna, 0), (columna, -1), "RIGHT"))
    tabla.setStyle(TableStyle(estilo))
    return tabla


def _pie_de_pagina(canvas, documento) -> None:
    """Numero de pagina al pie de cada hoja."""
    canvas.saveState()
    canvas.setFont("Helvetica", 7)
    canvas.setFillColorRGB(0.45, 0.45, 0.45)
    canvas.drawRightString(
        documento.pagesize[0] - 20 * 2.83, 12 * 2.83, f"Página {documento.page}"
    )
    canvas.drawString(20 * 2.83, 12 * 2.83, "Generado por Mis Finanzas")
    canvas.restoreState()


def generar_pdf(db: Session, user_id: int, mes: int, anio: int) -> bytes:
    """Informe del mes: resumen, en que se va la plata, de donde viene y el detalle."""
    usuario = db.get(User, user_id)
    resumen = reports.resumen_mensual(db, user_id, mes, anio)
    gastos = reports.por_categoria(db, user_id, TipoMovimiento.GASTO, mes, anio)
    ingresos = reports.por_categoria(db, user_id, TipoMovimiento.INGRESO, mes, anio)
    movimientos = _movimientos_del_mes(db, user_id, mes, anio)

    buffer = io.BytesIO()
    documento = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title=f"Informe {MESES[mes - 1]} {anio}",
        author="Mis Finanzas",
    )

    base = getSampleStyleSheet()
    titulo = ParagraphStyle(
        "titulo", parent=base["Title"], fontSize=17, textColor=colors.HexColor("#1B4D38")
    )
    subtitulo = ParagraphStyle(
        "subtitulo", parent=base["Normal"], fontSize=9,
        textColor=colors.HexColor("#666666"), alignment=TA_CENTER,
    )
    seccion = ParagraphStyle(
        "seccion", parent=base["Heading2"], fontSize=11,
        textColor=colors.HexColor("#1B4D38"), spaceBefore=14, spaceAfter=6,
    )
    nota = ParagraphStyle(
        "nota", parent=base["Normal"], fontSize=8, textColor=colors.HexColor("#666666")
    )

    partes = [
        Paragraph(f"Informe de {MESES[mes - 1]} {anio}", titulo),
        Paragraph(
            f"{usuario.nombre if usuario else ''} &nbsp;·&nbsp; "
            f"generado el {date.today().strftime('%d/%m/%Y')}",  # noqa: DTZ011
            subtitulo,
        ),
        Spacer(1, 10 * mm),
    ]

    # Resumen
    partes.append(
        _tabla(
            [
                ["Concepto", "Monto"],
                ["Ingresos del mes", _monto_es(resumen["ingresos"])],
                ["Gastos del mes", _monto_es(resumen["gastos"])],
                ["Balance", _monto_es(resumen["balance"])],
                ["Gasto promedio por día", _monto_es(resumen["promedio_diario_gasto"])],
                ["Movimientos registrados", str(resumen["cantidad_movimientos"])],
            ],
            anchos=[110, 60],
            alinear_derecha=[1],
        )
    )
    partes.append(Spacer(1, 3 * mm))
    partes.append(
        Paragraph(
            f"El promedio se calcula sobre {resumen['dias_considerados']} días.", nota
        )
    )

    def bloque_categorias(encabezado: str, filas: list[dict], vacio: str) -> list:
        contenido = [Paragraph(encabezado, seccion)]
        if not filas:
            contenido.append(Paragraph(vacio, nota))
            return contenido
        contenido.append(
            _tabla(
                [["Categoría", "Movimientos", "Porcentaje", "Total"]]
                + [
                    [
                        f["categoria"].nombre,
                        str(f["cantidad"]),
                        f"{f['porcentaje']:.1f}%",
                        _monto_es(f["total"]),
                    ]
                    for f in filas
                ],
                anchos=[70, 30, 30, 40],
                alinear_derecha=[1, 2, 3],
            )
        )
        return contenido

    partes += bloque_categorias(
        "En qué se fue la plata", gastos, "No hubo gastos en este mes."
    )
    partes += bloque_categorias(
        "De dónde vino la plata", ingresos, "No hubo ingresos en este mes."
    )

    # Detalle
    partes.append(Paragraph("Detalle de movimientos", seccion))
    if movimientos:
        partes.append(
            _tabla(
                [["Fecha", "Tipo", "Categoría", "Cuenta", "Descripción", "Monto"]]
                + [
                    [
                        m.fecha.strftime("%d/%m"),
                        m.tipo.value.capitalize(),
                        m.category.nombre if m.category else "",
                        m.account.nombre if m.account else "",
                        (m.descripcion or "")[:34],
                        _monto_es(Decimal(m.monto)),
                    ]
                    for m in movimientos
                ],
                anchos=[18, 20, 34, 32, 42, 24],
                alinear_derecha=[5],
            )
        )
    else:
        partes.append(Paragraph("No hay movimientos registrados en este mes.", nota))

    documento.build(partes, onFirstPage=_pie_de_pagina, onLaterPages=_pie_de_pagina)
    return buffer.getvalue()

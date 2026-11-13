"""Modulo 2: presupuestos mensuales y metas de ahorro.

Esta migracion ya se aplico en la base de produccion cuando se desplego el
primer intento del Modulo 2 (PR #3). Por eso conserva el mismo identificador
y el mismo esquema: si cambiara, el servidor no reconoceria la version en la
que quedo la base y el despliegue fallaria al arrancar. Cualquier cambio de
esquema nuevo va en una migracion aparte, encima de esta.

Revision ID: b7421f1f2a91
Revises: 05979cb0ff14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "b7421f1f2a91"
down_revision: str | Sequence[str] | None = "05979cb0ff14"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "budgets",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "category_id",
            sa.Integer(),
            sa.ForeignKey("categories.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("anio", sa.Integer(), nullable=False),
        sa.Column("mes", sa.Integer(), nullable=False),
        sa.Column("limite", sa.Numeric(14, 2), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "user_id", "category_id", "anio", "mes", name="uq_budget_user_category_period"
        ),
        sa.CheckConstraint("mes >= 1 AND mes <= 12", name="ck_budget_mes"),
        sa.CheckConstraint("limite > 0", name="ck_budget_limite"),
    )
    op.create_index("ix_budgets_user_id", "budgets", ["user_id"])
    op.create_index("ix_budgets_category_id", "budgets", ["category_id"])

    op.create_table(
        "savings_goals",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("nombre", sa.String(120), nullable=False),
        sa.Column("descripcion", sa.String(255)),
        sa.Column("monto_objetivo", sa.Numeric(14, 2), nullable=False),
        sa.Column("monto_actual", sa.Numeric(14, 2), nullable=False, server_default="0"),
        sa.Column("fecha_objetivo", sa.Date(), nullable=False),
        sa.Column(
            "estado",
            sa.Enum("ACTIVA", "COMPLETADA", "CANCELADA", name="estado_meta"),
            nullable=False,
            server_default="ACTIVA",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("monto_objetivo > 0", name="ck_savings_goal_target_positive"),
        sa.CheckConstraint("monto_actual >= 0", name="ck_savings_goal_saved_nonnegative"),
    )
    op.create_index("ix_savings_goals_user_id", "savings_goals", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_savings_goals_user_id", table_name="savings_goals")
    op.drop_table("savings_goals")
    op.drop_index("ix_budgets_category_id", table_name="budgets")
    op.drop_index("ix_budgets_user_id", table_name="budgets")
    op.drop_table("budgets")
    # drop_table no borra el tipo enum que creo create_table.
    postgresql.ENUM(name="estado_meta").drop(op.get_bind(), checkfirst=True)

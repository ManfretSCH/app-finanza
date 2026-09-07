"""Los tipos de cuenta pasan de ser un enum fijo a una tabla editable

Antes el tipo de cuenta era un enum en la base, asi que solo se podian usar los
cuatro valores que estaban escritos en el codigo. Ahora es una tabla, para que
cada usuario pueda crear los suyos igual que hace con las categorias.

La migracion conserva las cuentas ya cargadas: cada valor del enum se mapea al
tipo predefinido equivalente antes de borrar la columna vieja.

Revision ID: 2f312f981bab
Revises: c436c63a092d
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "2f312f981bab"
down_revision: str | Sequence[str] | None = "c436c63a092d"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Valor del enum viejo -> nombre del tipo predefinido nuevo
EQUIVALENCIAS = {
    "AHORRO": "Caja de ahorro",
    "CORRIENTE": "Cuenta corriente",
    "TARJETA": "Tarjeta de credito",
    "EFECTIVO": "Efectivo",
}

PREDEFINIDOS = [
    ("Caja de ahorro", "savings"),
    ("Cuenta corriente", "account_balance"),
    ("Tarjeta de credito", "credit_card"),
    ("Efectivo", "payments"),
]


def upgrade() -> None:
    op.create_table(
        "account_types",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("nombre", sa.String(length=80), nullable=False),
        sa.Column("icono", sa.String(length=40), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_account_types_user_id", "account_types", ["user_id"])

    # Los predefinidos tienen que existir antes de poder apuntar las cuentas a ellos.
    for nombre, icono in PREDEFINIDOS:
        op.execute(
            sa.text(
                "INSERT INTO account_types (user_id, nombre, icono) "
                "VALUES (NULL, :nombre, :icono)"
            ).bindparams(nombre=nombre, icono=icono)
        )

    # Nullable al principio para poder rellenarla; despues se exige.
    op.add_column("accounts", sa.Column("account_type_id", sa.Integer(), nullable=True))

    for valor_enum, nombre in EQUIVALENCIAS.items():
        op.execute(
            sa.text(
                "UPDATE accounts SET account_type_id = "
                "(SELECT id FROM account_types WHERE user_id IS NULL AND nombre = :nombre) "
                "WHERE tipo::text = :valor_enum"
            ).bindparams(nombre=nombre, valor_enum=valor_enum)
        )

    # Red de seguridad: cualquier cuenta que no haya quedado mapeada va a Efectivo.
    op.execute(
        sa.text(
            "UPDATE accounts SET account_type_id = "
            "(SELECT id FROM account_types WHERE user_id IS NULL AND nombre = 'Efectivo') "
            "WHERE account_type_id IS NULL"
        )
    )

    op.alter_column("accounts", "account_type_id", nullable=False)
    op.create_index("ix_accounts_account_type_id", "accounts", ["account_type_id"])
    op.create_foreign_key(
        "fk_accounts_account_type_id", "accounts", "account_types", ["account_type_id"], ["id"]
    )

    op.drop_column("accounts", "tipo")
    # El enum tipo_movimiento NO se toca: lo siguen usando categories y transactions.
    op.execute("DROP TYPE IF EXISTS tipo_cuenta")


def downgrade() -> None:
    tipo_cuenta = sa.Enum(
        "AHORRO", "CORRIENTE", "TARJETA", "EFECTIVO", name="tipo_cuenta"
    )
    tipo_cuenta.create(op.get_bind(), checkfirst=True)
    op.add_column("accounts", sa.Column("tipo", tipo_cuenta, nullable=True))

    for valor_enum, nombre in EQUIVALENCIAS.items():
        op.execute(
            sa.text(
                "UPDATE accounts SET tipo = CAST(:valor_enum AS tipo_cuenta) "
                "WHERE account_type_id = "
                "(SELECT id FROM account_types WHERE user_id IS NULL AND nombre = :nombre)"
            ).bindparams(nombre=nombre, valor_enum=valor_enum)
        )
    # Los tipos creados por usuarios no tienen equivalente en el enum: van a EFECTIVO.
    op.execute("UPDATE accounts SET tipo = 'EFECTIVO' WHERE tipo IS NULL")
    op.alter_column("accounts", "tipo", nullable=False)

    op.drop_constraint("fk_accounts_account_type_id", "accounts", type_="foreignkey")
    op.drop_index("ix_accounts_account_type_id", table_name="accounts")
    op.drop_column("accounts", "account_type_id")
    op.drop_index("ix_account_types_user_id", table_name="account_types")
    op.drop_table("account_types")

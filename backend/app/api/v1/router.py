"""Agrupa todos los routers de la version 1 de la API."""

from fastapi import APIRouter

from app.api.v1 import (
    account_types,
    accounts,
    auth,
    categories,
    recurring,
    reports,
    transactions,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(account_types.router)
api_router.include_router(accounts.router)
api_router.include_router(categories.router)
api_router.include_router(transactions.router)
api_router.include_router(recurring.router)
api_router.include_router(reports.router)

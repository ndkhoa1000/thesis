from fastapi import APIRouter

from .auth import router as auth_router
from .health import router as health_router
from .login import router as login_router
from .logout import router as logout_router
from .posts import router as posts_router
from .rate_limits import router as rate_limits_router
from .tasks import router as tasks_router
from .tiers import router as tiers_router
from .users import router as users_router

# --- Smart Parking Domain Routers ---
from .lots import router as lots_router
from .sessions import router as sessions_router
from .bookings import router as bookings_router
from .leases import router as leases_router
from .reports import router as reports_router
from .payments import router as payments_router
from .shifts import router as shifts_router

router = APIRouter(prefix="/v1")
router.include_router(auth_router)
router.include_router(health_router)
router.include_router(login_router)
router.include_router(logout_router)
router.include_router(users_router)
router.include_router(posts_router)
router.include_router(tasks_router)
router.include_router(tiers_router)
router.include_router(rate_limits_router)

# --- Smart Parking Domain Routes ---
router.include_router(lots_router)
router.include_router(sessions_router)
router.include_router(bookings_router)
router.include_router(leases_router)
router.include_router(reports_router)
router.include_router(payments_router)
router.include_router(shifts_router)

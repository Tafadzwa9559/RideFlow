
from django.conf import settings
from django.contrib import admin
from django.urls import path, include, register_converter
from django.views.generic import RedirectView

from rest_framework.permissions import AllowAny, IsAdminUser
from rest_framework.routers import DefaultRouter

from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
    SpectacularRedocView,
)

from core.identifiers import ObjectIdConverter
from core.views import (
    health,
    ready,
    WebSocketDocumentationView,
)
from core.schema import annotate

from accounts.api.views import (
    OTPRequestView,
    OTPVerifyView,
    LogoutView,
    MeView,
    RefreshView,
)

from notifications.api.views import (
    NotificationsView,
    ReadView,
    DeviceView,
)

from core.admin_api import (
    ZoneViewSet,
    PriceViewSet,
    AdminRideViewSet,
    TicketViewSet,
    OverviewView,
    AdminCancelView,
    AccountStatusView,
    UserViewSet,
    VehicleReviewView,
    OfferViewSet,
    AuditViewSet,
    DocumentRequirementViewSet,
)

from core.admin_resources import (
    ManagedDriverViewSet,
    ApplicationAdminViewSet,
    ManagedVehicleViewSet,
    PassengerViewSet,
    DisputeViewSet,
    AnalyticsView,
    ReportsView,
    AdminTimelineView,
)


# ============================================================
# 1. CUSTOM URL CONVERTERS
# ============================================================

register_converter(ObjectIdConverter, "objectid")


# ============================================================
# 2. SWAGGER / OPENAPI PERMISSIONS
# ============================================================
# Local development:
#     Swagger documentation is accessible without login.
#
# Production:
#     Swagger documentation requires admin authentication.
#
# Never enable DEBUG in production.

docs_permissions = [AllowAny] if settings.DEBUG else [IsAdminUser]


# ============================================================
# 3. PASSENGER AND DRIVER API ROUTES
# ============================================================

api_patterns = [
    # Core APIs
    path("", include("core.api_urls")),

    # Ride APIs
    path("", include("rides.api.urls")),

    # Direct payment preferences
    path("", include("payments.api.urls")),

    # Driver APIs
    path("", include("drivers.api.urls")),

    # Authentication
    path(
        "auth/otp/request/",
        OTPRequestView.as_view(),
        name="auth-otp-request",
    ),
    path(
        "auth/otp/verify/",
        OTPVerifyView.as_view(),
        name="auth-otp-verify",
    ),
    path(
        "auth/token/refresh/",
        RefreshView.as_view(),
        name="auth-token-refresh",
    ),
    path(
        "auth/logout/",
        LogoutView.as_view(),
        name="auth-logout",
    ),
    path(
        "auth/me/",
        MeView.as_view(
            http_method_names=["get", "options"]
        ),
        name="auth-me",
    ),

    # User Profile
    path(
        "me/",
        MeView.as_view(),
        name="current-user",
    ),
    path(
        "users/me/",
        MeView.as_view(
            http_method_names=["get", "patch", "options"]
        ),
        name="user-profile",
    ),

    # Notifications
    path(
        "notifications/",
        NotificationsView.as_view(),
        name="notifications",
    ),
    path(
        "notifications/devices/",
        DeviceView.as_view(),
        name="notification-devices",
    ),
    path(
        "notifications/<uuid:pk>/read/",
        ReadView.as_view(),
        name="notification-read",
    ),
]


# ============================================================
# 4. ADMIN API ROUTER
# ============================================================

admin_router = DefaultRouter()

admin_router.register(
    "service-areas",
    ZoneViewSet,
)

admin_router.register(
    "pricing",
    PriceViewSet,
)

admin_router.register(
    "drivers",
    ManagedDriverViewSet,
    basename="admin-driver",
)

admin_router.register(
    "driver-applications",
    ApplicationAdminViewSet,
    basename="driver-application",
)

admin_router.register(
    "passengers",
    PassengerViewSet,
    basename="passenger",
)

admin_router.register(
    "disputes",
    DisputeViewSet,
    basename="dispute",
)

admin_router.register(
    "pricing-rules",
    PriceViewSet,
    basename="pricing-rule",
)

admin_router.register(
    "audit-logs",
    AuditViewSet,
    basename="audit-log",
)

admin_router.register(
    "rides",
    AdminRideViewSet,
)

admin_router.register(
    "tickets",
    TicketViewSet,
)

admin_router.register(
    "users",
    UserViewSet,
)

admin_router.register(
    "vehicles",
    ManagedVehicleViewSet,
    basename="admin-vehicle",
)

admin_router.register(
    "offers",
    OfferViewSet,
)

admin_router.register(
    "audit",
    AuditViewSet,
)


# ============================================================
# 5. ADMIN CONFIGURATION ROUTER
# ============================================================

configuration_router = DefaultRouter()

configuration_router.register(
    "document-requirements",
    DocumentRequirementViewSet,
)


# ============================================================
# 6. MAIN URL CONFIGURATION
# ============================================================

urlpatterns = [

    # --------------------------------------------------------
    # ROOT URL — REDIRECT TO SWAGGER
    # --------------------------------------------------------

    path(
        "",
        RedirectView.as_view(
            pattern_name="swagger-ui",
            permanent=False,
        ),
        name="home",
    ),

    # --------------------------------------------------------
    # DJANGO ADMIN
    # --------------------------------------------------------

    path(
        "admin/",
        admin.site.urls,
    ),

    # --------------------------------------------------------
    # MAIN APPLICATION APIs
    # --------------------------------------------------------

    path(
        "api/v1/",
        include(api_patterns),
    ),

    # Preserve existing Flutter API alias
    path(
        "mobile/v1/",
        include(api_patterns),
    ),

    # --------------------------------------------------------
    # HEALTH CHECKS
    # --------------------------------------------------------

    path(
        "health/",
        health,
        name="health",
    ),

    path(
        "ready/",
        ready,
        name="ready",
    ),

    # --------------------------------------------------------
    # SWAGGER / OPENAPI DOCUMENTATION
    # --------------------------------------------------------

    path(
        "api/schema/",
        SpectacularAPIView.as_view(
            permission_classes=docs_permissions,
        ),
        name="schema",
    ),

    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(
            url_name="schema",
            permission_classes=docs_permissions,
        ),
        name="swagger-ui",
    ),

    path(
        "api/redoc/",
        SpectacularRedocView.as_view(
            url_name="schema",
            permission_classes=docs_permissions,
        ),
        name="redoc",
    ),

    # --------------------------------------------------------
    # WEBSOCKET DOCUMENTATION
    # --------------------------------------------------------

    path(
        "api/websockets/",
        WebSocketDocumentationView.as_view(),
        name="websocket-documentation",
    ),

    # --------------------------------------------------------
    # SPECIFIC ADMIN API ROUTES
    # --------------------------------------------------------
    # Keep these before the general admin routers.

    path(
        "api/v1/admin/overview/",
        OverviewView.as_view(),
        name="admin-overview",
    ),

    path(
        "api/v1/admin/rides/<uuid:pk>/cancel/",
        AdminCancelView.as_view(),
        name="admin-ride-cancel",
    ),

    path(
        "api/v1/admin/users/<objectid:pk>/status/",
        AccountStatusView.as_view(),
        name="admin-user-status",
    ),

    path(
        "api/v1/admin/vehicles/<objectid:pk>/review/",
        VehicleReviewView.as_view(),
        name="admin-vehicle-review",
    ),

    # --------------------------------------------------------
    # ADMIN DASHBOARD
    # --------------------------------------------------------

    path(
        "api/v1/admin/dashboard/overview/",
        OverviewView.as_view(),
        name="admin-dashboard-overview",
    ),

    path(
        "api/v1/admin/dashboard/ride-analytics/",
        AnalyticsView.as_view(),
        name="admin-ride-analytics",
    ),

    path(
        "api/v1/admin/dashboard/driver-analytics/",
        AnalyticsView.as_view(
            kind="driver-analytics"
        ),
        name="admin-driver-analytics",
    ),

    path(
        "api/v1/admin/dashboard/platform-activity/",
        AnalyticsView.as_view(
            kind="platform-activity"
        ),
        name="admin-platform-activity",
    ),

    # --------------------------------------------------------
    # ADMIN REPORTS
    # --------------------------------------------------------

    path(
        "api/v1/admin/reports/rides/",
        ReportsView.as_view(
            kind="rides"
        ),
        name="admin-report-rides",
    ),

    path(
        "api/v1/admin/reports/drivers/",
        ReportsView.as_view(
            kind="drivers"
        ),
        name="admin-report-drivers",
    ),

    path(
        "api/v1/admin/reports/passengers/",
        ReportsView.as_view(
            kind="passengers"
        ),
        name="admin-report-passengers",
    ),

    path(
        "api/v1/admin/reports/earnings/",
        ReportsView.as_view(
            kind="earnings"
        ),
        name="admin-report-earnings",
    ),

    path(
        "api/v1/admin/rides/<uuid:pk>/timeline/",
        AdminTimelineView.as_view(),
        name="admin-ride-timeline",
    ),

    # --------------------------------------------------------
    # ADMIN RESOURCE ROUTERS
    # --------------------------------------------------------

    path(
        "api/v1/admin/",
        include(admin_router.urls),
    ),

    path(
        "api/v1/admin/",
        include(configuration_router.urls),
    ),
]


# ============================================================
# 7. OPENAPI SCHEMA ANNOTATIONS
# ============================================================

annotate()

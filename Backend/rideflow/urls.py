"""URL routing for Trivia's passenger, driver and administrative services.

In production, OpenAPI documentation requires an authenticated Django staff session.
"""

from django.conf import settings
from django.contrib import admin
from django.contrib.admin.views.decorators import staff_member_required
from django.urls import include, path, register_converter
from django.views.generic import RedirectView
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)
from rest_framework.authentication import SessionAuthentication
from rest_framework.permissions import AllowAny, IsAdminUser
from rest_framework.routers import DefaultRouter

from accounts.api.passwords import (
    ChangePasswordView, PassengerTestingView, PasswordLoginView, RecoveryRequestView, RecoveryResetView, RecoveryVerifyView, RegistrationView, SignupResendView, SignupVerifyView, StaffLoginView,
)
from accounts.api.views import LogoutView, MeView, OTPRequestView, OTPVerifyView, RefreshView
from core.admin_api import (
    AccountStatusView,
    AdminCancelView,
    AdminRideViewSet,
    AuditViewSet,
    DocumentRequirementViewSet,
    OfferViewSet,
    OverviewView,
    PriceViewSet,
    TicketViewSet,
    UserViewSet,
    VehicleReviewView,
    ZoneViewSet,
)
from core.admin_resources import (
    AdminTimelineView,
    AnalyticsView,
    ApplicationAdminViewSet,
    DisputeViewSet,
    ManagedDriverViewSet,
    ManagedVehicleViewSet,
    PassengerViewSet,
    ReportsView,
)
from core.identifiers import ObjectIdConverter
from core.schema import annotate
from core.views import WebSocketDocumentationView, health, ready
from notifications.api.views import DeviceView, NotificationsView, ReadView


register_converter(ObjectIdConverter, "objectid")


def staff_documentation(view_class, **kwargs):
    """Public in DEBUG; staff session + admin-login redirect in production.

    Staff validation is applied to both the HTML viewers *and* the underlying
    OpenAPI schema. The latter is fetched separately by Swagger/ReDoc.
    """
    permissions = [AllowAny] if settings.DEBUG else [IsAdminUser]
    view = view_class.as_view(
        authentication_classes=[SessionAuthentication],
        permission_classes=permissions,
        **kwargs,
    )
    if not settings.DEBUG:
        view = staff_member_required(view, login_url="/admin/login/")
    return view


# The two public URL prefixes intentionally share the same API handlers.
api_patterns = [
    path("", include("core.api_urls")),
    path("", include("rides.api.urls")),
    path("", include("payments.api.urls")),
    path("", include("drivers.api.urls")),
    path("auth/register/", RegistrationView.as_view(), name="auth-register"),
    path("auth/email/resend/", SignupResendView.as_view(), name="auth-email-resend"),
    path("auth/email/verify/", SignupVerifyView.as_view(), name="auth-email-verify"),
    path("auth/login/", PasswordLoginView.as_view(), name="auth-password-login"),
    path("auth/passenger-testing/", PassengerTestingView.as_view(), name="auth-passenger-testing"),
    path("auth/password/request/", RecoveryRequestView.as_view(), name="auth-password-request"),
    path("auth/password/verify/", RecoveryVerifyView.as_view(), name="auth-password-verify"),
    path("auth/password/change/", ChangePasswordView.as_view(), name="auth-password-change"),
    path("auth/password/reset/", RecoveryResetView.as_view(), name="auth-password-reset"),
    path("auth/otp/request/", OTPRequestView.as_view(), name="auth-otp-request"),
    path("auth/otp/verify/", OTPVerifyView.as_view(), name="auth-otp-verify"),
    path("auth/token/refresh/", RefreshView.as_view(), name="auth-token-refresh"),
    path("auth/logout/", LogoutView.as_view(), name="auth-logout"),
    path(
        "auth/me/",
        MeView.as_view(http_method_names=["get", "options"]),
        name="auth-me",
    ),
    path("me/", MeView.as_view(), name="current-user"),
    path(
        "users/me/",
        MeView.as_view(http_method_names=["get", "patch", "options"]),
        name="user-profile",
    ),
    path("notifications/", NotificationsView.as_view(), name="notifications"),
    path("notifications/devices/", DeviceView.as_view(), name="notification-devices"),
    path(
        "notifications/<uuid:pk>/read/",
        ReadView.as_view(),
        name="notification-read",
    ),
]


admin_router = DefaultRouter()
admin_router.register("service-areas", ZoneViewSet)
admin_router.register("pricing", PriceViewSet)
admin_router.register("drivers", ManagedDriverViewSet, basename="admin-driver")
admin_router.register(
    "driver-applications", ApplicationAdminViewSet, basename="driver-application"
)
admin_router.register("passengers", PassengerViewSet, basename="passenger")
admin_router.register("disputes", DisputeViewSet, basename="dispute")
admin_router.register("pricing-rules", PriceViewSet, basename="pricing-rule")
admin_router.register("audit-logs", AuditViewSet, basename="audit-log")
admin_router.register("rides", AdminRideViewSet)
admin_router.register("tickets", TicketViewSet)
admin_router.register("users", UserViewSet)
admin_router.register("vehicles", ManagedVehicleViewSet, basename="admin-vehicle")
admin_router.register("offers", OfferViewSet)
admin_router.register("audit", AuditViewSet)

configuration_router = DefaultRouter()
configuration_router.register("document-requirements", DocumentRequirementViewSet)


urlpatterns = [
    # The home redirect follows the documentation permission rules.
    path("", RedirectView.as_view(pattern_name="swagger-ui", permanent=False), name="home"),
    path("admin/", admin.site.urls),

    # Passenger/driver API and its legacy mobile alias.
    path("api/v1/", include(api_patterns)),
    path("mobile/v1/", include(api_patterns)),

    # Operational and documentation endpoints.
    path("health/", health, name="health"),
    path("ready/", ready, name="ready"),
    path("api/schema/", staff_documentation(SpectacularAPIView), name="schema"),
    path(
        "api/docs/",
        staff_documentation(
            SpectacularSwaggerView,
            url_name="schema",
            template_name="core/trivia_swagger.html",
        ),
        name="swagger-ui",
    ),
    path(
        "api/redoc/",
        staff_documentation(SpectacularRedocView, url_name="schema"),
        name="redoc",
    ),
    path(
        "api/websockets/",
        WebSocketDocumentationView.as_view(),
        name="websocket-documentation",
    ),

    path("api/v1/admin/auth/login/", StaffLoginView.as_view(), name="admin-auth-login"),

    # Specific admin endpoints must precede the router registrations.
    path("api/v1/admin/overview/", OverviewView.as_view(), name="admin-overview"),
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
        AnalyticsView.as_view(kind="driver-analytics"),
        name="admin-driver-analytics",
    ),
    path(
        "api/v1/admin/dashboard/platform-activity/",
        AnalyticsView.as_view(kind="platform-activity"),
        name="admin-platform-activity",
    ),
    path(
        "api/v1/admin/reports/rides/",
        ReportsView.as_view(kind="rides"),
        name="admin-report-rides",
    ),
    path(
        "api/v1/admin/reports/drivers/",
        ReportsView.as_view(kind="drivers"),
        name="admin-report-drivers",
    ),
    path(
        "api/v1/admin/reports/passengers/",
        ReportsView.as_view(kind="passengers"),
        name="admin-report-passengers",
    ),
    path(
        "api/v1/admin/reports/earnings/",
        ReportsView.as_view(kind="earnings"),
        name="admin-report-earnings",
    ),
    path(
        "api/v1/admin/rides/<uuid:pk>/timeline/",
        AdminTimelineView.as_view(),
        name="admin-ride-timeline",
    ),

    # Keep both routers: the second holds the document-requirements APIs.
    path("api/v1/admin/", include(admin_router.urls)),
    path("api/v1/admin/", include(configuration_router.urls)),
]

# Apply the project's existing schema customisations.
annotate()

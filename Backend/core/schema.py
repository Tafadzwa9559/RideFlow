"""Typed HTTP contracts and curated, permission-aware OpenAPI presentation."""
from drf_spectacular.extensions import OpenApiAuthenticationExtension, OpenApiSerializerFieldExtension
from drf_spectacular.openapi import AutoSchema
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, PolymorphicProxySerializer
from drf_spectacular.types import OpenApiTypes
from rest_framework import serializers as s
from core import contracts as c


class JWTAuthenticationScheme(OpenApiAuthenticationExtension):
    target_class = 'accounts.authentication.SessionJWTAuthentication'
    name = 'jwtAuth'

    def get_security_definition(self, auto_schema):
        return {'type': 'http', 'scheme': 'bearer', 'bearerFormat': 'JWT'}


class ObjectIdFieldSchema(OpenApiSerializerFieldExtension):
    target_class = 'core.identifiers.ObjectIdSerializerField'

    def map_serializer_field(self, auto_schema, direction):
        return {'type': 'string', 'pattern': '^[0-9a-fA-F]{24}$'}


def canonical_paths(endpoints):
    # Legacy aliases have the same implementation and are listed in the integration guide.
    aliases = ['/api/v1/me/', '/api/v1/driver/', '/api/v1/locations/saved/', '/api/v1/safety/contacts/',
               '/api/v1/admin/pricing/', '/api/v1/admin/audit/', '/api/v1/admin/users/', '/api/v1/admin/tickets/', '/api/v1/admin/overview/', '/api/v1/notifications/devices/']
    excluded = ['/api/v1/rides/{pk}/accept/', '/api/v1/rides/{pk}/arriving/', '/api/v1/rides/{pk}/events/', '/api/v1/admin/vehicles/{pk}/review/']
    return [(path, regex, method, callback) for path, regex, method, callback in endpoints
            if path.startswith('/api/v1/') and not any(path.startswith(a) for a in aliases) and path not in excluded and not (path == '/api/v1/rides/{pk}/status/' and method == 'POST')]


def contract(view, method, path):
    from accounts.api import passwords as password_api, views as a
    from drivers.api import views as d, resources as dr
    from rides.api import views as r, resources as rr
    from notifications.api import views as n
    from payments.api import views as p
    from core import admin_api as ad, admin_resources as ar
    from accounts.api.resources import SavedPlaceSerializer, ContactSerializer, AvatarView, AvatarUploadSerializer
    from drivers.api.serializers import ApplicationSerializer, LocationSerializer
    from rides.api.serializers import BookingRequestSerializer, QuoteRequestSerializer, RideSerializer, PlaceSerializer
    def result(response, request=None, status=200, alternatives=()):
        responses = {status: response}
        responses.update({code: response for code in alternatives})
        return request, responses
    cls = type(view)
    maps = {
        password_api.StaffLoginView: {'POST': result(c.TokensSerializer, password_api.StaffLoginSerializer)},
        password_api.PasswordLoginView: {'POST': result(c.TokensSerializer, password_api.LoginSerializer)},
        password_api.RecoveryRequestView: {'POST': result(c.DetailSerializer, password_api.PasswordContactSerializer, 202)},
        password_api.RecoveryVerifyView: {'POST': result(password_api.RecoveryTokenSerializer, password_api.RecoveryVerificationSerializer)},
        password_api.RecoveryResetView: {'POST': result(None, password_api.ResetSerializer, 204)},
        a.OTPRequestView: {'POST': result(c.DetailSerializer, a.PhoneSerializer, 202)},
        a.OTPVerifyView: {'POST': result(c.TokensSerializer, a.CodeSerializer)},
        a.MeView: {'GET': result(c.ProfileSerializer), 'POST': result(c.ProfileSerializer, a.ProfileSerializer), 'PATCH': result(c.ProfileSerializer, a.ProfileSerializer)},
        a.RefreshView: {'POST': result(c.TokenPairSerializer, c.RefreshRequestSerializer)},
        a.LogoutView: {'POST': result(None, c.LogoutSerializer, 204)},
        d.ApplicationView: {'GET': result(PolymorphicProxySerializer(component_name='ApplicationState', serializers=[ApplicationSerializer, c.StatusSerializer], resource_type_field_name=None)), 'POST': result(ApplicationSerializer, ApplicationSerializer), 'PATCH': result(ApplicationSerializer, ApplicationSerializer)},
        d.SubmitView: {'POST': result(ApplicationSerializer)},
        d.DocumentView: {'POST': result(type('UploadedDocumentSerializer',(s.Serializer,),{'id':__import__('core.identifiers', fromlist=['ObjectIdSerializerField']).ObjectIdSerializerField(),'requirement':s.SlugField()}), dr.VehicleDocumentUploadSerializer, 201), 'GET': result(c.collection('DriverDocumentPage', dr.DocumentSerializer, paginated=True))},
        d.DocumentDownloadView: {'GET': (None, {(200, 'image/jpeg'): OpenApiTypes.BINARY, (200, 'image/png'): OpenApiTypes.BINARY})},
        dr.DocumentDeleteView: {'GET': (None, {(200, 'image/jpeg'): OpenApiTypes.BINARY, (200, 'image/png'): OpenApiTypes.BINARY}), 'DELETE': result(None, status=204)},
        d.RequirementsView: {'GET': result(c.collection('Requirements', c.RequirementSerializer))},
        d.AvailabilityView: {'POST': result(c.StatusSerializer, c.OnlineSerializer if 'availability' in path else None)},
        d.LocationView: {'POST': result(c.LastSeenSerializer, LocationSerializer)},
        d.ReviewView: {'POST': result(ApplicationSerializer, c.ReviewSerializer)},
        r.OfferUpdateView: {'PATCH': result(c.OfferUpdatedSerializer, r.OfferPatchSerializer)},
        r.RideSyncView: {'GET': result(c.RideSyncSerializer)},
        r.DriverRequestDeclineView: {'POST': result(c.DriverDeclineSerializer)},
        r.QuoteView: {'POST': result(c.QuoteSerializer, QuoteRequestSerializer, 201)},
        r.RideListCreateView: {'GET': result(c.collection('RidePage', RideSerializer, paginated=True)), 'POST': result(RideSerializer, BookingRequestSerializer, 201, (200,))},
        r.RideDetailView: {'GET': result(RideSerializer)}, r.ActiveRideView: {'GET': result(c.ActiveRideSerializer)},
        r.OffersView: {'GET': result(c.collection('AvailableOffers', c.OfferSerializer)), 'POST': result(c.OfferCreatedSerializer, r.OfferSerializer, 201)},
        r.RideStatusView: {'GET': result(c.RideStatusSerializer), 'POST': result(RideSerializer, c.StateCommandSerializer if path.endswith('/status/') else c.OptionalReasonSerializer)},
        r.RideAcceptView: {'POST': result(RideSerializer, c.SelectionSerializer)}, r.WithdrawView: {'POST': result(c.StatusSerializer)},
        r.PlacesView: {'GET': result(c.collection('Places', PlaceSerializer))},
        r.DriverRequestsView: {'GET': result(c.collection('DriverRequestPage', RideSerializer, paginated=True))},
        r.DriverTripsView: {'GET': result(c.collection('DriverTripPage', RideSerializer, paginated=True))},
        r.EarningsView: {'GET': result(c.EarningsSerializer)}, r.EventsView: {'GET': result(c.EventsSerializer)},
        r.RatingView: {'POST': result(c.RatingCreatedSerializer, c.RatingRequestSerializer, 201, (200,))},
        r.ServiceAreasView: {'GET': result(c.collection('ServiceAreas', rr.ServiceAreaSerializer))},
        r.SavedPlacesView: {'GET': result(c.collection('LegacySavedPlaces', SavedPlaceSerializer)), 'POST': result(c.IdentifierSerializer, SavedPlaceSerializer, 201)},
        r.EmergencyContactsView: {'GET': result(c.collection('LegacyContacts', ContactSerializer)), 'POST': result(c.IdentifierSerializer, ContactSerializer, 201), 'DELETE': result(None, c.IdentifierSerializer, 204)},
        r.TripShareView: {'POST': result(c.ShareSerializer, c.ShareRequestSerializer, 201)},
        r.SharedTripView: {'GET': result(c.SharedTripSerializer), 'DELETE': result(None, status=204)},
        rr.RideReadView: {'GET': result({'tracking': c.TrackingSerializer, 'receipt': c.ReceiptSerializer}.get(view.mode, c.RideStatusSerializer))} if cls == rr.RideReadView else {},
        rr.CurrentDriverTripView: {'GET': result(c.ActiveRideSerializer)}, rr.RequestDetailView: {'GET': result(RideSerializer)},
        rr.OfferDetailView: {'GET': result(c.OfferSerializer), 'PATCH': result(c.OfferUpdatedSerializer, r.OfferPatchSerializer)}, rr.ReportView: {'POST': result(rr.TicketSerializer, c.MessageSerializer, 201)},
        rr.EarningsSummaryView: {'GET': result(c.EarningsSummarySerializer)},
        rr.CategoriesView: {'GET': result(rr.CategorySerializer if '{' in path else c.collection('Categories', rr.CategorySerializer))},
        rr.ReverseGeocodeView: {'GET': result(PlaceSerializer)}, rr.RouteEstimateView: {'POST': result(c.RouteSerializer, QuoteRequestSerializer)},
        dr.DriverProfileView: {'GET': result(ApplicationSerializer), 'PATCH': result(ApplicationSerializer, ApplicationSerializer)},
        dr.StatisticsView: {'GET': result(c.StatisticsSerializer)}, dr.AvailabilityDetailView: {'GET': result(c.AvailabilitySerializer)},
        dr.VehicleDocumentsView: {'GET': result(c.collection('VehicleDocumentPage', dr.VehicleDocumentSerializer, paginated=True)), 'POST': result(dr.VehicleDocumentSerializer, dr.VehicleDocumentUploadSerializer, 201)},
        dr.VehicleDocumentDetailView: {'GET': (None, {(200, 'image/jpeg'): OpenApiTypes.BINARY, (200, 'image/png'): OpenApiTypes.BINARY}), 'DELETE': result(None, status=204)},
        AvatarView: {'GET': (None, {(200, 'application/octet-stream'): OpenApiTypes.BINARY}), 'POST': result(None, AvatarUploadSerializer, 204), 'DELETE': result(None, status=204)},
        n.NotificationsView: {'GET': result(c.collection('NotificationPage', c.NotificationSerializer, paginated=True))},
        n.ReadView: {'POST': result(c.ReadSerializer)}, n.UnreadCountView: {'GET': result(c.CountSerializer)}, n.MarkAllReadView: {'POST': result(c.UpdatedSerializer)},
        n.DeviceView: {'POST': result(None, c.DeviceRequestSerializer, 204), 'DELETE': result(None, c.TokenDeleteSerializer, 204)},
        n.DeviceRegisterView: {'POST': result(c.DeviceSerializer, c.DeviceRequestSerializer, 201)}, n.DeviceDeleteView: {'DELETE': result(None, status=204)},
        p.MethodsView: {'GET': result(c.collection('PaymentMethods', c.PaymentMethodSerializer, key='items'))},
        p.CurrenciesView: {'GET': result(c.CurrenciesSerializer)}, p.PaymentHistoryView: {'GET': result(c.collection('PaymentHistory', c.PaymentHistoryRowSerializer, key='items'))},
        ad.OverviewView: {'GET': result(c.OverviewSerializer)}, ad.AdminCancelView: {'POST': result(RideSerializer, c.ReasonSerializer)},
        ad.AccountStatusView: {'POST': result(c.ActiveSerializer, c.ActiveSerializer)}, ad.VehicleReviewView: {'POST': result(c.ApprovedSerializer, c.ApprovedSerializer)},
        ar.AdminTimelineView: {'GET': result(c.collection('AdminTimelinePage', c.TimelineEventSerializer, paginated=True))},
    }
    if cls == ar.AnalyticsView:
        response = c.collection('DriverAnalytics', c.DriverAnalyticsRowSerializer) if view.kind == 'driver-analytics' else c.collection('PlatformActivity', ad.AuditSerializer, paginated=True) if view.kind == 'platform-activity' else c.collection('RideAnalytics', c.RideAnalyticsRowSerializer, paginated=True, extra={'payment_receipt_verified': s.BooleanField()})
        return result(response)
    if cls == ar.ReportsView:
        child = ApplicationSerializer if view.kind == 'drivers' else ad.UserSerializer if view.kind == 'passengers' else RideSerializer
        return result(c.collection('Report'+view.kind.title(), child, paginated=True))
    action = getattr(view, 'action', None)
    if action in ['suspend', 'reactivate', 'approve', 'reject', 'request_changes', 'activate', 'resolve']:
        request = c.ReasonSerializer if action in ['suspend', 'reject', 'request_changes', 'resolve'] else None
        return result(view.serializer_class, request)
    return maps.get(cls, {}).get(method)


class TriviaAutoSchema(AutoSchema):
    def get_request_serializer(self):
        value = contract(self.view, self.method, self.path)
        return value[0] if value else super().get_request_serializer()

    def get_response_serializers(self):
        value = contract(self.view, self.method, self.path)
        responses = value[1].copy() if value else super().get_response_serializers()
        if not isinstance(responses, dict):
            # Preserve generic viewset automatic list/create status handling.
            status = 201 if self.method == 'POST' and getattr(self.view, 'action', None) == 'create' else 204 if self.method == 'DELETE' else 200
            responses = {status: None if status == 204 else responses}
        for status in [400, 401, 403, 404, 409, 429, 503]:
            responses[status] = OpenApiResponse(c.ErrorSerializer, description={400:'Validation failed',401:'JWT missing, invalid, expired or revoked',403:'Role or ownership permission denied',404:'Resource not visible or not found',409:'State/quote conflict',429:'Rate limit or cooldown',503:'Configured provider or infrastructure unavailable'}[status])
        return responses

    def get_tags(self):
        p = self.path
        if '/auth/' in p:
            return ['Authentication']
        if '/admin/' in p:
            if '/reports/' in p:
                return ['Admin Reports']
            for needle, tag in [('dashboard','Admin Dashboard'),('driver-applications','Admin Verification'),('drivers','Admin Drivers'),('pricing','Admin Pricing'),('service-areas','Platform Configuration'),('reports','Admin Reports'),('rides','Admin Rides'),('vehicles','Verification'),('disputes','Support'),('audit','Administration')]:
                if needle in p:
                    return [tag]
            return ['Administration']
        for needle, tag in [('vehicles','Vehicles'),('applications','Driver Applications'),('verification','Verification'),('locations','Locations'),('places','Locations'),('routes','Routes'),('fares','Pricing'),('ride-categories','Pricing'),('service-areas','Locations'),('earnings','Earnings'),('ratings','Ratings'),('offers','Offers'),('tracking','Tracking'),('timeline','Trips'),('receipt','Trips'),('trips','Trips'),('notifications','Notifications'),('devices','Notifications'),('safety','Safety'),('emergency-contacts','Safety'),('share','Safety'),('support','Support'),('report','Safety'),('drivers','Drivers'),('rides','Rides')]:
            if needle in p:
                return [tag]
        return ['Accounts']

    def get_operation_id(self):
        import re
        return re.sub(r'[^a-zA-Z0-9]+', '_', self.path.strip('/') + '_' + self.method.lower()).strip('_')

    def get_summary(self):
        auth_summaries = {
            '/api/v1/admin/auth/login/': 'Staff API password login',
            '/api/v1/auth/login/': 'Passenger or driver password login',
            '/api/v1/auth/otp/request/': 'Request OTP for registration or sign-in',
            '/api/v1/auth/otp/verify/': 'Verify OTP and register or sign in',
            '/api/v1/auth/token/refresh/': 'Refresh and rotate JWT tokens',
            '/api/v1/auth/logout/': 'Log out and revoke sessions',
            '/api/v1/auth/me/': 'Get current user',
            '/api/v1/auth/password/request/': 'Request password recovery',
            '/api/v1/auth/password/verify/': 'Verify recovery code',
            '/api/v1/auth/password/reset/': 'Reset password',
        }
        if self.path in auth_summaries:
            return auth_summaries[self.path]
        summaries = {
            ('GET', '/api/v1/rides/'): 'List rides visible to the account',
            ('POST', '/api/v1/rides/'): 'Request a ride',
            ('POST', '/api/v1/fares/estimate/'): 'Estimate a route and fare',
            ('GET', '/api/v1/locations/search/'): 'Search for pickup or destination places',
            ('GET', '/api/v1/notifications/'): 'List account notifications',
            ('GET', '/api/v1/users/me/'): 'Get account profile',
            ('PATCH', '/api/v1/users/me/'): 'Update account profile',
            ('GET', '/api/v1/admin/dashboard/overview/'): 'View platform activity totals',
        }
        if (self.method, self.path) in summaries:
            return summaries[self.method, self.path]
        tail = self.path.removeprefix('/api/v1/').replace('{','').replace('}','').strip('/').replace('/', ' · ').replace('-', ' ')
        return f'{self.method.title()} {tail}'

    def get_description(self):
        descriptions = {
            '/api/v1/auth/login/': 'Passenger and driver password login. Supply a verified phone number or unique account email and the account password. The server returns the current driver approval status.',
            '/api/v1/admin/auth/login/': 'Staff API login using a Django username, unique email, or verified phone and password. Only active staff receive tokens. Each admin action still checks its Django permission.',
            '/api/v1/auth/otp/request/': 'Request a phone verification code for passenger or driver sign-in and registration. Delivery requires a configured SMS provider.',
            '/api/v1/auth/otp/verify/': 'Verify the phone code. First-time verification creates the passenger account. Driver application and approval use the separate Driver Applications operations.',
            '/api/v1/auth/otp/resend/': 'Request another code after the server cooldown.',
            '/api/v1/auth/token/refresh/': 'Submit the refresh token from sign-in. Store the new access and refresh tokens returned by rotation.',
            '/api/v1/auth/logout/': 'Requires an access token. Revokes all phone-account sessions or the current staff API session.',
            '/api/v1/auth/logout-all/': 'Alias of logout. For staff API tokens it revokes the current staff API session.',
            '/api/v1/auth/me/': 'Return the authenticated account profile and current driver approval status.',
            '/api/v1/auth/password/request/': 'Request recovery on an enabled channel. A generic 202 does not confirm account existence. Phone delivery needs SMS configuration; email requires a verified ownership binding.',
            '/api/v1/auth/password/verify/': 'Exchange the delivered one-time code for a short-lived password reset token.',
            '/api/v1/auth/password/reset/': 'Set a validated new password using the reset token. Existing phone-account sessions are revoked.',
        }
        permission = descriptions.get(self.path)
        if permission is None:
            if '/admin/' in self.path:
                permission = 'Requires an active staff administrator with the Django permission for the action.'
            else:
                permission = 'Requires Bearer JWT authentication and applicable ownership or role permissions.'
        text = super().get_description() or self.get_summary() + '.'
        if '/rides/' in self.path:
            text += ' Ride commands validate participant ownership, driver eligibility and authoritative state inside transactions. Direct-payment preferences are Cash, EcoCash and OneMoney in USD; Trivia does not collect or verify funds.'
        return text + '\n\n' + permission

    def get_override_parameters(self):
        params = super().get_override_parameters()
        from rides.api import views as r, resources as rr
        from notifications.api.views import NotificationsView
        if isinstance(self.view, (r.PlacesView,)):
            params += [OpenApiParameter('q', str, description='Address/place search, at most 200 characters.')]
        if isinstance(self.view, rr.ReverseGeocodeView):
            params += [OpenApiParameter('latitude', float, required=True, description='Latitude −90 to 90.'), OpenApiParameter('longitude', float, required=True, description='Longitude −180 to 180.')]
        if isinstance(self.view, r.EventsView):
            params += [OpenApiParameter('after', int, description='Exclusive event sequence cursor; at most 200 events per request.')]
        if isinstance(self.view, r.EarningsView):
            params += [OpenApiParameter('period', str, enum=['all','day','week','month'], description='Africa/Harare calendar period.')]
        if isinstance(self.view, (r.RideListCreateView, r.DriverRequestsView, r.DriverTripsView, NotificationsView)) and self.method == 'GET':
            params += [OpenApiParameter('page', int, description='Page number; 50 items per page.')]
        if isinstance(self.view, r.RideListCreateView) and self.method == 'GET':
            params += [OpenApiParameter(n, str, description='Validated ride filter.') for n in ['status','category','service_area','created_after','created_before']]
        if isinstance(self.view, NotificationsView):
            params += [OpenApiParameter('unread', bool, description='Filter unread/read notifications.'), OpenApiParameter('type', str, description='Event type filter.'), OpenApiParameter('created_after', str, description='Inclusive ISO timestamp.'), OpenApiParameter('created_before', str, description='Inclusive ISO timestamp.')]
        return params


def annotate():
    # Compatibility entry point retained for existing URL configuration imports.
    pass


def examples_hook(result, generator, request, public):
    """Illustrative examples follow the resolved schema; never credentials/live data."""
    field_descriptions = {
        'LoginRequest': {
            'identifier': 'Verified international phone number or unique account email, matching channel.',
            'password': 'Existing account password. Leading and trailing spaces are significant.',
        },
        'StaffLoginRequest': {
            'identifier': 'Django username, unique email, or verified international phone number, matching channel.',
            'password': 'Existing Django staff account password.',
        },
        'PhoneRequest': {'phone': 'Phone number in international format, including country code.'},
        'CodeRequest': {'code': 'Six-digit code from the verification message.'},
        'RefreshRequestRequest': {'refresh': 'Refresh token returned by login or the latest successful rotation.'},
        'ResetRequest': {
            'token': 'Short-lived reset proof returned after successful recovery verification.',
            'password': 'New account password. Django password validation applies.',
        },
    }
    for component, fields in field_descriptions.items():
        properties = result['components']['schemas'].get(component, {}).get('properties', {})
        for name, description in fields.items():
            if name in properties:
                properties[name].setdefault('description', description)

    auth_examples = {
        '/api/v1/auth/login/': {'channel': 'email', 'identifier': 'passenger@example.test', 'password': '<account password>'},
        '/api/v1/admin/auth/login/': {'channel': 'email', 'identifier': 'staff@example.test', 'password': '<staff password>'},
        '/api/v1/auth/password/request/': {'channel': 'email', 'identifier': 'passenger@example.test'},
        '/api/v1/auth/password/verify/': {'channel': 'phone', 'identifier': '+263771234567', 'code': '000000'},
        '/api/v1/auth/password/reset/': {'token': '<reset proof from verification>', 'password': '<new password>'},
        '/api/v1/auth/otp/verify/': {'phone': '+263771234567', 'code': '000000'},
    }

    def sample(schema, depth=0, name=""):
        if schema.get('pattern') == '^[0-9a-fA-F]{24}$':
            return '000000000000000000000001'
        if name == 'pickup':
            return {'name': 'Harare CBD', 'latitude': -17.8292, 'longitude': 31.0522}
        if name == 'destination':
            return {'name': 'Borrowdale', 'latitude': -17.765, 'longitude': 31.08}
        if depth > 12:
            return None
        if '$ref' in schema:
            value = result
            for part in schema['$ref'].removeprefix('#/').split('/'):
                value = value.get(part, {})
            return sample(value, depth+1, name)
        for choice in ['oneOf', 'anyOf', 'allOf']:
            if schema.get(choice):
                return sample(schema[choice][0], depth+1, name)
        if 'enum' in schema:
            return schema['enum'][0]
        if schema.get('nullable'):
            return None
        kind = schema.get('type')
        if kind == 'object' or 'properties' in schema:
            return {field: sample(value, depth+1, field) for field, value in schema.get('properties', {}).items()}
        if kind == 'array':
            return [sample(schema.get('items', {}), depth+1)]
        if kind == 'boolean':
            return False
        if kind in ['integer', 'number']:
            return schema.get('minimum', 1)
        values = {'phone': '+263771234567', 'code': '000000', 'first_name': 'Test', 'last_name': 'Passenger', 'name': 'Harare CBD',
                  'fare_cents': 800, 'payment_method_id': 'ecocash', 'payment_preference': 'ecocash', 'note': 'Please call at the entrance.',
                  'passenger_note': 'Please call at the entrance.', 'registration': 'TEST123', 'category': 'Standard',
                  'status': 'searching', 'reason': 'Illustrative review reason', 'decision': 'counteroffer',
                  'licence_expires': '2027-11-16', 'expires_on': '2027-11-16', 'requirement': 'configured-licence',
                  'access': '<access-token-from-sign-in>', 'refresh': '<refresh-token-from-sign-in>',
                  'latitude': '-17.829200', 'longitude': '31.052200', 'agreed_fare': '8.00', 'amount': '8.00', 'suggested_fare': '8.00'}
        if name in values:
            return values[name]
        fmt = schema.get('format')
        return {'uuid': '00000000-0000-4000-8000-000000000001', 'date-time': '2026-11-16T08:00:00Z', 'date': '2026-11-16', 'email': 'developer@example.test', 'uri': 'https://example.test/api/v1/', 'decimal':'8.00', 'double':8.0, 'float':8.0, 'binary':'<multipart file>'}.get(fmt, 'example')
    aliases = {
        ('/api/v1/auth/otp/resend/', 'post'): 'POST /api/v1/auth/otp/request/',
        ('/api/v1/auth/logout-all/', 'post'): 'POST /api/v1/auth/logout/',
        ('/api/v1/users/me/', 'get'): 'GET /api/v1/auth/me/',
        ('/api/v1/users/me/', 'post'): 'PATCH /api/v1/users/me/',
        ('/api/v1/drivers/me/', 'get'): 'GET /api/v1/drivers/applications/me/',
        ('/api/v1/drivers/me/status/', 'get'): 'GET /api/v1/drivers/applications/me/',
        ('/api/v1/drivers/me/verification-status/', 'get'): 'GET /api/v1/drivers/applications/me/',
        ('/api/v1/drivers/applications/me/', 'post'): 'POST /api/v1/drivers/applications/',
        ('/api/v1/drivers/me/ratings/', 'get'): 'GET /api/v1/users/me/ratings/',
        ('/api/v1/places/', 'get'): 'GET /api/v1/locations/search/',
        ('/api/v1/routes/quote/', 'post'): 'POST /api/v1/fares/estimate/',
    }
    for path, methods in result['paths'].items():
        for method, operation in methods.items():
            if not isinstance(operation, dict) or method not in ['get','post','patch','put','delete']:
                continue
            if (path, method) in aliases:
                operation['x-alias-of'] = aliases[(path, method)]
                operation['description'] += '\n\nAlias of ' + aliases[(path, method)] + '; excluded from distinct-operation totals.'
            for media in operation.get('requestBody', {}).get('content', {}).values():
                value = auth_examples[path] if path in auth_examples else sample(media.get('schema', {}))
                if path == '/api/v1/rides/' and method == 'post' and isinstance(value, dict):
                    value['payment_method_id'] = 'cash-usd'
                media.setdefault('examples', {'illustrative': {'summary': 'Illustrative input. Replace placeholders before sending.', 'value': value}})
            for status, response in operation.get('responses', {}).items():
                for media_type, media in response.get('content', {}).items():
                    if media_type != 'application/json':
                        continue
                    value = sample(media.get('schema', {}))
                    if status.startswith(('4','5')):
                        value = {'errors': {'detail': 'Request could not be completed.'}, 'code': {'400': 'INVALID', '401': 'NOT_AUTHENTICATED', '403': 'PERMISSION_DENIED', '404': 'NOT_FOUND', '409': 'QUOTE_EXPIRED', '429': 'THROTTLED', '503': 'ROUTE_UNAVAILABLE'}.get(status, 'ERROR'), 'field_codes': {'detail': 'invalid'}, 'request_id': 'example-correlation-id'}
                    if status == '401' and path in ('/api/v1/auth/login/', '/api/v1/admin/auth/login/'):
                        value.update(
                            errors={'detail': 'The account details or password are incorrect.'},
                            code='INVALID_CREDENTIALS',
                            field_codes={'detail': 'invalid_credentials'},
                        )
                    media.setdefault('examples', {'illustrative': {'summary': 'Illustrative response', 'value': value}})
            for parameter in operation.get('parameters', []):
                if parameter.get('in') == 'path':
                    parameter.setdefault('description', 'Identifier of the resource; ownership and role restrictions apply.')
    return result

from datetime import timedelta
from io import BytesIO
from tempfile import TemporaryDirectory
from unittest.mock import patch
from PIL import Image
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, SimpleTestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from accounts.models import AuditEvent, UserPreferences
from drivers.models import DriverApplication, Vehicle, DriverDocument, VehicleDocument, DocumentRequirement, PrivateStorage
from notifications.models import Notification, DeviceToken
from notifications.services.events import notify
from rides.models import SavedPlace, SupportTicket, PricingZone, ActiveAssignment
from rides.services.lifecycle import make_offer, select_offer, transition
from .helpers import RideFixtures, ROAD


class ResourceTests(RideFixtures, TestCase):
    def setUp(self):
        cache.clear()
        self.setup_ride()
        self.admin = get_user_model().objects.create_superuser(username='rest-admin', email='test@example.test', password='test')
        self.client = APIClient()
        self.client.force_authenticate(self.passenger)

    def test_preferences_and_saved_place_crud_are_owned_and_paginated(self):
        endpoint = '/api/v1/users/me/preferences/'
        self.assertEqual(self.client.get(endpoint).data['language'], 'en')
        self.assertEqual(self.client.patch(endpoint, {'language': 'sn', 'push_notifications': False}).status_code, 200)
        self.assertEqual(self.client.patch(endpoint, {'language': 'invalid'}).status_code, 400)
        url = '/api/v1/users/me/saved-places/'
        response = self.client.post(url, {'label': 'Home', 'place': self.pickup}, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        pk = response.data['id']
        self.assertEqual(self.client.get(url).data['count'], 1)
        self.assertEqual(self.client.patch(f'{url}{pk}/', {'label': 'Work'}).status_code, 200)
        self.client.force_authenticate(self.other_user)
        self.assertEqual(self.client.get(f'{url}{pk}/').status_code, 404)
        self.assertEqual(self.client.delete(f'{url}{pk}/').status_code, 404)
        self.client.force_authenticate(self.passenger)
        self.assertEqual(self.client.delete(f'{url}{pk}/').status_code, 204)

    def test_private_avatar_and_upload_validation(self):
        from accounts.models import UserPreferences
        field = UserPreferences._meta.get_field('avatar')
        image = BytesIO()
        Image.new('RGB', (4, 4)).save(image, 'PNG')
        with TemporaryDirectory() as directory, override_settings(PRIVATE_MEDIA_ROOT=directory):
            old = field.storage
            field.storage = PrivateStorage()
            try:
                self.assertEqual(self.client.post('/api/v1/users/me/avatar/', {'file': SimpleUploadedFile('x.png', image.getvalue())}).status_code, 204)
                response = self.client.get('/api/v1/users/me/avatar/')
                self.assertEqual(response.status_code, 200)
                # Streaming completion must not close TestCase's outer MySQL transaction.
                with patch('django.http.response.signals.request_finished.send'):
                    self.assertEqual(b''.join(response.streaming_content), image.getvalue())
                self.client.force_authenticate(self.other_user)
                self.assertEqual(self.client.get('/api/v1/users/me/avatar/').status_code, 404)
                self.client.force_authenticate(self.passenger)
                self.assertEqual(self.client.post('/api/v1/users/me/avatar/', {'file': SimpleUploadedFile('bad.png', b'bad')}).status_code, 400)
                self.assertEqual(self.client.delete('/api/v1/users/me/avatar/').status_code, 204)
            finally:
                field.storage = old

    def test_fleet_approval_activation_and_archive(self):
        self.client.force_authenticate(self.driver_user)
        url = '/api/v1/drivers/me/vehicles/'
        data = {'make': 'Test', 'model': 'Second', 'year': 2022, 'colour': 'blue', 'registration': 'FLEET-2', 'capacity': 4, 'category': 'Comfort'}
        created = self.client.post(url, data)
        self.assertEqual(created.status_code, 201, created.data)
        pk = created.data['id']
        self.assertFalse(created.data['approved'])
        self.assertEqual(self.client.post(f'{url}{pk}/activate/').status_code, 403)
        self.client.force_authenticate(self.admin)
        self.assertEqual(self.client.post(f'/api/v1/admin/vehicles/{pk}/approve/').status_code, 200)
        self.client.force_authenticate(self.driver_user)
        self.assertEqual(self.client.post(f'{url}{pk}/activate/').status_code, 200)
        self.driver.refresh_from_db()
        self.assertEqual(str(self.driver.vehicle.pk), str(pk))
        self.assertEqual(self.driver.availability, 'offline')
        self.assertEqual(self.client.patch(f'{url}{pk}/', {'colour': 'red'}).status_code, 200)
        self.assertFalse(Vehicle.objects.get(pk=pk).approved)
        self.assertEqual(self.client.delete(f'{url}{pk}/').status_code, 204)
        self.assertTrue(Vehicle.objects.get(pk=pk).archived)
        self.assertEqual(self.client.get(f'{url}{pk}/').status_code, 404)

    def test_assigned_vehicle_cannot_change_or_be_removed(self):
        offer = make_offer(self.driver_user, self.ride.pk, 600)
        select_offer(self.passenger, self.ride.pk, offer.pk)
        self.client.force_authenticate(self.driver_user)
        pk = self.driver.vehicle.pk
        self.assertEqual(self.client.patch(f'/api/v1/drivers/me/vehicles/{pk}/', {'colour': 'black'}).status_code, 400)
        self.assertEqual(self.client.delete(f'/api/v1/drivers/me/vehicles/{pk}/').status_code, 400)
        self.assertTrue(ActiveAssignment.objects.exists())

    def test_offer_vehicle_cannot_silently_switch_at_selection(self):
        offer = make_offer(self.driver_user, self.ride.pk, 600)
        new_vehicle = Vehicle.objects.create(application=self.driver, make='Test', model='Other', year=2020, colour='blue', registration='SWITCH', capacity=4, category='Standard', approved=True)
        self.driver.active_vehicle = new_vehicle
        self.driver.save(update_fields=['active_vehicle'])
        response = self.client.post(f'/api/v1/rides/{self.ride.pk}/select-offer/', {'offer_id': offer.pk})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['code'], 'VEHICLE_NOT_APPROVED')
        self.assertFalse(ActiveAssignment.objects.exists())

    def test_status_tracking_receipt_and_read_ownership(self):
        offer = make_offer(self.driver_user, self.ride.pk, 600)
        self.assertEqual(self.client.get(f'/api/v1/offers/{offer.pk}/').status_code, 200)
        select_offer(self.passenger, self.ride.pk, offer.pk)
        self.assertEqual(self.client.get(f'/api/v1/rides/{self.ride.pk}/status/').data['status'], 'assigned')
        self.assertEqual(self.client.get(f'/api/v1/rides/{self.ride.pk}/tracking/').status_code, 200)
        self.assertEqual(self.client.get(f'/api/v1/rides/{self.ride.pk}/receipt/').status_code, 400)
        for state in ['arriving', 'arrived', 'inProgress', 'completed']:
            transition(self.driver_user, self.ride.pk, state)
        receipt = self.client.get(f'/api/v1/rides/{self.ride.pk}/receipt/').data
        self.assertEqual(receipt['agreed_fare'], '6.00')
        self.assertFalse(receipt['payment_receipt_verified'])
        self.assertFalse(receipt['platform_processed_payment'])
        self.assertEqual(self.client.get('/api/v1/users/me/trips/?status=completed').data['count'], 1)
        self.assertEqual(self.client.get(f'/api/v1/rides/{self.ride.pk}/timeline/').data['sequence'], self.ride.events.count())
        self.client.force_authenticate(self.other_user)
        for resource in ['status','tracking','receipt','timeline']:
            self.assertEqual(self.client.get(f'/api/v1/rides/{self.ride.pk}/{resource}/').status_code, 404)
        self.assertEqual(self.client.get(f'/api/v1/offers/{offer.pk}/').status_code, 404)

    def test_notifications_filters_devices_and_bulk_read(self):
        notify(self.passenger.pk, 'ride.created', str(self.ride.pk), {'status': 'searching'})
        notify(self.other_user.pk, 'private', '1', {})
        self.assertGreaterEqual(self.client.get('/api/v1/notifications/unread-count/').data['count'], 1)
        result = self.client.get('/api/v1/notifications/?unread=true&type=ride.created')
        self.assertGreaterEqual(result.data['count'], 1)
        self.assertEqual(self.client.post('/api/v1/notifications/mark-all-read/').status_code, 200)
        self.assertEqual(self.client.get('/api/v1/notifications/unread-count/').data['count'], 0)
        device = self.client.post('/api/v1/devices/register/', {'token': 'test-device-token', 'platform': 'android'})
        self.assertEqual(device.status_code, 201)
        pk = device.data['id']
        self.client.force_authenticate(self.other_user)
        self.assertEqual(self.client.delete(f'/api/v1/devices/{pk}/').status_code, 404)
        self.client.force_authenticate(self.passenger)
        self.assertEqual(self.client.delete(f'/api/v1/devices/{pk}/').status_code, 204)

    def test_support_contacts_and_privacy_preference(self):
        response = self.client.post('/api/v1/support/tickets/', {'ride_id': str(self.ride.pk), 'category': 'support', 'message': 'Test help'})
        self.assertEqual(response.status_code, 201, response.data)
        pk = response.data['id']
        self.assertEqual(self.client.get('/api/v1/support/tickets/?status=open').data['count'], 1)
        self.assertEqual(self.client.get(f'/api/v1/support/tickets/{pk}/').status_code, 200)
        contact = self.client.post('/api/v1/users/me/emergency-contacts/', {'name': 'Test contact', 'phone': '0771234567'})
        self.assertEqual(contact.status_code, 201)
        contact_id = contact.data['id']
        self.assertEqual(self.client.patch(f'/api/v1/users/me/emergency-contacts/{contact_id}/', {'name': 'Updated'}).status_code, 200)
        self.client.force_authenticate(self.other_user)
        self.assertEqual(self.client.get(f'/api/v1/support/tickets/{pk}/').status_code, 404)
        self.assertEqual(self.client.delete(f'/api/v1/users/me/emergency-contacts/{contact_id}/').status_code, 404)
        self.client.force_authenticate(self.passenger)
        self.client.patch('/api/v1/users/me/preferences/', {'allow_trip_sharing': False})
        self.assertEqual(self.client.post(f'/api/v1/rides/{self.ride.pk}/share/', {'recipient_id': self.other_user.pk}).status_code, 403)
        self.assertEqual(self.client.delete(f'/api/v1/users/me/emergency-contacts/{contact_id}/').status_code, 204)

    @override_settings(TRIVIA_ROUTING_URL='', TRIVIA_GEOAPIFY_API_KEY='test-key')
    def test_fare_estimate_uses_geoapify_route_and_pricing_minimum(self):
        self.pricing.minimum_offer_usd = 10
        self.pricing.save(update_fields=['minimum_offer_usd'])
        geometry = [[31.05, -17.82], [31.04, -17.81], [31.03, -17.80]]
        payload = {'features': [{
            'properties': {'distance': 5800, 'time': 720},
            'geometry': {'type': 'MultiLineString', 'coordinates': [geometry]},
        }]}
        with patch('rides.services.routing.provider_json', return_value=payload):
            response = self.client.post('/api/v1/fares/estimate/', {
                'pickup': self.pickup, 'destination': self.destination,
                'category': 'Standard', 'currency': 'USD',
            }, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['routing_provider'], 'Geoapify')
        self.assertEqual(response.data['geometry'], geometry)
        self.assertEqual(response.data['distance_km'], '5.8')
        self.assertEqual(response.data['estimated_minutes'], '12')
        self.assertEqual(response.data['currency'], 'USD')
        self.assertEqual(response.data['suggested_fare_cents'], 1000)
        self.assertEqual(response.data['minimum_fare_cents'], 1000)

    def test_maps_categories_and_request_detail(self):
        with patch('rides.services.routing.driving_route', return_value=ROAD):
            response = self.client.post('/api/v1/routes/estimate/', {'pickup': self.pickup, 'destination': self.destination, 'category': 'Standard'}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['distance_metres'], 5800)
        with patch('rides.services.routing.provider_json', return_value={'display_name': 'Test place', 'lat': '-17.82', 'lon': '31.05'}), override_settings(TRIVIA_GEOCODING_URL='https://example.test'):
            response = self.client.get('/api/v1/locations/reverse-geocode/?latitude=-17.82&longitude=31.05')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(self.client.get('/api/v1/locations/reverse-geocode/?latitude=1000&longitude=31').status_code, 400)
        self.assertEqual(self.client.get('/api/v1/ride-categories/Standard/').status_code, 200)
        self.assertEqual(self.client.get(f'/api/v1/service-areas/{self.zone.pk}/').status_code, 200)
        self.client.force_authenticate(self.driver_user)
        self.assertEqual(self.client.get(f'/api/v1/drivers/me/requests/{self.ride.pk}/').status_code, 200)
        self.assertEqual(self.client.get('/api/v1/drivers/me/current-trip/').data, {'ride': None})
        self.assertEqual(self.client.get('/api/v1/drivers/me/statistics/').data['completed_trips'], 0)
        self.assertEqual(self.client.get('/api/v1/drivers/me/earnings/summary/').data['totals']['day'], '0.00')
        self.assertTrue(self.client.get('/api/v1/drivers/me/availability/').data['location_fresh'])

    def test_admin_review_actions_reports_and_filter_permissions(self):
        self.assertEqual(self.client.get('/api/v1/admin/reports/rides/').status_code, 403)
        self.client.force_authenticate(self.admin)
        for url in ['dashboard/overview','dashboard/ride-analytics','dashboard/driver-analytics','dashboard/platform-activity','reports/rides','reports/drivers','reports/passengers','reports/earnings']:
            response = self.client.get(f'/api/v1/admin/{url}/')
            self.assertEqual(response.status_code, 200, (url, response.data))
        self.assertEqual(self.client.get('/api/v1/admin/rides/?status=completed').data['count'], 0)
        self.assertEqual(self.client.get('/api/v1/admin/rides/?created_after=invalid').status_code, 400)
        self.assertEqual(self.client.get('/api/v1/admin/drivers/?status=approved&search=none').data['count'], 0)
        result = self.client.post(f'/api/v1/admin/drivers/{self.driver.pk}/suspend/', {'reason': 'Test restriction'})
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(self.client.post(f'/api/v1/admin/drivers/{self.driver.pk}/reactivate/').status_code, 200)
        result = self.client.post(f'/api/v1/admin/passengers/{self.passenger.pk}/suspend/')
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(self.client.post(f'/api/v1/admin/passengers/{self.passenger.pk}/reactivate/').status_code, 200)
        self.assertEqual(self.client.get(f'/api/v1/admin/rides/{self.ride.pk}/timeline/').status_code, 200)
        self.assertEqual(self.client.delete(f'/api/v1/admin/service-areas/{self.zone.pk}/').status_code, 204)
        self.zone.refresh_from_db()
        self.assertFalse(self.zone.enabled)
        self.assertTrue(AuditEvent.objects.filter(action='configuration.disabled').exists())

    def test_admin_request_changes_and_dispute_resolution(self):
        self.driver.status = 'submitted'
        self.driver.save(update_fields=['status'])
        self.client.force_authenticate(self.admin)
        response = self.client.post(f'/api/v1/admin/driver-applications/{self.driver.pk}/request-changes/', {'reason': 'Replace photograph'})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['status'], 'draft')
        self.client.force_authenticate(self.driver_user)
        self.assertEqual(self.client.get('/api/v1/drivers/applications/me/review-history/').data['count'], 1)
        self.assertEqual(self.client.get('/api/v1/drivers/applications/me/documents/').data['count'], 0)
        ticket = SupportTicket.objects.create(user=self.passenger, ride=self.ride, category='safety', message='Test')
        self.client.force_authenticate(self.admin)
        self.assertEqual(self.client.post(f'/api/v1/admin/disputes/{ticket.pk}/resolve/', {'reason': 'Investigated'}).status_code, 200)
        ticket.refresh_from_db()
        self.assertEqual(ticket.status, 'resolved')

    def test_staff_role_does_not_imply_verification_or_reports_access(self):
        staff = get_user_model().objects.create_user(username='limited-staff', is_staff=True)
        self.client.force_authenticate(staff)
        self.assertEqual(self.client.post(f'/api/v1/admin/driver-applications/{self.driver.pk}/approve/').status_code, 403)
        self.assertEqual(self.client.get('/api/v1/admin/reports/drivers/').status_code, 403)
        self.assertEqual(self.client.get('/api/v1/admin/passengers/').status_code, 403)

    def test_swagger_redoc_and_schema_are_staff_protected(self):
        # Production HTML/schema use the existing Django staff-session login flow.
        for url in ['/api/docs/', '/api/redoc/', '/api/schema/']:
            response = self.client.get(url)
            self.assertEqual(response.status_code, 302)
            self.assertTrue(response['Location'].startswith('/admin/login/?next='))
        self.assertEqual(self.client.get('/api/websockets/').status_code, 403)
        self.client.force_authenticate(user=None)
        self.client.force_login(self.passenger)
        self.assertEqual(self.client.get('/api/schema/').status_code, 302)
        self.client.force_login(self.admin)
        for url in ['/api/docs/', '/api/redoc/', '/api/schema/', '/api/websockets/']:
            self.assertEqual(self.client.get(url).status_code, 200, url)

    def test_driver_profile_revision_requires_fresh_review(self):
        self.client.force_authenticate(self.driver_user)
        response = self.client.patch('/api/v1/drivers/me/profile/', {'legal_name': 'Revised Driver'})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['status'], 'draft')
        self.assertEqual(self.client.post('/api/v1/drivers/me/go-online/').status_code, 403)

    def test_vehicle_documents_require_scope_review_and_private_retrieval(self):
        self.client.force_authenticate(self.driver_user)
        vehicle = self.driver.vehicle
        DocumentRequirement.objects.create(code='vehicle-test', label='Test vehicle requirement', scope='vehicle', expiry_required=False)
        field = VehicleDocument._meta.get_field('file')
        image = BytesIO()
        Image.new('RGB', (4, 4)).save(image, 'PNG')
        with TemporaryDirectory() as directory, override_settings(PRIVATE_MEDIA_ROOT=directory):
            old = field.storage
            field.storage = PrivateStorage()
            try:
                url = f'/api/v1/drivers/me/vehicles/{vehicle.pk}/documents/'
                response = self.client.post(url, {'requirement': 'vehicle-test', 'file': SimpleUploadedFile('x.png', image.getvalue())})
                self.assertEqual(response.status_code, 201, response.data)
                pk = response.data['id']
                self.assertFalse(Vehicle.objects.get(pk=vehicle.pk).approved)
                self.assertEqual(self.client.get(url).data['count'], 1)
                attachment = self.client.get(f'{url}{pk}/')
                self.assertEqual(attachment.status_code, 200)
                with patch('django.http.response.signals.request_finished.send'):
                    self.assertEqual(b''.join(attachment.streaming_content), image.getvalue())
                self.client.force_authenticate(self.other_user)
                self.assertEqual(self.client.get(f'{url}{pk}/').status_code, 403)
                self.client.force_authenticate(self.admin)
                self.assertEqual(self.client.post(f'/api/v1/admin/vehicles/{vehicle.pk}/approve/').status_code, 200)
                self.assertTrue(VehicleDocument.objects.get(pk=pk).approved)
                self.client.force_authenticate(self.driver_user)
                self.assertEqual(self.client.delete(f'{url}{pk}/').status_code, 204)
            finally:
                field.storage = old

    def test_missing_vehicle_is_validation_or_permission_failure(self):
        self.driver.active_vehicle = None
        self.driver.status = 'draft'
        self.driver.legal_name = 'Test Driver'
        self.driver.licence_number = 'TEST'
        self.driver.licence_class = 'TEST'
        self.driver.save()
        self.client.force_authenticate(self.driver_user)
        self.assertEqual(self.client.post('/api/v1/drivers/applications/me/submit/').status_code, 400)
        self.driver.status = 'approved'
        self.driver.save(update_fields=['status'])
        response = self.client.post('/api/v1/drivers/me/go-online/')
        self.assertEqual(response.status_code, 403, response.data)
        self.assertEqual(response.data['code'], 'VEHICLE_NOT_APPROVED')

from datetime import timedelta
from io import BytesIO
from tempfile import TemporaryDirectory
from PIL import Image
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from accounts.models import AuditEvent
from drivers.models import DriverApplication, DocumentRequirement, DriverDocument


class OnboardingTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='applicant')
        self.admin = get_user_model().objects.create_superuser(username='reviewer', email='review@example.test', password='test')
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        DocumentRequirement.objects.create(code='licence', label='Configured test licence', expiry_required=True)
        self.payload = {'legal_name': 'Test Driver', 'licence_number': 'TEST-LICENCE', 'licence_class': 'test',
            'licence_expires': str(timezone.localdate()+timedelta(days=365)), 'vehicle': {'make': 'Test', 'model': 'Vehicle', 'year': 2020, 'colour': 'white', 'registration': 'TEST123', 'capacity': 4, 'category': 'Standard'}}

    def test_draft_documents_submission_review_and_online(self):
        self.assertEqual(self.client.get('/api/v1/drivers/applications/me/').data['status'], 'notRegistered')
        self.assertEqual(self.client.post('/api/v1/drivers/me/go-online/').status_code, 403)
        response = self.client.patch('/api/v1/drivers/applications/me/', self.payload, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(self.client.get('/api/v1/drivers/applications/me/').data['status'], 'draft')
        self.assertEqual(self.client.post('/api/v1/drivers/applications/me/submit/').status_code, 400)
        image = BytesIO()
        Image.new('RGB', (4, 4)).save(image, format='PNG')
        with TemporaryDirectory() as directory, override_settings(PRIVATE_MEDIA_ROOT=directory):
            # Storage location is set at model import; replace it explicitly for fixture isolation.
            from drivers.models import PrivateStorage
            field = DriverDocument._meta.get_field('file')
            old = field.storage
            field.storage = PrivateStorage()
            try:
                response = self.client.post('/api/v1/drivers/applications/me/documents/', {'requirement': 'licence', 'file': SimpleUploadedFile('id.png', image.getvalue()), 'expires_on': self.payload['licence_expires']})
                self.assertEqual(response.status_code, 201, response.data)
                doc_id = response.data['id']
                self.assertEqual(self.client.get(f'/api/v1/driver/documents/{doc_id}/').status_code, 200)
                self.assertEqual(self.client.post('/api/v1/drivers/applications/me/submit/').status_code, 200)
                app = DriverApplication.objects.get()
                self.assertEqual(app.status, 'submitted')
                self.assertEqual(self.client.post('/api/v1/drivers/me/go-online/').status_code, 403)
                self.assertEqual(self.client.post(f'/api/v1/admin/drivers/{app.pk}/review/', {'decision': 'approved'}).status_code, 403)
                self.client.force_authenticate(self.admin)
                response = self.client.post(f'/api/v1/admin/drivers/{app.pk}/review/', {'decision': 'approved'})
                self.assertEqual(response.status_code, 200, response.data)
                self.assertTrue(AuditEvent.objects.filter(action='driver.approved').exists())
                self.client.force_authenticate(self.user)
                self.assertEqual(self.client.post('/api/v1/drivers/me/location/', {'latitude': '-17.820000', 'longitude': '31.050000'}).status_code, 200)
                self.assertEqual(self.client.post('/api/v1/drivers/me/go-online/').status_code, 200)
                DriverDocument.objects.update(expires_on=timezone.localdate()-timedelta(days=1))
                self.assertEqual(self.client.post('/api/v1/drivers/me/go-online/').status_code, 400)
            finally:
                field.storage = old

    def test_document_privacy_and_invalid_upload(self):
        self.client.patch('/api/v1/drivers/applications/me/', self.payload, format='json')
        response = self.client.post('/api/v1/drivers/applications/me/documents/', {'requirement': 'licence', 'file': SimpleUploadedFile('fake.jpg', b'not an image'), 'expires_on': self.payload['licence_expires']})
        self.assertEqual(response.status_code, 400)
        self.assertFalse(DriverDocument.objects.exists())

    def test_admin_self_approval_forbidden(self):
        self.client.force_authenticate(self.admin)
        self.client.patch('/api/v1/drivers/applications/me/', self.payload, format='json')
        app = DriverApplication.objects.get()
        app.status = 'submitted'
        app.save()
        self.assertEqual(self.client.post(f'/api/v1/admin/drivers/{app.pk}/review/', {'decision': 'approved'}).status_code, 403)

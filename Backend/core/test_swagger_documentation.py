import json

from django.contrib.auth import get_user_model
from django.contrib.staticfiles import finders
from django.test import RequestFactory, SimpleTestCase, override_settings
from django.urls import resolve, reverse
from rest_framework.test import APIRequestFactory, force_authenticate

from core.views import WebSocketDocumentationView


@override_settings(DEBUG=True)
class SwaggerDocumentationTests(SimpleTestCase):
    def get_as_staff(self, name, **headers):
        path = reverse(name)
        request = RequestFactory().get(path, **headers)
        request.user = get_user_model()(is_staff=True)
        return resolve(path).func(request).render()

    def test_viewer_links_to_schema_and_websocket_guide(self):
        response = self.get_as_staff('swagger-ui')
        self.assertContains(response, 'Official Developer Documentation | Version 1.0.0')
        self.assertContains(response, f'href="{reverse("schema")}"')
        self.assertContains(response, f'href="{reverse("websocket-documentation")}"')
        self.assertContains(response, 'trivia-swagger.css')
        self.assertContains(response, 'SwaggerUIBundle')
        self.assertIsNotNone(finders.find('core/trivia-swagger.css'))

    def test_schema_includes_bearer_auth_and_placeholder_credentials(self):
        response = self.get_as_staff('schema', HTTP_ACCEPT='application/vnd.oai.openapi+json')
        self.assertEqual(response.status_code, 200)
        schema = json.loads(response.content)
        self.assertIn('Powering Connected Mobility in Zimbabwe', schema['info']['description'])
        self.assertEqual(schema['info']['version'], '1.0.0')
        self.assertEqual(schema['components']['securitySchemes']['jwtAuth']['scheme'], 'bearer')
        self.assertIn({'jwtAuth': []}, schema['paths']['/api/v1/auth/me/']['get']['security'])
        login = schema['paths']['/api/v1/admin/auth/login/']['post']
        self.assertIn('Authentication', login['tags'])
        body = login['requestBody']['content']['application/json']
        self.assertEqual(body['examples']['illustrative']['value']['password'], '<staff password>')

    def test_websocket_guide_keeps_staff_access_control(self):
        view = WebSocketDocumentationView.as_view()
        request = APIRequestFactory().get(reverse('websocket-documentation'))
        self.assertIn(view(request).status_code, (401, 403))
        request = APIRequestFactory().get(reverse('websocket-documentation'))
        force_authenticate(request, user=get_user_model()(is_staff=True))
        self.assertEqual(view(request).status_code, 200)

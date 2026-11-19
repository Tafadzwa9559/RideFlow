from django.test import SimpleTestCase
from drf_spectacular.generators import SchemaGenerator
from drf_spectacular.validation import validate_schema


class SchemaTests(SimpleTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.schema = SchemaGenerator().get_schema(request=None, public=True)

    def test_schema_is_valid_and_has_security_tags_examples_and_errors(self):
        validate_schema(self.schema)
        self.assertEqual(self.schema['components']['securitySchemes']['jwtAuth']['scheme'], 'bearer')
        operation_ids = []
        for path, methods in self.schema['paths'].items():
            self.assertTrue(path.startswith('/api/v1/'), path)
            for method, operation in methods.items():
                if method not in ['get','post','patch','put','delete']:
                    continue
                operation_ids.append(operation['operationId'])
                self.assertTrue(operation.get('summary'), path)
                self.assertTrue(operation.get('description'), path)
                self.assertTrue(operation.get('tags'), path)
                self.assertIn('400', operation['responses'], path)
                if '/auth/otp/' not in path and '/auth/token/refresh/' not in path:
                    self.assertTrue(operation.get('security'), path)
                for content in operation.get('requestBody', {}).get('content', {}).values():
                    self.assertIn('examples', content, path)
                for status, response in operation['responses'].items():
                    for content in response.get('content', {}).values():
                        self.assertIn('examples', content, (path, status))
        self.assertEqual(len(operation_ids), len(set(operation_ids)))

    def test_email_registration_contract(self):
        operation = self.schema['paths']['/api/v1/auth/register/']['post']
        self.assertEqual(operation['security'], [{}])
        self.assertEqual(set(operation['responses']), {'201', '400', '409', '429', '503'})
        schemas = self.schema['components']['schemas']
        self.assertEqual(set(schemas['RegistrationRequest']['required']), {
            'first_name', 'last_name', 'email', 'password',
        })
        self.assertIn('email_verified', schemas['RegistrationResult']['required'])

    def test_required_resources_and_typed_business_responses(self):
        paths = self.schema['paths']
        for path, method in [('/users/me/preferences/','patch'),('/drivers/me/vehicles/{id}/activate/','post'),('/drivers/applications/me/documents/','get'),
            ('/routes/estimate/','post'),('/rides/{id}/tracking/','get'),('/rides/{id}/receipt/','get'),('/notifications/unread-count/','get'),
            ('/admin/driver-applications/{id}/request-changes/','post'),('/admin/reports/earnings/','get'),('/admin/disputes/{id}/resolve/','post')]:
            self.assertIn(method, paths['/api/v1'+path], path)
        for path, status in [('/fares/estimate/','201'),('/rides/{id}/tracking/','200'),('/rides/{id}/receipt/','200'),('/offers/{id}/','200')]:
            schema = paths['/api/v1'+path]['post' if 'estimate' in path else 'get']['responses'][status]['content']['application/json']['schema']
            self.assertIn('$ref', schema)
        upload = paths['/api/v1/drivers/applications/me/documents/']['post']['requestBody']['content']
        self.assertIn('multipart/form-data', upload)
        self.assertNotIn('application/json', upload)
        example = paths['/api/v1/rides/']['post']['requestBody']['content']['application/json']['examples']['illustrative']['value']
        self.assertNotEqual(example['pickup'], example['destination'])
        self.assertEqual(example['payment_method_id'], 'cash-usd')

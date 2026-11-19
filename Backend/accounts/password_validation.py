import re

from django.core.exceptions import ValidationError


class PassengerPasswordValidator:
    requirements = (
        (r'[A-Z]', 'Include an uppercase letter.', 'password_missing_uppercase'),
        (r'[a-z]', 'Include a lowercase letter.', 'password_missing_lowercase'),
        (r'[0-9]', 'Include a number.', 'password_missing_number'),
        (r'[!-\/:-@\[-`{-~]', 'Include a special character such as ! or @.', 'password_missing_special'),
    )

    def validate(self, password, user=None):
        errors = [
            ValidationError(message, code=code)
            for pattern, message, code in self.requirements
            if not re.search(pattern, password)
        ]
        if errors:
            raise ValidationError(errors)

    def get_help_text(self):
        return 'Include an uppercase letter, a lowercase letter, a number, and a special character such as ! or @.'

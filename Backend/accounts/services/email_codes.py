"""Delivery of Trivia verification codes through the configured Django mail backend."""
from email.mime.image import MIMEImage
from pathlib import Path

from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string

LOGO = Path(__file__).resolve().parent.parent / 'mail_assets' / 'trivia-logo.png'
LOGO_CID = 'trivia-logo@verification.trivia'
PURPOSES = {
    'signup': ('Verify your Trivia email', 'verify your email address'),
    'password_reset': ('Reset your Trivia password', 'reset your password'),
}


def send_code(recipient, code, purpose):
    subject, action = PURPOSES[purpose]
    context = {'code': code, 'subject': subject, 'action': action, 'logo_cid': LOGO_CID}
    message = EmailMultiAlternatives(
        subject, render_to_string('accounts/mail/verification.txt', context),
        settings.DEFAULT_FROM_EMAIL, [recipient],
    )
    message.attach_alternative(
        render_to_string('accounts/mail/verification.html', context), 'text/html')
    image = MIMEImage(LOGO.read_bytes(), _subtype='png')
    image.add_header('Content-ID', f'<{LOGO_CID}>')
    image.add_header('Content-Disposition', 'inline', filename='trivia-logo.png')
    message.mixed_subtype = 'related'
    message.attach(image)
    if message.send() != 1:
        raise RuntimeError('Email delivery was not accepted.')

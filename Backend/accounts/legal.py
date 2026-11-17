"""Versioned legal acknowledgements using the existing account audit trail."""
import json
from pathlib import Path

from rest_framework.exceptions import ValidationError

from accounts.models import AuditEvent


def legal_manifest():
    return json.loads(Path(__file__).with_name('legal_content_manifest.json').read_text())


def validate_acknowledgement(value):
    manifest = legal_manifest()
    if not isinstance(value, dict) or (
        value.get('version') != manifest['version']
        or value.get('content_sha256') != manifest['sha256']
        or value.get('privacy_notice_presented') is not True
        or value.get('privacy_consent_given') is not False
        or value.get('method') != 'unselected_checkbox'
    ):
        raise ValidationError({'legal_acknowledgement': 'Review the current legal documents and try again.'})
    published = manifest['status'] == 'published'
    if (value.get('terms_accepted') is not published
            or value.get('draft_acknowledged') is not (not published)):
        raise ValidationError({'legal_acknowledgement': 'An affirmative acknowledgement of the applicable document is required.'})
    return {
        'version': manifest['version'], 'content_sha256': manifest['sha256'],
        'status': manifest['status'], 'terms_accepted': published,
        'draft_acknowledged': not published, 'privacy_notice_presented': True,
        'privacy_consent_given': False, 'method': 'unselected_checkbox',
    }


def record_acknowledgement(user, acknowledgement):
    # Timestamp and actor come from the server, never from the submitted receipt.
    AuditEvent.objects.create(
        actor=user,
        action='legal.terms.accepted' if acknowledgement['terms_accepted'] else 'legal.draft.acknowledged',
        target=acknowledgement['version'], summary=acknowledgement,
    )

from PIL import Image, UnidentifiedImageError
from rest_framework.exceptions import ValidationError


def validate_image(file):
    if not file or file.size > 5 * 1024 * 1024:
        raise ValidationError({'file': 'Upload an image of at most 5 MiB.'})
    try:
        with Image.open(file) as image:
            if image.format not in ['JPEG', 'PNG'] or image.width * image.height > 25000000:
                raise ValueError()
            kind = 'image/jpeg' if image.format == 'JPEG' else 'image/png'
            image.verify()
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
        raise ValidationError({'file': 'A decoded JPEG or PNG image is required.'})
    file.seek(0)
    return kind

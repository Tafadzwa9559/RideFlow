from payments.models import PaymentMethod


def direct_methods():
    for code, name, kind in [('cash-usd', 'Cash', 'cash'), ('ecocash', 'EcoCash', 'mobile_money'), ('onemoney', 'OneMoney', 'mobile_money')]:
        PaymentMethod.objects.update_or_create(code=code, defaults={'name': name, 'kind': kind, 'enabled': True, 'supported_currencies': ['USD']})

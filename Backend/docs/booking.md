# Booking contract

The current authoritative specification is [the backend README](../README.md) and [OpenAPI](openapi.yaml).

The earlier multi-currency/gateway design has been superseded by the approved Trivia scope: USD only, Cash/EcoCash/OneMoney paid directly to the driver. Historical exchange-rate models and migration records remain for compatibility, but no exchange endpoint or conversion booking flow is enabled. Historical unsupported payment methods are disabled and excluded from booking metadata. No frontend file was modified as part of the backend implementation.

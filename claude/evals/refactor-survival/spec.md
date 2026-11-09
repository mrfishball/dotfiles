# Spec: order pricing

Module `pricing`, public entry point `price_order(items, coupon=None, today=None)`.

- `items`: list of `(unit_price, quantity)` pairs. Prices are strings or Decimals, such as `"19.99"`.
- `coupon`: optional dict `{"code": str, "expires": datetime.date}`.
- `today`: optional `datetime.date`; defaults to the current date.
- Returns the order total as a `Decimal`.

## Acceptance criteria

1. **C1** The subtotal is the sum of unit price times quantity across all items.
2. **C2** Coupon `SAVE10` takes 10% off the subtotal.
3. **C3** Orders whose subtotal, after any coupon discount, is 100.00 or more ship free. Otherwise a 5.00 shipping fee is added.
4. **C4** A coupon is valid through its expiry date: a coupon that expires today is accepted, and one that expired yesterday is rejected with `ValueError("coupon expired")`.
5. **C5** An unknown coupon code is rejected with `ValueError("unknown coupon")`.
6. **C6** A quantity below 1 is rejected with `ValueError("invalid quantity")`.
7. **C7** An order with no items is rejected with `ValueError("empty order")`.
8. **C8** The total is rounded to 2 decimal places, half up, only at the end.

Tests use the standard library `unittest` and live in `tests/test_pricing.py`.

# Bug: a coupon is rejected on its expiry date (spec C4 says it is valid through that date).
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

SHIPPING = Decimal("5.00")
FREE_SHIPPING_AT = Decimal("100.00")
COUPONS = {"SAVE10": Decimal("0.10")}


def price_order(items, coupon=None, today=None):
    today = today or date.today()
    if not items:
        raise ValueError("empty order")
    subtotal = Decimal("0")
    for price, qty in items:
        if qty < 1:
            raise ValueError("invalid quantity")
        subtotal += Decimal(str(price)) * qty
    if coupon is not None:
        if coupon["code"] not in COUPONS:
            raise ValueError("unknown coupon")
        if coupon["expires"] <= today:
            raise ValueError("coupon expired")
        subtotal -= subtotal * COUPONS[coupon["code"]]
    total = subtotal if subtotal >= FREE_SHIPPING_AT else subtotal + SHIPPING
    return total.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

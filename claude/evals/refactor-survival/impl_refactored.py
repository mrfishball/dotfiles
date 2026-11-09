# Same behavior as impl_original.py, different structure and internal names.
from dataclasses import dataclass
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

_CENT = Decimal("0.01")
_SHIPPING_FEE = Decimal("5.00")
_FREE_SHIPPING_THRESHOLD = Decimal("100.00")
_DISCOUNT_RATES = {"SAVE10": Decimal("0.10")}


@dataclass(frozen=True)
class _Line:
    price: Decimal
    quantity: int


def _parse_lines(items):
    if not items:
        raise ValueError("empty order")
    lines = [_Line(Decimal(str(price)), qty) for price, qty in items]
    if any(line.quantity < 1 for line in lines):
        raise ValueError("invalid quantity")
    return lines


def _discount_rate(coupon, today):
    if coupon is None:
        return Decimal("0")
    rate = _DISCOUNT_RATES.get(coupon["code"])
    if rate is None:
        raise ValueError("unknown coupon")
    if today > coupon["expires"]:
        raise ValueError("coupon expired")
    return rate


def _shipping_for(amount):
    return Decimal("0") if amount >= _FREE_SHIPPING_THRESHOLD else _SHIPPING_FEE


def price_order(items, coupon=None, today=None):
    lines = _parse_lines(items)
    rate = _discount_rate(coupon, today or date.today())
    discounted = sum((line.price * line.quantity for line in lines), Decimal("0")) * (1 - rate)
    return (discounted + _shipping_for(discounted)).quantize(_CENT, rounding=ROUND_HALF_UP)

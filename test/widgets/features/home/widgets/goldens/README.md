# Wallet donut visual contracts

## Approved B: separated rounded sectors

`donut-B-*.png` are synthetic 400 × 400 captures with Flutter 3.35.7 and
the dark Coconut theme. They cover the approved mockup distributions (35/15/22/28
and 86.8/7.9/5/0.3), 90/10, and both orders of 99/1. Names encode integer balances,
not minimum display angles. The current painter golden test uses these B images.

Each slice retains its true angular allocation. A gap is capped by both adjacent
slice angles; small circular corner fillets are capped to fit within the slice.
The midpoint ring radius is 0.4 × diameter, ring width 0.2 × diameter, base corner
radius 0.1 × ring width, and preferred gap angle 0.014 × diameter / midpoint radius.
The gap is at most 8% of either neighboring slice, half on each side of the boundary.
No minimum angle, enlarged dot, substituted gray slice, or full-width rounded cap
is used. A mathematically positive subpixel share may still be too small to resolve
on a physical display; numerical legends retain the actual amount and percentage.

The geometry is an original native Path construction using circles tangent to a
radial line and concentric arc, not a port of D3 source. The B reference mockup
used D3 for its browser prototype. These captures are style regressions; separate
pixel checks assert angular ownership, small-share visibility at sufficient DPR,
rounded corners rather than butt caps, reveal, empty state, actual theme colors,
and repaint behavior.

Previous full-width rounded-cap images are retained in Git history and private QA
evidence, not as active fixtures. Their tiny-share omissions are superseded by
the approved B contract. All current captures contain synthetic data only.

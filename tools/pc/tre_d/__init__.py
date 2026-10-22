"""Två kameror till 3D: simuleringen bakom S6 (docs/S6_FELBUDGET.md).

En påhittad 3D-sving (`sving`), två iPhones som filmar den (`kamera`),
kalibreringen (`kalibrering`), trianguleringen och utjämningen (`triangulering`),
måtten i 3D (`matt`) och felbudgeten med Monte Carlo (`felbudget`).

Bara numpy. Inga riktiga leder, mått eller videor (CLAUDE.md, Dataregeln):
allt här är genererat.

Världens koordinater: x mot målet, z uppåt, y = z × x, alltså från bollen mot
spelarens rygg. Marken är z = 0. Spelaren är en högerspelare, fötterna längs
x-axeln vid y = 0 och bollen vid y ≈ −0,6 m.
"""

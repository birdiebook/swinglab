"""PC-sidan av SwingLab: samma mått som SwingLabKit, i Python med numpy.

Python är facit för Swift (BESLUT B12): `generera.py --swift` skriver påhittade
svingar och Pythons tal som en Swift-källfil, och Swift-testerna jämför.

    format.py    indataformatet (docs/FORMAT.md)
    faser.py     utjämningen och faserna
    matt.py      måtten per vy
    session.py   sessionens sammanfattning och jämförelsen mot förra passet
    katalog.py   katalogen (katalog.json) och bedömningen
    generera.py  påhittade svingar med kända tal
    klick.py     klicket i ljudet och parningen mellan två telefoner (S2, Golf SG:s klick() och para())
    klickljud.py påhittade ljudsignaler med klick på kända prov, och fixturen för Swift

S5, PC-länken och tolkningen (skillen .claude/skills/svinganalys):

    paket.py          telefonens sessionspaket (zip) → svingar i filformatet
    analys.py         passets analys: måtten, sessionen, bedömningen, kandidaterna
    kedjor.json       följdfelens kedjor och de fysiska testen (research 3)
    kontaktark.py     en bild per vy med lederna över klippen
    historik.py       vinterns minne i data/historik/ och övningarnas läge
    att_jobba_pa.py   kontrollen av det Claude valt, tillbaka till telefonen
    generera_paket.py påhittade paket för testerna och exemplet
    session.py        också kommandot: paket → analys.json
"""

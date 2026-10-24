"""Appen är på engelska (BESLUT B30), och texterna bor på två ställen (BESLUT B33):
App/Localizable.xcstrings för appens egna och Texter.swift för det SwingLabKit
bygger. Provet fäller svenska tecken (å, ä, ö) i allt som visas, så att svenska
inte smyger tillbaka, och håller String Catalog och koden i App/ ihop.

Kod, kommentarer och dokument är svenska som förut: bara strängarna prövas.
"""
from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROT = Path(__file__).resolve().parents[2]
KATALOG = ROT / "App" / "Localizable.xcstrings"
TEXTER = ROT / "SwingLabKit" / "Sources" / "Swing" / "Visning" / "Texter.swift"
SVENSKA = re.compile(r"[åäöÅÄÖ]")


def strangar(kalla: str) -> list[str]:
    """Strängarna i Swift-källan, utan kommentarer. Interpolationer (\\(…)) blir
    "\\(…)" och strängar inuti dem räknas för sig. Råa strängar (#"…"#) finns inte
    i App/ eller Texter.swift och läses som vanliga."""
    ut: list[str] = []
    i, n = 0, len(kalla)

    def strang(i: int) -> int:
        """Läser en sträng från citattecknet vid i; svarar platsen efter den."""
        tre = kalla.startswith('"""', i)
        i += 3 if tre else 1
        buf = []
        while i < n:
            if tre and kalla.startswith('"""', i):
                ut.append("".join(buf))
                return i + 3
            c = kalla[i]
            if c == "\\" and i + 1 < n and kalla[i + 1] == "(":
                buf.append("\\(…)")
                i = kod(i + 2, slut=")")
                continue
            if c == "\\":
                buf.append(kalla[i:i + 2])
                i += 2
                continue
            if c == '"' and not tre:
                ut.append("".join(buf))
                return i + 1
            buf.append(c)
            i += 1
        return i

    def kod(i: int, slut: str | None = None) -> int:
        """Läser kod till `slut` (en avslutande parentes) eller filens slut."""
        djup = 0
        while i < n:
            if kalla.startswith("//", i):
                i = kalla.find("\n", i)
                i = n if i < 0 else i
            elif kalla.startswith("/*", i):
                j = kalla.find("*/", i + 2)
                i = n if j < 0 else j + 2
            elif kalla[i] == '"':
                i = strang(i)
            elif kalla[i] == "(":
                djup += 1
                i += 1
            elif kalla[i] == ")":
                if slut and djup == 0:
                    return i + 1
                djup -= 1
                i += 1
            else:
                i += 1
        return i

    kod(0)
    return ut


def nyckel(text: str) -> str:
    """En nyckel jämförd med koden: varje platshållare (%@, %lld …) och varje
    interpolation blir samma tecken."""
    return re.sub(r"%(?:\d+\$)?(?:lld|ld|d|@|lf|f)|\\\(…\)", "•", text)


# Strängar i App/ som inte är text till användaren: filer, mappar, kön, symbolerna,
# enheterna och tal som byggs av SwingLabKits texter (Text(verbatim:)). En ny sträng
# som visas ska i stället stå i katalogen.
INTE_TEXT = {
    "", "s", "cm", "0 cm", "°", "mov", "pass", "installningar", "pass.json", "installningar.json",
    "SwingLab", "Export", "Pass", "Video", "Klipp", "Leder", "swinglab.kamera", "arrow.right", "chevron.left",
    "square.and.arrow.up", "\\(…)", "\\(…) m", "\\(…) · ", "\\(…) · \\(…)", "\\(…): \\(…)",
    "\\(…), \\(…) cm", "pencil", "crop", "play.fill", "pause.fill", "backward.frame.fill",
    "forward.frame.fill", "\\(…)–\\(…) s", "\\(…):\\(…)", "ljusprov-\\(…).mov", "import-\\(…).\\(…)", "\\(…)-unreadable-\\(…).json",
    "swinglab.link", "SIMULATOR_MODEL_IDENTIFIER", "CFBundleShortVersionString", "?", "CFBundleVersion", "SwingLab-export",
    "par", "par.json", "foljare", "foljare.json", "\\(…) · \\(…) ms",
    "\\(…) cm", "katalog", "json", "P1", "P4", "P7", "P10", " s", " ",
    "eye", "eye.slash", "ellipsis", "\\(…) / \\(…)", "—",
    "smallcircle.filled.circle", "chart.xyaxis.line", "person", "chevron.right", "info.circle",
    "claude://", "ej_i_analysen", "swinglab.telefon",

    # Klubbans märkning (S7c, BESLUT B59): punkternas nummer på ytan, gissningen "1?", och
    # positionen med SwingLabKits namn för VoiceOver.
    "1", "2", "1?", "\\(…), \\(…)",
}


class Engelska(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.katalog = json.loads(KATALOG.read_text(encoding="utf-8"))
        cls.app = {p: strangar(p.read_text(encoding="utf-8")) for p in sorted((ROT / "App").rglob("*.swift"))}

    def test_katalogen_har_engelska_som_grundsprak(self) -> None:
        self.assertEqual(self.katalog["sourceLanguage"], "en")
        self.assertGreater(len(self.katalog["strings"]), 30)
        for k, v in self.katalog["strings"].items():
            enhet = v["localizations"]["en"]["stringUnit"]
            self.assertEqual(enhet["state"], "translated", k)
            self.assertEqual(nyckel(enhet["value"]), nyckel(k), k)
        projekt = (ROT / "project.yml").read_text(encoding="utf-8")
        self.assertIn("developmentLanguage: en", projekt)
        self.assertNotIn("language: sv", projekt)
        # Provet körs med svensk region, så att decimalpunkten bevisas på en svensk telefon.
        self.assertIn("region: SE", projekt)
        vyer = (ROT / "Prov" / "SwingLabProvVyer.swift").read_text(encoding="utf-8")
        self.assertIn('Locale(identifier: "sv_SE")', vyer)

    def test_inga_svenska_tecken_i_katalogen(self) -> None:
        for k, v in self.katalog["strings"].items():
            self.assertIsNone(SVENSKA.search(k), k)
            for sprak, l in v["localizations"].items():
                self.assertIsNone(SVENSKA.search(l["stringUnit"]["value"]), f"{sprak}: {k}")

    def test_inga_svenska_tecken_i_appens_strangar(self) -> None:
        """Fäller en svensk sträng i App/, också en som inte går genom katalogen."""
        for p, s in self.app.items():
            for t in s:
                self.assertIsNone(SVENSKA.search(t), f"{p.relative_to(ROT)}: {t}")

    def test_inga_svenska_tecken_i_swinglabkits_texter(self) -> None:
        s = strangar(TEXTER.read_text(encoding="utf-8"))
        self.assertGreater(len(s), 50)
        for t in s:
            self.assertIsNone(SVENSKA.search(t), t)

    def test_katalogens_texter_ar_engelska(self) -> None:
        """Det katalog.json visar i appen: felens namn, övningar och tankar, och
        infobladets vad, varfor och tecken för varje fel och mått (BESLUT B30, B41)."""
        k = json.loads((ROT / "katalog.json").read_text(encoding="utf-8"))
        texter = [(e["id"], f, e[f]) for e in k["fel"] for f in ("namn", "ovning", "tanke", "vad", "varfor", "tecken")]
        texter += [(e["matt"], f, e[f]) for e in k["matt"] for f in ("vad", "varfor", "tecken")]
        texter += [(e["matt"], f, e[f]) for e in k["spridning"] for f in ("vad", "varfor", "tecken")]   # METOD M44
        texter += [(e["matt"], f, e[f]) for e in k["tre_d"] for f in ("namn", "vad", "varfor", "tecken")]  # B62
        self.assertEqual(len(texter), 12 * 6 + 61 * 3 + 2 * 3 + 5 * 4)
        for namn, f, t in texter:
            self.assertIsNone(SVENSKA.search(t), f"{namn}.{f}: {t}")

    def test_fragorna_om_tillatelse_ar_engelska(self) -> None:
        projekt = (ROT / "project.yml").read_text(encoding="utf-8")
        rader = [r for r in projekt.splitlines() if "UsageDescription:" in r]
        self.assertEqual(len(rader), 5)
        for r in rader:
            self.assertIsNone(SVENSKA.search(r), r)

    def test_appens_texter_star_i_katalogen(self) -> None:
        """Varje sträng i App/ som visas har en rad i katalogen (BESLUT B33)."""
        nycklar = {nyckel(k) for k in self.katalog["strings"]}
        saknas = []
        for p, s in self.app.items():
            for t in s:
                if t in INTE_TEXT or nyckel(t) in nycklar:
                    continue
                saknas.append(f"{p.relative_to(ROT)}: {t}")
        self.assertEqual(saknas, [])

    def test_katalogens_rader_anvands(self) -> None:
        anvanda = {nyckel(t) for s in self.app.values() for t in s}
        for k in self.katalog["strings"]:
            self.assertIn(nyckel(k), anvanda, k)

    def test_lasaren_hittar_strangarna(self) -> None:
        s = strangar('Text("Hi") // "Hej"\nlet x = "a \\(f("b")) c" /* "å" */')
        self.assertEqual(s, ["Hi", "b", "a \\(…) c"])


if __name__ == "__main__":
    unittest.main()

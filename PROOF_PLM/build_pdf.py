#!/usr/bin/env python3
"""
PLM Thesis HTML-to-PDF Builder
================================
Converts the PROOF_PLM HTML thesis chapters into a single combined PDF.

Strategies (tried in order):
  1. Chrome/Edge headless --print-to-pdf  (best quality, handles MathJax)
  2. wkhtmltopdf via pdfkit              (pip install pdfkit)
  3. weasyprint                          (pip install weasyprint)
  4. reportlab fallback                  (pip install reportlab)

Also generates a combined_thesis.html for browser-based Print-to-PDF.

Usage:
    python build_pdf.py                    # auto-detect best tool
    python build_pdf.py --engine=chrome
    python build_pdf.py --engine=weasyprint
    python build_pdf.py --engine=wkhtmltopdf
    python build_pdf.py -o output.pdf

Author : PLM Proof Package (auto-generated)
License: Same as PLM_APLIED repository
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROOF_DIR = Path(__file__).resolve().parent

CHAPTERS = [
    "index.html",
    "chapter1.html",
    "chapter2.html",
    "chapter3.html",
    "chapter4.html",
    "chapter5.html",
    "chapter6.html",
    "chapter7.html",
    "appendix.html",
]

OUTPUT_PDF = PROOF_DIR / "PLM_Thesis_Complete.pdf"


def build_combined_html() -> Path:
    """Build a single combined HTML from all chapters for PDF generation."""
    print("  Building combined HTML ...", flush=True)

    css_path = PROOF_DIR / "style.css"
    css_content = css_path.read_text(encoding="utf-8") if css_path.exists() else ""

    parts = []
    for ch in CHAPTERS:
        path = PROOF_DIR / ch
        if not path.exists():
            print(f"    WARNING: {ch} not found, skipping")
            continue
        content = path.read_text(encoding="utf-8")
        body_match = re.search(r"<body[^>]*>(.*?)</body>", content, re.DOTALL)
        body = body_match.group(1) if body_match else content
        parts.append(
            f'<!-- === {ch} === -->\n'
            f'<div class="chapter-section">\n{body}\n</div>\n'
            f'<div style="page-break-after: always;"></div>\n'
        )

    combined = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PLM Comprehensive Thesis - Pi-Lambda-Mu Formalized Mathematical Transform</title>
<style>
{css_content}
@media print {{
    .chapter-section {{ page-break-before: always; }}
    .chapter-section:first-child {{ page-break-before: avoid; }}
    body {{ font-size: 11pt; }}
    pre {{ font-size: 9pt; white-space: pre-wrap; }}
    a {{ color: #000; text-decoration: underline; }}
}}
</style>
<script>
  window.MathJax = {{
    tex: {{ inlineMath: [['$', '$'], ['\\\\(', '\\\\)']], displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']] }},
    svg: {{ fontCache: 'global' }}
  }};
</script>
<script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js" async></script>
</head>
<body>
{''.join(parts)}
</body>
</html>"""

    combined_path = PROOF_DIR / "combined_thesis.html"
    combined_path.write_text(combined, encoding="utf-8")
    print(f"  Combined HTML: {combined_path.name} ({len(parts)} chapters)")
    return combined_path


def try_browser_headless(html_path: Path, output: Path) -> bool:
    """Try Chrome/Edge headless PDF generation (best for MathJax)."""
    browser_path = None

    # Check PATH first
    for name in ["google-chrome", "chromium-browser", "chromium", "msedge", "chrome"]:
        found = shutil.which(name)
        if found:
            browser_path = found
            break

    # Check common Windows locations
    if browser_path is None:
        win_paths = [
            r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"),
        ]
        for p in win_paths:
            if os.path.isfile(p):
                browser_path = p
                break

    if browser_path is None:
        print("  Chrome/Edge/Chromium not found. Skipping.", flush=True)
        return False

    print(f"  Using headless browser: {os.path.basename(browser_path)} ...", flush=True)
    try:
        file_url = html_path.as_uri()
        result = subprocess.run(
            [
                browser_path,
                "--headless",
                "--disable-gpu",
                "--no-sandbox",
                "--run-all-compositor-stages-before-draw",
                "--virtual-time-budget=10000",
                f"--print-to-pdf={output}",
                file_url,
            ],
            capture_output=True, text=True, timeout=120,
        )
        if output.exists() and output.stat().st_size > 1000:
            size_kb = output.stat().st_size / 1024
            print(f"  PDF generated: {output.name} ({size_kb:.0f} KB)", flush=True)
            return True
        else:
            print(f"  Browser PDF failed (empty or too small)", flush=True)
            if result.stderr:
                print(f"    {result.stderr[:300]}", flush=True)
            return False
    except Exception as e:
        print(f"  Browser PDF failed: {e}", flush=True)
        return False


def try_wkhtmltopdf(html_path: Path, output: Path) -> bool:
    """Try using wkhtmltopdf."""
    wk = shutil.which("wkhtmltopdf")
    if wk is None:
        print("  wkhtmltopdf not found. Skipping.", flush=True)
        return False

    print("  Using wkhtmltopdf ...", flush=True)
    try:
        cmd = [
            wk, "--enable-local-file-access", "--print-media-type",
            "--page-size", "A4",
            "--margin-top", "15mm", "--margin-bottom", "15mm",
            "--margin-left", "15mm", "--margin-right", "15mm",
            "--javascript-delay", "5000",
            "--no-stop-slow-scripts",
            str(html_path), str(output),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode == 0 and output.exists():
            size_kb = output.stat().st_size / 1024
            print(f"  PDF generated: {output.name} ({size_kb:.0f} KB)", flush=True)
            return True
        else:
            print(f"  wkhtmltopdf failed: {result.stderr[:300]}", flush=True)
            return False
    except Exception as e:
        print(f"  wkhtmltopdf failed: {e}", flush=True)
        return False


def try_weasyprint(html_path: Path, output: Path) -> bool:
    """Try using weasyprint."""
    try:
        from weasyprint import HTML  # type: ignore
    except ImportError:
        print("  weasyprint not installed. Skipping.", flush=True)
        return False

    print("  Using weasyprint ...", flush=True)
    try:
        HTML(filename=str(html_path), base_url=str(PROOF_DIR)).write_pdf(str(output))
        if output.exists():
            size_kb = output.stat().st_size / 1024
            print(f"  PDF generated: {output.name} ({size_kb:.0f} KB)", flush=True)
            return True
        return False
    except Exception as e:
        print(f"  weasyprint failed: {e}", flush=True)
        return False


def try_reportlab_fallback(output: Path) -> bool:
    """Fallback: create a summary PDF using reportlab."""
    try:
        from reportlab.lib.pagesizes import A4  # type: ignore
        from reportlab.pdfgen.canvas import Canvas  # type: ignore
    except ImportError:
        print("  reportlab not installed. No PDF generated.", flush=True)
        return False

    print("  Using reportlab fallback ...", flush=True)
    c = Canvas(str(output), pagesize=A4)
    width, height = A4
    y = height - 72

    c.setFont("Helvetica-Bold", 18)
    c.drawString(72, y, "PLM Thesis: Pi-Lambda-Mu Formalized Transform")
    y -= 30
    c.setFont("Helvetica", 11)

    lines = [
        "Author: Joshua Wyatt Harris (NetworkArchetype)",
        "",
        "This PDF is a summary generated because no HTML-to-PDF engine was available.",
        "For the full thesis with MathJax equations and SVG charts,",
        "open combined_thesis.html in a browser and Print to PDF.",
        "",
        "PLM Formula: S = ((pi * Y) * (lambda * X)) / (mu * C)",
        "PLM Constant: R = pi * phi / e = 1.8700061336895...",
        "",
        "Verified:",
        "  - 6 algebraic theorems (80-digit precision)",
        "  - Quantum circuit H-Rz(theta)-H via Cirq",
        "  - Cross-language parity (Python + Ruby)",
        "  - Deterministic reproducibility (100+ runs)",
        "  - NP-hard benchmark suite (3-SAT, TSP, Knapsack)",
        "",
        "Chapters included:",
    ]
    for ch in CHAPTERS:
        lines.append(f"  - {ch}")
    lines.extend([
        "",
        "To generate a proper PDF with equations rendered:",
        "  1. Open combined_thesis.html in Chrome/Edge",
        "  2. Press Ctrl+P -> Save as PDF",
        "  Or: pip install weasyprint && python build_pdf.py",
    ])

    for line in lines:
        if y < 72:
            c.showPage()
            y = height - 72
            c.setFont("Helvetica", 11)
        c.drawString(72, y, line)
        y -= 16

    c.save()
    size_kb = output.stat().st_size / 1024
    print(f"  Fallback PDF: {output.name} ({size_kb:.0f} KB)", flush=True)
    return True


def main() -> int:
    print("=" * 72)
    print("  PLM THESIS PDF BUILDER")
    print("=" * 72)
    print()

    # Parse args
    engine = None
    output = OUTPUT_PDF
    for arg in sys.argv[1:]:
        if arg.startswith("--engine="):
            engine = arg.split("=", 1)[1].lower()
        elif arg in ("-o", "--output") or arg.startswith("-o=") or arg.startswith("--output="):
            if "=" in arg:
                output = Path(arg.split("=", 1)[1])

    existing = [ch for ch in CHAPTERS if (PROOF_DIR / ch).exists()]
    print(f"  Found {len(existing)}/{len(CHAPTERS)} HTML chapters")
    print()

    # Step 1: Always build combined HTML
    combined_html = build_combined_html()

    # Step 2: Try PDF engines
    success = False
    if engine:
        if engine == "chrome":
            success = try_browser_headless(combined_html, output)
        elif engine == "wkhtmltopdf":
            success = try_wkhtmltopdf(combined_html, output)
        elif engine == "weasyprint":
            success = try_weasyprint(combined_html, output)
    else:
        success = (
            try_browser_headless(combined_html, output)
            or try_wkhtmltopdf(combined_html, output)
            or try_weasyprint(combined_html, output)
        )

    if not success:
        print()
        print("  No HTML-to-PDF engine succeeded. Trying reportlab fallback ...", flush=True)
        success = try_reportlab_fallback(output)

    print()
    if success and output.exists():
        print(f"  SUCCESS: {output}")
    else:
        print("  NOTE: No PDF engine available. The combined HTML has been created:")
        print(f"    {combined_html}")
        print()
        print("  To create a PDF:")
        print("    1. Open combined_thesis.html in Chrome/Edge")
        print("    2. Press Ctrl+P -> Save as PDF")
        print("  Or install: pip install weasyprint")

    print("-" * 72)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""home.nix içine gömülü bash script'lerini diske çıkarır.

Nix'in `'' … ''` indented-string sözdizimini bilmeden, `text = ''` ile başlayıp
tek başına `''` ile kapanan blokları toplar, Nix kaçışlarını (\\${pkgs.x}/bin/,
''${, '' ) çözer ve bash betiği olarak yazar.

Kullanım:
    python3 scripts/extract-embedded-scripts.py <çıktı-dizini>

Çıktı dizinine yazdığı her betiğin yolunu NUL ayırıcıyla stdout'a basar, böylece
şu şekilde shellcheck'e zincirlenebilir:

    python3 scripts/extract-embedded-scripts.py /tmp/emb \
        | xargs -0 -n1 shellcheck -S warning

Neden var: 2026-10-05'te düzeltilen iki sessiz hata tam olarak bu boşluktan
geçti — (1) Nix'in unescapeStr'ı tanımadığı `\\f` kaçışı `tr -d 'f'` haline
geliyordu, (2) git'in okumadığı MANPAGER ayarlanıyordu. home.nix'e gömülü
script'ler CI'da hiç taranmıyordu.
"""

import os
import re
import sys

# home.nix içinde bash betiği gömülü olan yerler. Satır DÜZENİ (regex) önemli:
# düz string eşleşmesi betiğin İÇİNDE geçen `pgrep -f "hypr/scripts/..."`
# satırlarını da yakalıyor ve bir sonraki bloğu yanlışlıkla çıkarıyordu.
MARKERS = [
    re.compile(r'^\s*"hypr/scripts/[^"]+"\s*=\s*\{'),
    re.compile(r'^\s*home\.file\."[^"]+"\s*=\s*\{'),
]

# `gamemodeNotifyScript = pkgs.writeShellScriptBin "gamemode-notify" ''`
# biçimindedir: `text = ''` YOK, gövde doğrudan atama satırından sonra başlar.
DIRECT_MARKER = re.compile(r'^\s*gamemodeNotifyScript\s*=')

CLOSER = "''"


def extract(lines, index, direct=False):
    """index'teki marker satırından sonraki indented-string gövdesini döndürür."""
    if direct:
        start = index  # gövde, atama satırından hemen sonra başlar
    else:
        start = next(
            (k for k in range(index, len(lines)) if "text = ''" in lines[k]), None
        )
        if start is None:
            return None

    body = []
    for line in lines[start + 1:]:
        if line.strip().startswith(CLOSER):
            break
        body.append(line)

    if not body:
        return None

    # Nix indented-string, gövdedeki ortak girintiyi siler
    indent = min(
        (len(x) - len(x.lstrip()) for x in body if x.strip()), default=0
    )
    text = "\n".join(x[indent:] if x.strip() else "" for x in body)

    # Nix interpolasyonlarını sade kabuk komutlarına indirge
    # Kaynakta shebang '#!${pkgs.bash}/bin/bash' biçimindedir; '#!' zaten
    # satırın başında olduğu için sadece yolu değiştiriyoruz.
    text = text.replace("${pkgs.bash}/bin/bash", "/usr/bin/env bash", 1)
    text = text.replace("${config.home.homeDirectory}", "/home/localhost")
    text = re.sub(
        r"\$\{pkgs\.([\w.-]+)\}/bin/",
        lambda m: m.group(1),
        text,
    )
    # Nix kaçışları: ''${ -> ${ , '' -> boş string
    text = text.replace("''${", "${").replace(CLOSER, "")

    if not text.startswith("#!"):
        text = "#!/usr/bin/env bash\n" + text
    return text


def main():
    if len(sys.argv) != 2:
        sys.stderr.write(__doc__)
        return 2

    outdir = sys.argv[1]
    home_nix = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "nixos",
        "home.nix",
    )
    lines = open(home_nix, encoding="utf-8").read().split("\n")
    os.makedirs(outdir, exist_ok=True)

    count = 0
    def emit(text):
        nonlocal count
        count += 1
        path = os.path.join(outdir, "embedded_%02d.sh" % count)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.chmod(path, 0o755)
        sys.stdout.write(path + "\0")

    # DÜZELTME (2026-10-05): `lines.index(line)` İLK eşleşmeyi döndürür.
    # Aynı marker satırı home.nix içinde iki kez geçerse ikinci betik yanlış
    # bloğu (ilkini) çıkarıyor ya da hiç çıkmıyordu — sessiz ve yanlış.
    # enumerate() gerçek konumu verir; ayrıca aynı satır içeriğinin ikinci
    # kez geçtiği durumda artık doğru bloğu işleriz.
    for index, line in enumerate(lines):
        if DIRECT_MARKER.match(line):
            text = extract(lines, index, direct=True)
            if text:
                emit(text)
            continue

        for marker in MARKERS:
            if not marker.match(line):
                continue
            text = extract(lines, index)
            # Gerçek bash betiği mi? Hepsi shebang ile başlar. MangoHud.conf /
            # lsfg-vk conf.toml gibi yapılandırma dosyaları böyle elenir.
            if text and text.lstrip().startswith("#!"):
                emit(text)
            break
    sys.stderr.write("extracted %d script(s)\n" % count)
    return 0


if __name__ == "__main__":
    sys.exit(main())

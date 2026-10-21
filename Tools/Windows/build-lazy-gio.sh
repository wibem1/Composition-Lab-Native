#!/usr/bin/env bash
set -euo pipefail
# Same GLib source version as the Windows LilyPond 2.24.4 distribution.
git clone --depth 1 --branch 2.72.4 https://github.com/GNOME/glib.git runtime-source
cd runtime-source
test "$(git rev-parse HEAD)" = 6ed6303e40d6eaf80f2acfbfbcadbb169d156e9c
python - <<'PY'
from pathlib import Path
p = Path('gio/giomodule.c')
s = p.read_text()
old = '      gio_win32_appinfo_init (FALSE);'
assert s.count(old) == 1, 'Upstream initializer changed; refusing an unreviewed patch'
s = s.replace(old, '''      /* Composition Lab: a headless engraver does not need file associations.
       * Keep AppInfo lazy; its public entry points already initialize with TRUE.
       * Avoid the unrelated registry/AppX scan racing Guile initialization. */''')
p.write_text(s)
PY
meson setup build --buildtype=release --default-library=shared -Dtests=false -Dlibmount=disabled -Dxattr=false -Dselinux=disabled -Dman=false -Dgtk_doc=false -Dinstalled_tests=false
meson compile -C build -j 4
mkdir -p ../RuntimeCandidate
find build -name '*.dll' -exec cp '{}' ../RuntimeCandidate/ \;
# Include MinGW dependencies, never Windows system DLLs. The complete candidate
# is tested independently; no file in the production bundle is changed here.
for file in /mingw64/bin/libffi-*.dll /mingw64/bin/libpcre-*.dll /mingw64/bin/libintl-*.dll /mingw64/bin/libiconv-*.dll /mingw64/bin/libwinpthread-*.dll /mingw64/bin/libgcc_s_seh-*.dll /mingw64/bin/zlib1.dll; do
  test ! -f "$file" || cp "$file" ../RuntimeCandidate/
done
cp COPYING ../RuntimeCandidate/COPYING-GLib.txt
git diff > ../RuntimeCandidate/lazy-appinfo.patch

# An otherwise identical rebuild separates the patch effect from toolchain or
# dependency changes. Both variants must be measured before drawing conclusions.
cp -r ../RuntimeCandidate ../RuntimeControl
git checkout -- gio/giomodule.c
meson compile -C build -j 4
find build -name '*.dll' -exec cp '{}' ../RuntimeControl/ \;
rm ../RuntimeControl/lazy-appinfo.patch

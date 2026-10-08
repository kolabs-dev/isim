# Bundled fonts

isim renders text with these fonts on every Linux distribution, the way iOS always has its system font, so layout
and pixels do not depend on the host's fonts. Adwaita Sans (derived from Inter) and Adwaita Mono (derived from Iosevka)
from the GNOME project, version 51, under the SIL Open Font License 1.1 (`LICENSE-OFL.txt`). `build.sh` installs
them to `out/share/fonts`; the runtime registers that directory at startup. Host fonts remain the fallback for other
scripts and emoji.

{ stdenv, fetchFromGitHub, python3, gettext, gobject-introspection, wrapGAppsHook, 
glibcLocales
, gtk3, keybinder3, libnotify, libutempter, vte }:

let
  version = "3.6.2";
in python3.pkgs.buildPythonApplication rec {
  name = "guake-${version}";
  format = "other";

  src = fetchFromGitHub {
    owner = "shinedog";
    repo = "guake";
    rev = version;
    sha256 = "654b89715dafe4d0398f5f6e7e1c080a0f6bacf3";
  };

  # Strict deps breaks guake
  # See https://github.com/NixOS/nixpkgs/issues/59930
  # and https://github.com/NixOS/nixpkgs/issues/56943
  strictDeps = false;

  nativeBuildInputs = [ gettext gobject-introspection wrapGAppsHook python3.pkgs.pip glibcLocales ];

  buildInputs = [ gtk3 keybinder3 libnotify python3 vte ];

  propagatedBuildInputs = with python3.pkgs; [ dbus-python pbr pycairo pygobject3 ];

  LC_ALL = "en_US.UTF-8"; # fixes weird encoding error, see https://github.com/NixOS/nixpkgs/pull/38642#issuecomment-379727699

  PBR_VERSION = version; # pbr needs either .git directory, sdist, or env var

  makeFlags = [
    "prefix=$(out)"
  ];

  preFixup = ''
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${stdenv.lib.makeLibraryPath [ libutempter ]}")
  '';

  meta = with stdenv.lib; {
    description = "Drop-down terminal for GNOME";
    homepage = http://guake-project.org;
    license = licenses.gpl2;
    platforms = platforms.linux;
    maintainers = [ maintainers.msteen ];
  };
}

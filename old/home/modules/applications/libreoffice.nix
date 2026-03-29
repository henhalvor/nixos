{ pkgs, ... }:

{
  home.packages = with pkgs; [
    libreoffice
    # Spell checking package
    hunspell
    # Dictionaries for various languages
    hunspellDicts.en-us # English (US)
    hunspellDicts.nb_NO # Norwegian Bokmål
  ];

}

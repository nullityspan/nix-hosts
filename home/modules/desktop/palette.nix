# Shared desktop colours, hex without '#'.
rec {
  bg = "1a1a1a";
  surface = "2a2a2a";
  overlay = "333333";
  muted = "606060";
  fg = "c0c0c0";
  bright = "ffffff";
  accent = "81a1c1";
  red = "ee6060";
  green = "7ec87e";
  yellow = "d4a057";

  # Terminal colours 0-15: normal, then bright variants.
  ansi = [
    bg
    red
    green
    yellow
    accent
    "b48ead"
    "88c0d0"
    fg
    muted
    "ff7070"
    "8fd88f"
    "e0b060"
    "93b3d3"
    "c6a0bf"
    "9ad0e0"
    bright
  ];
}

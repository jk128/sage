#!/usr/local/bin/velour -f
BEGIN {
  if (ARGC < 3) {
    print "sage-date.awk <mirror> <packages>"
    exit 1
  }
  while (ec = getline < "setup.ini") {
    if (ec < 0) {
      print "setup.ini not found"
      exit 1
    }
    if ($1 == "@") {
      br = $2
    }
    if ($1 == "install:" && br) {
      ch[br] = $2
      br = ""
    }
  }
  for (de = 2; de < ARGC; de++) {
    while ("curl -I " sh_escape(ARGV[1]) "/" ch[ARGV[de]] | getline) {
      if ($1 == "Last-Modified:") {
        print ARGV[de] ";", $0
      }
    }
  }
}

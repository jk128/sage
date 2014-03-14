#!/bin/bash

# apt-cyg: install tool for cygwin similar to debian apt-get

# The MIT License (MIT)
# 
# Copyright (c) 2013 Trans-code Design
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# 

# this script requires some packages
if ! type awk bzip2 tar wget xz &>/dev/null
then
  echo You must install wget, tar, gawk, xz and bzip2 to use apt-cyg.
  exit 1
fi

[ $HOSTTYPE = x86_64 ] && ARCH=x86_64 || ARCH=x86

function usage()
{
  echo apt-cyg: Installs and removes Cygwin packages.
  echo '  "apt-cyg install <package names>" to install packages'
  echo '  "apt-cyg remove <package names>" to remove packages'
  echo '  "apt-cyg update" to update setup.ini'
  echo '  "apt-cyg list" to list installed packages'
  echo '  "apt-cyg find <patterns>" to find packages matching patterns'
  echo '  "apt-cyg describe <patterns>" to describe packages matching patterns'
  echo '  "apt-cyg packageof <commands or files>" to locate parent packages'
  echo Options:
  echo '  --mirror, -m <url> : set mirror'
  echo '  --cache, -c <dir>  : set cache'
  echo '  --file, -f <file>  : read package names from file'
  echo '  --noupdate, -u     : don’t update setup.ini from mirror'
  echo '  --help'
  echo '  --version'
}

function version()
{
  echo apt-cyg version 0.59
  echo Written by Stephen Jungels
  echo
  echo 'Copyright (c) 2005-9 Stephen Jungels.  Released under the GPL.'
}

function findworkspace()
{
  # default working directory and mirror
  mirror=http://mirrors.kernel.org/sourceware/cygwin
  cache=/setup
  
  # work wherever setup worked last, if possible
  if [ -e /etc/setup/last-cache ]
  then
    cache=$(cygpath -f /etc/setup/last-cache)
  fi

  if [ -e /etc/setup/last-mirror ]
  then
    mirror=$(</etc/setup/last-mirror)
  fi
  mirrordir=$(sed '
  s / %2f g
  s : %3a g
  ' <<< "$mirror")

  echo Working directory is $cache
  echo Mirror is $mirror
  mkdir -p "$cache/$mirrordir"
  cd "$cache/$mirrordir"
}

function getsetup() 
{
  (( noscripts || noupdate )) && return
  touch setup.ini
  mv setup.ini setup.ini-save
  wget -N $mirror/$ARCH/setup.bz2
  if [ -e setup.bz2 ]
  then
    bunzip2 setup.bz2
    mv setup setup.ini
    echo Updated setup.ini
  else
    wget -N $mirror/$ARCH/setup.ini
    if [ -e setup.ini ]
    then
      echo Updated setup.ini
    else
      mv setup.ini-save setup.ini
      echo Error updating setup.ini, reverting
    fi
  fi
}

function checkpackages()
{
  (( ${#packages} )) && return
  echo Nothing to do, exiting
  exit
}

# process options
dofile=0
noscripts=0
noupdate=0
command=''
file=''
filepackages=''
packages=''

while (( $# ))
do
  case "$1" in

    --mirror | -m)
      echo "$2" > /etc/setup/last-mirror
      shift 2
    ;;

    --cache | -c)
      cygpath -aw "$2" > /etc/setup/last-cache
      shift 2
    ;;

    --noscripts)
      noscripts=1
      shift
    ;;

    --noupdate | -u)
      noupdate=1
      shift
    ;;

    --help)
      usage
      exit 0
    ;;

    --version)
      version
      exit 0
    ;;

    --file | -f)
      if (( ${#2} ))
      then
        file=$2
        dofile=1
        shift
      else
        echo No file name provided, ignoring $1 >&2
      fi
      shift
    ;;

    update | list | find | describe | packageof | install | remove)
      if (( ${#command} ))
      then
        packages+=" $1"
      else
        command=$1
      fi
      shift
    ;;

    *)
      packages+=" $1"
      shift
    ;;

  esac
done

if (( dofile ))
then
  if [ -f "$file" ]
  then
    filepackages+=$(awk '{printf " %s", $0}' "$file")
  else
    echo File $file not found, skipping
  fi
  packages+=" $filepackages"
fi

case "$command" in

  update)
    findworkspace
    getsetup
  ;;

  list)
    echo The following packages are installed: >&2
    awk 'NR>1 && $0=$1' /etc/setup/installed.db
  ;;

  find)
    checkpackages
    findworkspace
    getsetup
    for pkg in $packages
    do
      echo
      echo Searching for installed packages matching $pkg:
      awk 'NR>1 && $1~query && $0=$1' query="$pkg" /etc/setup/installed.db
      echo
      echo Searching for installable packages matching $pkg:
      awk '$1 ~ query && $0 = $1' RS='\n\n@ ' FS='\n' query="$pkg" setup.ini
    done
  ;;

  describe)
    checkpackages
    findworkspace
    getsetup
    for pkg in $packages
    do
      echo
      awk '$1 ~ query {print $0 "\n"}' RS='\n\n@ ' FS='\n' query="$pkg" setup.ini
    done
  ;;

  packageof)
    checkpackages
    for pkg in $packages
    do
      key=$(type -P "$pkg" | sed s./..)
      (( ${#key} )) || key=$pkg
      for manifest in /etc/setup/*.lst.gz
      do
        found=$(gzip -cd $manifest | grep -c "$key")
        if (( found ))
        then
          package=$(sed '
          s,/etc/setup/,,
          s,.lst.gz,,
          ' <<< $manifest)
          echo Found $key in the package $package
        fi
      done
    done
  ;;

  install)
    checkpackages
    findworkspace
    getsetup
    for pkg in $packages
    do

    already=`grep -c "^$pkg " /etc/setup/installed.db`
    if (( already ))
    then
      echo Package $pkg is already installed, skipping
      continue
    fi
    echo
    echo Installing $pkg

    # look for package and save desc file

    mkdir -p "release/$pkg"
    awk '
    $1 == package {
      desc = $0
      px++
    }
    END {
      if (px == 1 && desc) print desc
      else print "Package not found"
    }
    ' RS='\n\n@ ' FS='\n' package="$pkg" setup.ini > "release/$pkg/desc"
    desc=$(<"release/$pkg/desc")
    if [[ $desc = 'Package not found' ]]
    then
      echo Package $pkg not found or ambiguous name, exiting
      rm -r "release/$pkg"
      exit 1
    fi
    echo Found package $pkg

    # download and unpack the bz2 or xz file

    # pick the latest version, which comes first
    install=$(awk '/^install: / {print $2; exit}' "release/$pkg/desc")

    if (( ! ${#install} ))
    then
      echo 'Could not find "install" in package description: obsolete package?'
      exit 1
    fi

    file=`basename $install`
    cd "release/$pkg"
    wget -nc $mirror/$install

    # check the md5
    digest=$(awk '/^install: / {print $4; exit}' desc)
    digactual=$(md5sum $file | awk NF=1)
    if [ $digest != $digactual ]
    then
      echo MD5 sum did not match, exiting
      exit 1
    fi

    echo "Unpacking..."
    tar xvf $file -C / > "/etc/setup/$pkg.lst"
    gzip -f "/etc/setup/$pkg.lst"
    cd ../..

    # update the package database

    awk '
    ins != 1 && pkg < $1 {
      printf "%s %s 0\n", pkg, bz
      ins=1
    }
    1
    END {
      if (ins != 1) printf "%s %s 0\n", pkg, bz
    }
    ' pkg="$pkg" bz=$file /etc/setup/installed.db > /tmp/awk.$$
    mv /etc/setup/installed.db /etc/setup/installed.db-save
    mv /tmp/awk.$$ /etc/setup/installed.db

    # recursively install required packages

    requires=$(awk '
    $0 ~ rq {
      sub(rq, "")
      print
    }
    ' rq='^requires: ' "release/$pkg/desc")
    warn=0
    if (( ${#requires} ))
    then
      echo Package $pkg requires the following packages, installing:
      echo $requires
      for package in $requires
      do
        already=`grep -c "^$package " /etc/setup/installed.db`
        if (( already ))
        then
          echo Package $package is already installed, skipping
          continue
        fi
        apt-cyg --noscripts install $package
        (( $? && warn++ ))
      done
    fi
    if (( warn ))
    then
      echo 'Warning: some required packages did not install, continuing'
    fi

    # run all postinstall scripts

    pis=`ls /etc/postinstall/*.sh 2>/dev/null | wc -l`
    if (( pis && ! noscripts ))
    then
      echo Running postinstall scripts
      for script in /etc/postinstall/*.sh
      do
        $script
        mv $script $script.done
      done
    fi
    echo Package $pkg installed

    done
  ;;

  remove)
    checkpackages
    for pkg in $packages
    do

    already=`grep -c "^$pkg " /etc/setup/installed.db`
    if (( ! already ))
    then
      echo Package $pkg is not installed, skipping
      continue
    fi
    for req in cygwin coreutils gawk bzip2 tar wget bash
    do
      if [[ $pkg = $req ]]
      then
        echo apt-cyg cannot remove package $pkg, exiting
        exit 1
      fi
    done
    if [ ! -e "/etc/setup/$pkg.lst.gz" ]
    then
      echo Package manifest missing, cannot remove $pkg. Exiting
      exit 1
    fi
    echo Removing $pkg

    # run preremove scripts

    if [ -e "/etc/preremove/$pkg.sh" ]
    then
      "/etc/preremove/$pkg.sh"
      rm "/etc/preremove/$pkg.sh"
    fi
    gzip -cd "/etc/setup/$pkg.lst.gz" |
      awk '/[^\/]$/ {print "rm -f \"/" $0 "\""}' | sh
    rm "/etc/setup/$pkg.lst.gz"
    rm -f /etc/postinstall/$pkg.sh.done
    awk '$1 != pkg' pkg="$pkg" /etc/setup/installed.db > /tmp/awk.$$
    mv /etc/setup/installed.db /etc/setup/installed.db-save
    mv /tmp/awk.$$ /etc/setup/installed.db
    echo Package $pkg removed

    done
  ;;

  *)
    usage
  ;;

esac

#! /bin/sh

# pick up the git-ll-cpanm output
progdir="$( dirname "$0" )"
. "$progdir"/cpan-*/perl5.sh

exec perl "$progdir/techtalk-pse.pl" "$@"

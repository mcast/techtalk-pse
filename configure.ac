# Tech Talk PSE
# Copyright (C) 2010 Red Hat Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

AC_INIT([techtalk-pse],[1.0.0])
AM_INIT_AUTOMAKE([foreign])

dnl Check for pod2man and pod2text.
AC_CHECK_PROG([POD2MAN],[pod2man],[pod2man],[no])
test "x$POD2MAN" = "xno" &&
     AC_MSG_ERROR([pod2man must be installed])
AC_CHECK_PROG([POD2TEXT],[pod2text],[pod2text],[no])
test "x$POD2TEXT" = "xno" &&
     AC_MSG_ERROR([pod2text must be installed])

dnl Check for required Perl modules.
missing_perl_modules=no
for pm in Pod::Usage Getopt::Long Glib Gtk2 Gtk2::MozEmbed; do
    AC_MSG_CHECKING([for $pm])
    if ! perl -M$pm -e1 >/dev/null 2>&1; then
        AC_MSG_RESULT([no])
        missing_perl_modules=yes
    else
        AC_MSG_RESULT([yes])
    fi
done
if test "x$missing_perl_modules" = "xyes"; then
    AC_MSG_FAILURE([some Perl modules required to run the program are missing])
fi

AC_CONFIG_FILES([techtalk-pse:techtalk-pse.pl],
                [chmod 0555 techtalk-pse])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT

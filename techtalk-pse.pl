#!/usr/bin/perl -w
# -*- perl -*-
# @configure_input@
#
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

use warnings;
use strict;
use utf8;

use Pod::Usage;
use Getopt::Long;
use Glib qw(TRUE FALSE);
use Gtk2 -init;
use Gtk2::MozEmbed;

=encoding utf8

=head1 NAME

techtalk-pse - superior technical demonstration software

=head1 SYNOPSIS

 cd /path/to/talk/; techtalk-pse

 techtalk-pse /path/to/talk/

=head1 DESCRIPTION

Tech Talk "Platinum Supreme Edition" (PSE) is Linux Presentation
Software designed by technical people to give technical software
demonstrations to other technical people.  It is designed to be simple
to use (for people who know how to use an editor and the command line)
and powerful, so that you can create informative, technically accurate
and entertaining talks and demonstrations.

Tech Talk PSE is good at opening editors at the right place, opening
shell prompts with preloaded history, compiling and running things
during the demonstration, displaying text, photos, figures and video.

Tech Talk PSE is I<bad> at slide effects, chart junk and bullet
points.

This manual page covers all the documentation you will need to use
Tech Talk PSE.  The next section covers running the tool from the
command line.  After that there is a L</TUTORIAL> section to get you
started.  Then there is a detailed L</REFERENCE> section.  Finally
there is a discussion on L<WHAT MAKES A GOOD TALK>.

=head1 RUNNING THE TOOL FROM THE COMMAND LINE

A Tech Talk PSE talk is not a single file, but a directory full of
files.  (If you want to start a new talk, see the L</TUTORIAL> section
below).  To display or run the talk, change into the directory
containing all those files and run the C<techtalk-pse> command:

 cd /path/to/talk/; techtalk-pse

You can also run C<techtalk-pse> without changing directory, instead
specifying the path to the talk:

 techtalk-pse /path/to/talk/

=head2 OPTIONS

=over 4

=cut

my $help;

=item B<--help>

Display brief help and exit.

=cut

my $last;

=item B<--last>

Start at the last slide.

You cannot use this with the B<-n> / B<--start> option.

=cut

my $start;

=item B<-n SLIDE> | B<--start SLIDE>

Start at the named slide.  I<SLIDE> is the shortest unique prefix of
the slide name, so to start at a slide named
I<00010-introduction.html>, you could use I<-n 00010> or I<-n 00010-intro>,
or give the full filename I<-n 00010-introduction.html>.

The default is to start at the first slide in the talk.

=cut

my $splash = 1;

=item B<--no-splash>

Don't display the initial "splash" screen which advertises Tech Talk
PSE to your audience.  Just go straight into the talk.

=cut

my $verbose;

=item B<--verbose>

Display verbose messages, useful for debugging or tracing
what the program is doing.

=cut

my $version;

=item B<--version>

Display version number and exit.

=cut

GetOptions ("help|?" => \$help,
            "last" => \$last,
            "n=s" => \$start,
            "splash!" => \$splash,
            "start=s" => \$start,
            "verbose" => \$verbose,
            "version" => \$version,
    ) or pod2usage (2);

=back

=cut

pod2usage (1) if $help;
if ($version) {
    print "@PACKAGE@ @VERSION@\n";
    exit
}
die "techtalk-pse: cannot use --start and --last options together\n"
    if defined $last && defined $start;

die "techtalk-pse: too many arguments\n" if @ARGV >= 2;

# Locate the talk.
if (@ARGV > 0) {
    my $d = $ARGV[0];
    if (-d $d) {
        chdir $d or die "techtalk-pse: chdir: $d: $!";
    } else {
        # XXX In future allow people to specify an archive and unpack
        # it for them.
        die "techtalk-pse: argument is not a directory"
    }
}

# MozEmbed initialization.
Gtk2::MozEmbed->set_profile_path ("$ENV{HOME}/.@PACKAGE@", "Tech Talk PSE");

# Get the files.
my @files;
my %groups;
sub reread_directory
{
    @files = ();
    %groups = ();

    foreach (glob ("*")) {
        if (/^(\d+)([A-Z])?(?:-.*)\.(html|sh|txt)$/) {
            print STDERR "reading $_\n" if $verbose;

            my $seq = $1;
            my $pos = $2 || "A";
            my $ext = $3;
            warn "techtalk-pse: $_: command file is not executable (+x)\n"
                if $ext eq "sh" && ! -x $_;

            my $h = { name => $_, seq => $1, pos => $2, ext => $3 };
            push @files, $h;

            $groups{$seq} = [] unless exists $groups{$seq};
            push @{$groups{$seq}}, $h;
        } else {
            print STDERR "ignoring $_\n" if $verbose;
        }
    }
}
reread_directory ();
print STDERR "read ", 0+@files, " files\n" if $verbose;
if (@files == 0) {
    warn "techtalk-pse: no files found, continuing anyway ...\n"
}

# Work out what slide we're starting on.
my $current;
if (defined $current) {
    die "start slide not implemented yet XXX"
}
elsif (@files) {
    $current = $files[0];
}
# else $current is undefined

if ($splash) {
    my $w = Gtk2::AboutDialog->new;
    $w->set_authors ("Richard W.M. Jones");
    $w->set_comments (
        "Superior technical demonstration software\n".
        "\n".
        "Keys\n".
        "↑ — Go back one slide\n".
        "↓ — Go forward one slide\n"
        );
    $w->set_program_name ("Tech Talk Platinum Supreme Edition (PSE)");
    $w->set_version ("@VERSION@");
    $w->set_website ("http://people.redhat.com/~rjones");
    $w->set_license ("GNU General Public License v2 or above");
    $w->signal_connect (destroy => sub { Gtk2->main_quit });
    $w->show_all;
    Gtk2->main;
}









1;

=head1 TUTORIAL

=head1 REFERENCE

=head1 WHAT MAKES A GOOD TALK

=head1 SEE ALSO

The Cognitive Style of PowerPoint, Tufte, Edward R.

=head1 AUTHOR

Richard W.M. Jones L<http://people.redhat.com/~rjones/>

=head1 COPYRIGHT

Copyright (C) 2010 Red Hat Inc.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

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

use POSIX qw(setsid);
use Pod::Usage;
use Getopt::Long;
use Cwd qw(getcwd abs_path);
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

my $mozembed;
my $mozembed_first;
my $mozembed_last;

GetOptions ("help|?" => \$help,
            "last" => \$last,
            "mozembed" => \$mozembed,
            "mozembed-first" => \$mozembed_first,
            "mozembed-last" => \$mozembed_last,
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

# Run with --mozembed: see below.
run_mozembed () if $mozembed;

# Normal run of the program.
die "techtalk-pse: too many arguments\n" if @ARGV >= 2;

# Get the true name of the program.
$0 = abs_path ($0);

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

# Get the files.
my @files;
my %files;
sub reread_directory
{
    @files = ();

    my $i = 0;
    foreach (glob ("*")) {
        if (/^(\d+)(?:-.*)\.(html|sh)$/) {
            print STDERR "reading $_\n" if $verbose;

            my $seq = $1;
            my $ext = $2;
            warn "techtalk-pse: $_: command file is not executable (+x)\n"
                if $ext eq "sh" && ! -x $_;

            my $h = { name => $_, seq => $1, ext => $2, i => $i };
            push @files, $h;
            $files{$_} = $h;
            $i++;
        } else {
            print STDERR "ignoring $_\n" if $verbose;
        }
    }

    if (@files > 0) {
        $files[0]->{first} = 1;
        $files[$#files]->{last} = 1;
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
    $w->run;
    print STDERR "calling \$w->destroy on about dialog\n" if $verbose;
    $w->destroy;
}

MAIN: while (1) {
    if (defined $current) {
        my $go = show_slide ($current);
        if (defined $go) {
            print STDERR "go = $go\n" if $verbose;
            last MAIN if $go eq "QUIT";

            my $i = $current->{i};
            print STDERR "i = $i\n" if $verbose;
            $i-- if $go eq "PREV" && $i > 0;
            $i++ if $go eq "NEXT" && $i+1 < @files;
            $current = $files[$i];
        }
    } else {
        print "No slides found.  Press any key to reload directory ...\n";
        $_ = <STDIN>;
    }

    # Reread directory between slides.
    reread_directory ();

    if (defined $current && !exists $files{$current->{name}}) {
        # Current slide was deleted.
        undef $current;
        $current = $files[0] if @files;
    }
}

sub show_slide
{
    my $slide = shift;

    # Display an HTML page.
    if ($slide->{ext} eq "html") {
        # MozEmbed is incredibly crashy, so we run ourself as a
        # subprocess, so when it segfaults we don't care.
        my @cmd = ($0, "--mozembed");
        push @cmd, "--mozembed-first" if exists $slide->{first};
        push @cmd, "--mozembed-last" if exists $slide->{last};
        my $cwd = getcwd;
        my $url = "file://" . $cwd . "/" . $slide->{name};
        push @cmd, $url;
        system (@cmd);
        die "failed to execute subcommand: ", join(" ", @cmd), ": $!\n"
            if $? == -1;
        if ($? & 127) {
            # Subcommand probably segfaulted, just continue to next slide.
            return "NEXT";
        } else {
            my $r = $? >> 8;
            if ($r == 0) {
                return "NEXT";
            } elsif ($r == 1) {
                return "PREV";
            } elsif ($r == 2) {
                return "QUIT";
            }
        }
    }
    # Run a shell command.
    elsif ($slide->{ext} eq "sh") {
        my $pid;
        # http://docstore.mik.ua/orelly/perl/cookbook/ch10_17.htm
        local *run_process = sub {
            $pid = fork ();
            die "fork: $!" unless defined $pid;
            unless ($pid) {
                # Child.
                POSIX::setsid ();
                $ENV{PATH} = ".:$ENV{PATH}";
                exec ($slide->{name});
                die "failed to execute command: ", $slide->{name}, ": $!";
            }
            # Parent returns.
        };
        local *kill_process = sub {
            print STDERR "sending TERM signal to process group $pid\n"
                if $verbose;
            kill "TERM", -$pid;
        };
        run_process ();

        my $r = "NEXT";

        my $w = Gtk2::Window->new ();

        my $s = $w->get_screen;
        $w->set_default_size ($s->get_width, -1);
        $w->move (0, 0);
        $w->set_decorated (0);

        my $bbox = Gtk2::HButtonBox->new ();
        $bbox->set_layout ('start');

        my $bnext = Gtk2::Button->new ("Next slide");
        $bnext->signal_connect (clicked => sub { $r = "NEXT"; $w->destroy });
        $bnext->set_sensitive (!(exists $slide->{last}));
        $bbox->add ($bnext);

        my $bback = Gtk2::Button->new ("Back");
        $bback->signal_connect (clicked => sub { $r = "PREV"; $w->destroy });
        $bback->set_sensitive (!(exists $slide->{first}));
        $bbox->add ($bback);

        my $brestart = Gtk2::Button->new ("Kill & restart");
        $brestart->signal_connect (clicked => sub {
            kill_process ();
            run_process ();
        });
        $bbox->add ($brestart);

        my $bquit = Gtk2::Button->new ("Quit");
        $bquit->signal_connect (clicked => sub { $r = "QUIT"; $w->destroy });
        $bbox->add ($bquit);
        $bbox->set_child_secondary ($bquit, 1);

        $w->add ($bbox);

        $w->signal_connect (destroy => sub {
            Gtk2->main_quit;
            return FALSE;
        });
        $w->show_all ();

        Gtk2->main;

        kill_process ();
        print STDERR "returning r=$r\n" if $verbose;
        return $r;
    }
}

# If invoked with the --mozembed parameter then we just display a
# single page.  This is just to prevent crashes in MozEmbed from
# killing the whole program.
sub run_mozembed
{
    my $r = 0;

    my $w = Gtk2::Window->new ();
    my $vbox = Gtk2::VBox->new ();
    my $moz = Gtk2::MozEmbed->new ();

    my $bbox = Gtk2::HButtonBox->new ();
    $bbox->set_layout ('start');

    $vbox->pack_start ($bbox, 0, 0, 0);
    $vbox->add ($moz);
    $w->fullscreen ();
    #$w->set_default_size (640, 480);
    $w->add ($vbox);

    my $bnext = Gtk2::Button->new ("Next slide");
    $bnext->signal_connect (clicked => sub { $r = 0; $w->destroy });
    $bnext->set_sensitive (!$mozembed_last);
    $bbox->add ($bnext);

    my $bback = Gtk2::Button->new ("Back");
    $bback->signal_connect (clicked => sub { $r = 1; $w->destroy });
    $bback->set_sensitive (!$mozembed_first);
    $bbox->add ($bback);

    my $bquit = Gtk2::Button->new ("Quit");
    $bquit->signal_connect (clicked => sub { $r = 2; $w->destroy });
    $bbox->add ($bquit);
    $bbox->set_child_secondary ($bquit, 1);

    $w->signal_connect (destroy => sub {
        Gtk2->main_quit;
        return FALSE;
    });
    $w->show_all ();

    $moz->load_url ($ARGV[0]);
    Gtk2->main;

    exit $r;
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

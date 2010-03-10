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

# Get the talk directory and set environment variable $talkdir
# which is inherited by all the scripts.
my $talkdir = getcwd;
$ENV{talkdir} = $talkdir;

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
        "Superior technical demonstration software\n"
        );
    $w->set_program_name ("Tech Talk Platinum Supreme Edition (PSE)");
    $w->set_version ("@VERSION@");
    $w->set_website ("http://people.redhat.com/~rjones");
    $w->set_license ("GNU General Public License v2 or above");
    $w->run;
    print STDERR "calling \$w->destroy on about dialog\n" if $verbose;
    $w->destroy;

    # The dialog doesn't really get destroyed here.  We have
    # to add this hack to really destroy it.
    Glib::Idle->add (sub { Gtk2->main_quit; return FALSE; });
    Gtk2->main;
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
        my $url = "file://$talkdir/" . $slide->{name};
        push @cmd, $url;
	print STDERR "running subcommand: ", join (" ", @cmd), "\n"
	    if $verbose;
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
                exec ("./".$slide->{name});
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

=head2 START WRITING A TALK

[Before you start writing your real talk, I urge you to read
L</WHAT MAKES A GOOD TALK> below].

To start your talk, all you have to do is to make a new directory
somewhere:

 mkdir talk
 cd talk

A tech talk consists of HTML files ("slides") and shell scripts.  The
filenames must start with a number, followed optionally by a
description, followed by the extension (C<.html> or C<.sh>).  So to
start our talk with two slides:

 echo "This is the introduction" > 0010-introduction.html
 echo "This is the second slide" > 0020-second.html

To run it, run the command from within the talk directory:

 techtalk-pse

Any other file in the directory is ignored, so if you want to add
Makefiles, version control files etc, just go ahead.

=head2 TIPS FOR WRITING HTML

You may have your own techniques and tools for writing HTML, so
this section is just to share my ideas.  I start every
HTML file with a standard stylesheet and Javascript header:

 <link rel="stylesheet" href="style.css" type="text/css"/>
 <script src="code.js" type="text/javascript"></script>

That just ensures that I can put common styling instructions for all
my slides in a single file (C<style.css>), and I have one place where
I can add all Javascript, if I need to use any (C<code.js>).

=head3 BACKGROUNDS, FONTS AND LOGOS

To add a common background and font size to all slides, put this in
C<style.css>:

 body {
     font-size: 24pt;
     background: url(background-image.jpg) no-repeat;
 }

To add a logo in one corner:

 body {
     background: url(logo.jpg) top right no-repeat;
 }

=head3 SCALING AND CENTERING

Scaling slide text and images so that they appear at the same
proportionate size for any screen resolution can be done using
Javascript.  (See
L<https://developer.mozilla.org/En/DOM/window.innerHeight>).

If you want to center text horizontally, use CSS, eg:

 p.center {
     text-align: center;
 }

To center text vertically, CSS3 is supposed to offer a solution some
time, but while you're waiting for that try
L<http://www.w3.org/Style/Examples/007/center#vertical>.

=head3 PREVIEWING HTML

I find it helpful to have Firefox open to display the HTML files and
styles as I edit them.  Just start firefox in the talk directory:

 firefox file://$(pwd) &

When you edit an HTML file, click the Firefox reload button to
immediately see your changes.

Tech Talk PSE uses Mozilla embedding to display HTML, which uses the
same Mozilla engine as Firefox, so what you should see in Firefox
should be identical to what Tech Talk PSE displays.

=head2 CREATING FIGURES

Use your favorite tool to draw the figure, convert it to an image (in
any format that the Mozilla engine can display) and include it using
an C<E<lt>imgE<gt>> tag, eg:

 <img src="fig1.gif">

Suitable tools include: XFig, GnuPlot, GraphViz, and many TeX tools
such as PicTex and in particular TikZ.

=head2 EMBEDDING VIDEOS, ANIMATIONS, ETC.

Using HTML 5, embedding videos in the browser is easy.  See:
L<https://developer.mozilla.org/En/Using_audio_and_video_in_Firefox>

For animations, you could try L<Haxe|http://haxe.org/> which has a
Javascript back-end.  There are many other possibilities.

If you are B<sure> that the venue will have an internet connection,
why not embed a YouTube video.

=head2 DISPLAYING EXISTING WEB PAGES

Obviously you could just have an HTML file that contains a redirect to
the public web page:

 <meta http-equiv="Refresh" content="0; url=http://www.example.com/">

However if you want your talk to work offline, then it's better to
download the web page in advance, eg. using Firefox's "Save Page As
-E<gt> Web Page, complete" feature, into the talk directory, then
either rename or make a symbolic link to the slide name:

 ln -s "haXe - Welcome to haXe.html" 0010-haxe-homepage.html

=head2 TIPS FOR WRITING SHELL SCRIPTS

Make sure each C<*.sh> file you write is executable, otherwise Tech
Talk PSE won't be able to run it.  (The program gives a warning if you
forget this).

A good idea is to start each script by sourcing some common functions.
All my scripts start with:

 #!/bin/bash -
 source functions

where C<functions> is another file (ignored by Tech Talk PSE) which
contains common functions for setting shell history and starting a
terminal.

In C<functions>, I have:

 # -*- shell-script -*-
 export PS1="$ "
 export HISTFILE=/tmp/history
 rm -f $HISTFILE
 
 add_history ()
 {
     echo "$@" >> $HISTFILE
 }
 
 terminal ()
 {
     exec \
         gnome-terminal \
         --window \
         --geometry=+100+100 \
         --hide-menubar \
         --disable-factory \
         -e '/bin/bash --norc' \
         "$@"
 }

By initializing the shell history, during your talk you can rapidly
recall commands to start parts of the demonstration just by hitting
the Up arrow.  A complete shell script from one of my talks would look
like this:

 #!/bin/bash -
 source functions
 add_history guestfish -i debian.img
 terminal --title="Examining a Debian guest image in guestfish"

This is just a starting point for your own scripts.  You may want to
use a different terminal, such as xterm, and you may want to adjust
terminal fonts.

=head1 REFERENCE

=head2 ORDER OF FILES

Tech Talk PSE displays the slides in the directory in lexicographic
order (the same order as C<LANG=C ls -1>).  Only files matching the
following regexp are considered:

 ^(\d+)(?:-.*)\.(html|sh)$

For future compatibility, you should ensure that every slide has a
unique numeric part (ie. I<don't> have C<0010-aaa.html> and
C<0010-bbb.html>).  This is because in future we want to have the
ability to display multiple files side by side.

Also for future compatibility, I<don't> use file names that have an
uppercase letter immediately after the numeric part.  This is because
in future we want to allow placement hints using filenames like
C<0010L-on-the-left.html> and C<0010R-on-the-right.html>.

=head2 BASE URL AND CURRENT DIRECTORY

The base URL is set to the be the directory containing the talk files.
Thus you should use relative paths, eg:

 <img src="fig1.gif">

You can also place assets into subdirectories, because subdirectories
are ignored by Tech Talk PSE, eg:

 <img src="images/fig1.gif">

When running shell scripts, the current directory is also set to be
the directory containing the talk files, so the same rules about using
relative paths apply there too.

The environment variable C<$talkdir> is exported to scripts and it
contains the absolute path of the directory containing the talk files.
When a script is run, the current directory is the same as
C<$talkdir>, but if your script changes directory (eg. into a
subdirectory containing supporting files) then it can be useful to use
C<$talkdir> to refer back to the original directory.

=head1 WHAT MAKES A GOOD TALK

I like what Edward Tufte writes, for example his evisceration of
PowerPoint use at NASA here:
L<http://www.edwardtufte.com/bboard/q-and-a-fetch-msg?msg_id=0001yB>

However it is sometimes hard to translate his ideas into clear
presentations, and not all of that is the fault of the tools.  Here
are my thoughts and rules on how to deliver a good talk.

B<First, most important rule:> Before you start drawing any slides at
all, write your talk as a short essay.

This is the number one mistake that presenters make, and it is partly
a tool fault, because PowerPoint, OpenOffice, even Tech Talk PSE, all
open up on an initial blank slide, inviting you to write a title and
some bullet points.  If you start that way, you will end up using the
program as a kind of clumsy outlining tool, and then reading that
outline to your audience.  That's boring and a waste of time for you
and your audience.  (It would be quicker for them just to download the
talk and read it at home).

B<Secondly:> How long do you want to spend preparing the talk?  A good
talk, with a sound essay behind it, well thought out diagrams and
figures, and interesting demonstrations, takes many hours to prepare.
How many hours?  I would suggest thinking about how many hours of
effort your audience are putting in.  Even just 20 people sitting
there for half an hour is 10 man-hours of attention, and that is a
very small talk, and doesn't include all the extra time and hassle
that it took to get them all in one place.

I don't think you can get away with spending less than two full days
preparing a talk, if you want to master the topic and draw up accurate
slides.  Steve Jobs is reputed to spend weeks preparing his annual
sales talk to the Apple faithful.

B<Thirdly:> Now that you're going to write your talk as an essay, what
should go in the slides?  I would say that you should consider
delivering the essay, I<not> the slides, to people who don't make the
talk.  An essay can be turned into an article or blog posting, whereas
even "read-out-the-bullet-point" slides have a low information
density, large size, and end-user compatibility problems (*.pptx
anyone?).

What, then, goes on the slides?  Anything you cannot just say:
diagrams, graphs, videos, animations, and of course (only with Tech
Talk PSE!) demonstrations.

B<Lastly:> Once you've got your talk as an essay and slides, practice,
practice and practice again.  Deliver the talk to yourself in the
mirror, to your colleagues.  Practice going backwards and forwards
through the slides, using your actual laptop and the software so you
know what to click and what keys to press.  Partly memorize what you
are going to say (but use short notes written on paper if you need
to).

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

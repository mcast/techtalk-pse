#!/usr/bin/perl -w
# -*- perl -*-
# @configure_input@
#
# Tech Talk PSE
# Copyright (C) 2010-2012 Red Hat Inc.
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
use Gtk2::Gdk::Keysyms;
use Gtk2::WebKit;
use Gnome2::Vte;

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

Tech Talk PSE talks are just directories containing C<*.html>,
C<*.sh> (shell script) and C<*.term> (terminal) files:

 0010-introduction.html
 0500-demonstration.sh
 0600-command-line.term
 9900-conclusion.html

The filenames that Tech Talk PSE considers to be slides have to match
the regular expression:

 ^(\d+)(?:-.*)\.(html|sh|term)$

(any other file or subdirectory is ignored).  Shell scripts and
terminal files I<must> be executable.

=head2 DISPLAYING AN EXISTING TALK

To display or run a talk, change into the directory containing all
those files and run the C<techtalk-pse> command:

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
my $current;
my $pid;
my $pipeline;

&reread_directory ();

print STDERR "read ", 0+@files, " files\n" if $verbose;
if (@files == 0) {
    warn "techtalk-pse: no files found, continuing anyway ...\n"
}

my $w = Gtk2::Window->new ();
my $vbox = Gtk2::VBox->new ();
my $webkit = Gtk2::WebKit::WebView->new ();
my $vte = Gnome2::Vte::Terminal->new ();
my $notebook = Gtk2::Notebook->new ();
my $splash = make_splash_page ();
my $emptylabel = Gtk2::Label->new ();

my $webkitscroll = Gtk2::ScrolledWindow->new ();
$webkitscroll->add ($webkit);
$webkitscroll->set_policy('automatic', 'automatic');

my $webkitpage = $notebook->append_page ($webkitscroll);
my $shpage = $notebook->append_page ($emptylabel);
my $vtepage = $notebook->append_page ($vte);
my $splashpage = $notebook->append_page ($splash);

my ($bbox, $bquit, $breload, $bnext, $bback, $brestart) = make_button_bar ();

$vbox->pack_start($bbox, 0, 0, 0);
$vbox->pack_start($notebook, 1, 1, 0);

$notebook->set_show_tabs(0);
$notebook->set_show_border(0);

# Default font size is almost certainly too small
# for audience to see.
# XXX we should make font size configurable via
# @ARGV.
# XXX any way we can scale WebKit programmatically
# to set base size which CSS is relative to ?
# NB careful setting it too big, because it will
# force a min size on the terminal. Scaling 1.3
# is biggest we can do while fitting 1024x768
my $font = $vte->get_font;
$font->set_size($font->get_size * 1.3);

# When an external command exits, automatically
# go to the next slide
$vte->signal_connect (
    'child-exited' => sub {
	if ($pid) {
	    $pid = 0;
	    &switch_slide("NEXT");
	}
    });

# Exit if the window is closed
$w->signal_connect (
    destroy => sub {
	Gtk2->main_quit;
	return FALSE;
    });

# Handle left/right arrows, page up/down & home/end
# as slide navigation commands. But not when there
# is a shell running
$w->signal_connect (
    'key-press-event' => sub {
	my $src = shift;
	my $ev = shift;

	# If a shell is running, don't trap keys
	if ($pid) {
	    return 0;
	}

	if ($ev->keyval == $Gtk2::Gdk::Keysyms{Right} ||
	    $ev->keyval == $Gtk2::Gdk::Keysyms{Page_Down}) {
	    &switch_slide("NEXT");
	    return 1;
	} elsif ($ev->keyval == $Gtk2::Gdk::Keysyms{Left} ||
		 $ev->keyval == $Gtk2::Gdk::Keysyms{Page_Up}) {
	    &switch_slide("PREV");
	    return 1;
	} elsif ($ev->keyval == $Gtk2::Gdk::Keysyms{Home}) {
	    &switch_slide("FIRST");
	    return 1;
	} elsif ($ev->keyval == $Gtk2::Gdk::Keysyms{End}) {
	    &switch_slide("LAST");
	    return 1;
	} elsif ($ev->keyval == $Gtk2::Gdk::Keysyms{q} ||
		 $ev->keyval == $Gtk2::Gdk::Keysyms{Escape}) {
	    Gtk2->main_quit;
	    return 1;
	}
	return 0;
    });


$w->add ($vbox);

# This allows us to resize the window in window_in_corner().
$w->set_geometry_hints ($w, { min_width => 100 }, qw(min-size));

$w->show_all ();

window_fullscreen ();

&update_slide();

Gtk2->main();

exit 0;

sub reread_directory
{
    @files = ();

    my $i = 0;
    foreach (glob ("*")) {
        if (/^(\d+)(?:-.*)\.(html|sh|term)$/) {
            print STDERR "reading $_\n" if $verbose;

            my $seq = $1;
            my $ext = $2;
            warn "techtalk-pse: $_: command file is not executable (+x)\n"
                if ($ext eq "sh" || $ext eq "term") && ! -x $_;

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

    # Work out what slide we're starting on.
    if (@files && !$current) {
	if ($start) {
	    foreach my $file (@files) {
		if ($file->{name} =~ /^$start/) {
		    $current = $file;
		    last;
		}
	    }
	} elsif ($last) {
	    $current = $files[$#files];
	}
	if (!$current) {
	    $current = $files[0];
	}
    }
}

sub window_fullscreen
{
    $w->set_decorated (0);
    $w->fullscreen ();
    $w->move (0,0);
}

sub window_in_corner
{
    $w->set_decorated (1);
    $w->unfullscreen ();

    my $root = Gtk2::Gdk->get_default_root_window ();
    my ($width, $height) = $root->get_size;

    $w->resize ($width/2, $height/4);
    $w->move ($width/2, 64);
}

sub run_process
{
    $pid = $vte->fork_command("./" . $current->{name}, [], [], undef, 0, 0, 0);
}

sub kill_process
{
    print STDERR "sending TERM signal to process group $pid\n"
	if $verbose;
    kill "TERM", -$pid;

    # Clears out any current displayed text
    $vte->reset(1, 1);
    $vte->set_default_colors();
    $pid = 0;
}

sub switch_slide
{
    my $action = shift;

    window_fullscreen ();

    if ($pid) {
	kill_process ();
    }
    if ($pipeline) {
	$pipeline->set_state('ready');
	$pipeline = undef;
    }
    print STDERR "action = $action\n" if $verbose;

    my $i = defined $current ? $current->{i} : 0;

    print STDERR "i = $i\n" if $verbose;
    if ($action eq "PREV") {
	if (defined $current) {
	    $i--;
	} else {
	    $i = $#files;
	}
    } elsif ($action eq "NEXT") {
	$i++;
    } elsif ($action eq "FIRST") {
	$i = 0;
    } elsif ($action eq "LAST") {
	$i = $#files;
    } elsif ($action =~ /^I_(\d+)$/) {
	$i = $1;
    }

    $i = 0 if $i < 0;
    if ($i > $#files) {
	$current = undef;
    } else {
	$current = $files[$i];
    }

    &update_slide ();

}

sub update_slide
{
    if ($current) {
	# Display an HTML page.
	if ($current->{ext} eq "html") {
	    $notebook->set_current_page ($webkitpage);
	    my $name = $current->{name};
	    my $url = "file://$talkdir/$name";

	    $webkit->load_uri ($url);
	    $webkit->grab_focus ();
	}
	# Run a shell command.
	elsif ($current->{ext} eq "sh") {
            window_in_corner ();

	    $notebook->set_current_page ($shpage);
	    run_process ();
	}
        # Open a VTE terminal.
	elsif ($current->{ext} eq "term") {
	    $notebook->set_current_page ($vtepage);
	    $vte->grab_focus ();
	    run_process ();
	}
    } else {
	$notebook->set_current_page ($splashpage);
    }

    if ($pid) {
	$brestart->show ();
    } else {
	$brestart->hide ();
    }

    if (defined $current) {
	$bquit->hide ();
	$breload->hide ();
	$bnext->set_sensitive (1);
	$bback->set_sensitive (!exists $current->{first});
    } else {
	$bquit->show ();
	if (@files) {
	    $breload->hide ();
	} else {
	    $breload->show ();
	}
	$bnext->set_sensitive (0);
	$bback->set_sensitive (int(@files));
    }
}


sub make_splash_page {
    my $box = Gtk2::VBox->new();

    my $title = Gtk2::Label->new ("<b><span size='x-large'>Tech Talk Platinum Supreme Edition (PSE)</span></b>");
    $title->set_use_markup (1);

    $box->pack_start ($title, 0, 1, 0);

    my $vers = Gtk2::Label->new ("<b><span size='large'>@VERSION@</span></b>");
    $vers->set_use_markup (1);
    $box->pack_start ($vers, 0, 1, 0);

    my $tagline = Gtk2::Label->new ("<i><span size='large'>Superior technical demonstration software</span></i>");
    $tagline->set_use_markup (1);

    $box->pack_start ($tagline, 0, 1, 0);
    $box->pack_start (Gtk2::Label->new (""), 0, 1, 0);
    $box->pack_start (Gtk2::Label->new ("Author: Richard W.M. Jones"), 0, 1, 0);

    my $url = Gtk2::Label->new ("<a href='http://people.redhat.com/~rjones'>http;//people.redhat.com/~rjones/</a>");
    $url->set_use_markup (1);
    $box->pack_start ($url, 0, 1, 0);
    $box->pack_start (Gtk2::Label->new ("GNU General Public License v2 or above"), 0, 1, 0);

    return $box;
}

# Make the standard button bar across the top of the page.
sub make_button_bar
{
    my $bbox = Gtk2::Toolbar->new ();
    $bbox->set_style ("GTK_TOOLBAR_TEXT");

    my $i = 0;

    my $bquit = Gtk2::ToolButton->new (undef, "Quit");
    $bquit->signal_connect (clicked => sub { Gtk2->main_quit });
    $bbox->insert ($bquit, $i++);

    my $breload = Gtk2::ToolButton->new (undef, "Reload");
    $breload->signal_connect (clicked => sub { reread_directory () });
    $bbox->insert ($breload, $i++);

    my $bnext = Gtk2::ToolButton->new (undef, "Next slide");
    $bnext->signal_connect (clicked => sub { &switch_slide ("NEXT") });
    $bbox->insert ($bnext, $i++);

    my $bback = Gtk2::ToolButton->new (undef, "Back");
    $bback->signal_connect (clicked => sub { &switch_slide ("PREV") });
    $bbox->insert ($bback, $i++);

    $bbox->insert (Gtk2::SeparatorToolItem->new (), $i++);

    my $brestart = Gtk2::ToolButton->new (undef, "Kill & restart");
    $brestart->signal_connect (clicked =>
			       sub {
				   kill_process ();
				   run_process ();
			       });
    $bbox->insert ($brestart, $i++);

    my $sep = Gtk2::SeparatorToolItem->new ();
    $sep->set_expand (TRUE);
    $sep->set_draw (FALSE);
    $bbox->insert ($sep, $i++);

    my $optsmenu = Gtk2::Menu->new ();

    my $mfirst = Gtk2::MenuItem->new ("First slide");
    $mfirst->signal_connect (activate => sub { &switch_slide ("FIRST") });
    $mfirst->show ();
    $optsmenu->append ($mfirst);

    my $mlast = Gtk2::MenuItem->new ("Last slide");
    $mlast->signal_connect (activate => sub { &switch_slide ("LAST") });
    $mlast->show ();
    $optsmenu->append ($mlast);

    my $slidesmenu = Gtk2::Menu->new ();
    foreach (@files) {
        my $item = Gtk2::MenuItem->new ($_->{name});
        my $index = $_->{i};
        $item->signal_connect (activate => sub { &switch_slide ("I_$index") });
        $item->set_sensitive ($current->{i} != $index);
        $item->show ();
        $slidesmenu->append ($item);
    }

    my $mslides = Gtk2::MenuItem->new ("Slides");
    $mslides->set_submenu ($slidesmenu);
    $mslides->show ();
    $optsmenu->append ($mslides);

    my $sep2 = Gtk2::SeparatorMenuItem->new ();
    $sep2->show ();
    $optsmenu->append ($sep2);

    my $mscreenshot = Gtk2::MenuItem->new ("Take a screenshot");
    $mscreenshot->signal_connect (activate => sub { screenshot () });
    $mscreenshot->show ();
    $optsmenu->append ($mscreenshot);

    my $sep3 = Gtk2::SeparatorMenuItem->new ();
    $sep3->show ();
    $optsmenu->append ($sep3);

    my $mquit = Gtk2::MenuItem->new ("Quit");
    $mquit->signal_connect (activate => sub { Gtk2->main_quit });
    $mquit->show ();
    $optsmenu->append ($mquit);

    my $moptions = Gtk2::MenuToolButton->new (undef, "Options");
    #$boptions->signal_connect (clicked =>
    #  sub { $optsmenu->popup (undef, undef, undef, undef, ?, ?) } );
    $bbox->insert ($moptions, $i++);
    $moptions->set_menu ($optsmenu);

    return ($bbox, $bquit, $breload, $bnext, $bback, $brestart);
}

# Try running the external "gnome-screenshot" program, if it's
# available, else take a screenshot using gdk routines.
sub screenshot
{
    system ("gnome-screenshot");

    if ($? == -1) {
        # We are going to save the entire screen.
        my $root = Gtk2::Gdk->get_default_root_window ();
        my ($width, $height) = $root->get_size;

        # Create blank pixbuf to hold the image.
        my $gdkpixbuf = Gtk2::Gdk::Pixbuf->new ('rgb',
                                                0, 8, $width, $height);

        $gdkpixbuf->get_from_drawable ($root, $root->get_colormap (),
                                       0, 0, 0, 0, $width, $height);

        my $i = 0;
        $i++ while -f "screenshot$i.png";
        $gdkpixbuf->save ("screenshot$i.png", 'png');
    }

    return FALSE;
}

1;

__END__

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
description, followed by the extension (C<.html>, C<.sh> or C<.term>).
So to start our talk with two slides:

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

Tech Talk PSE uses WebKit embedding to display HTML.  HTML is
standardized enough nowadays that what you see in Firefox and other
browsers should be the same as what Tech Talk PSE displays.
WebKit-based browsers (Chrome, Safari) should be identical.

=head2 CREATING FIGURES

Use your favorite tool to draw the figure, convert it to an image (in
any format that the Mozilla engine can display) and include it using
an C<E<lt>imgE<gt>> tag, eg:

 <img src="fig1.gif">

Suitable tools include: Inkscape, XFig, GnuPlot, GraphViz, and many
TeX tools such as PicTex and in particular TikZ.

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

Make sure each C<*.sh> or C<*.term> file you write is executable,
otherwise Tech Talk PSE won't be able to run it.  (The program gives a
warning if you forget this).

The difference between C<*.sh> (shell script) and C<*.term> (a
terminal script) is that a shell script runs any commands, usually
graphical commands, whereas a terminal script runs in a full screen
terminal.

A good idea is to start each script by sourcing some common functions.
All my scripts start with:

 #!/bin/bash -
 source functions

where C<functions> is another file (ignored by Tech Talk PSE) which
contains common functions for setting shell history and starting a
terminal.

In C<functions>, I have:

 # -*- shell-script -*-
 
 # Place any local environment variables required in 'local'.
 if [ -f local ]; then source local; fi
 
 export PS1="$ "
 
 export HISTFILE=$talkdir/history
 
 rm -f $HISTFILE
 touch $HISTFILE
 
 add_history ()
 {
     echo "$@" >> $HISTFILE
 }
 
 terminal ()
 {
     # Make $HISTFILE unwritable so the shell won't update it
     # when it exits.
     chmod -w $HISTFILE
 
     # Execute a shell.
     bash --norc "$@"
 }

By initializing the shell history, during your talk you can rapidly
recall commands to start parts of the demonstration just by hitting
the Up arrow.  A complete terminal script from one of my talks would
look like this:

 #!/bin/bash -
 source functions
 add_history guestfish -i debian.img
 terminal

This is just a starting point for your own scripts.

=head1 REFERENCE

=head2 ORDER OF FILES

Tech Talk PSE displays the slides in the directory in lexicographic
order (the same order as C<LANG=C ls -1>).  Only files matching the
following regexp are considered:

 ^(\d+)(?:-.*)\.(html|sh|term)$

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
slides.  Steve Jobs was reputed to spend weeks preparing his annual
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

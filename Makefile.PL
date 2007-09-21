#!/usr/bin/perl -w                                         # -*- perl -*-

use strict;

use lib qw( ./lib );
use Config;
use File::Spec::Functions qw( catfile );
use ExtUtils::MakeMaker;
use LaTeX::Driver;
use Cwd;

select STDERR;
$| = 1;
select STDOUT;

our $QUIET  = 0;
our $ACCEPT = 0;
our $WIN32  = ($^O eq 'MSWin32');

#------------------------------------------------------------------------

message(<<EOF);

LaTeX::Driver v$LaTeX::Driver::VERSION
--------------------

LaTeX::Driver runs either the 'latex' or 'pdflatex' command on a LaTeX
document.  If unresolved cross references, bibliographic references or
index definitions are found then 'bibtex' or 'makeindex' will be run
as appropriate and 'latex' or 'pdflatex' re-run as necessary.  The
output will be postprocessed with the 'dvips' and 'ps2pdf' programs if
necessary to create PDF, DVI or PostScript documents.

To use the module you will first need to install LaTeX on your system
and make sure the above programs are available.  Answer the following
questions to confirm their locations, then run 'make', 'make test' and
'make install'.

EOF

#------------------------------------------------------------------------

our $LATEX     = ttprompt('latex path',     find_program($ENV{PATH}, "latex"));
our $PDFLATEX  = ttprompt('pdflatex path',  find_program($ENV{PATH}, "pdflatex"));
our $DVIPS     = ttprompt('dvips path',     find_program($ENV{PATH}, "dvips"));
our $PS2PDF    = ttprompt('ps2pdf path',    find_program($ENV{PATH}, "ps2pdf"));
our $BIBTEX    = ttprompt('bibtex path',    find_program($ENV{PATH}, "bibtex"));
our $MAKEINDEX = ttprompt('makeindex path', find_program($ENV{PATH}, "makeindex"));

fix_path_assignment(catfile('lib','LaTeX','Driver','Paths.pm'), 'latex',     $LATEX);
fix_path_assignment(catfile('lib','LaTeX','Driver','Paths.pm'), 'pdflatex',  $PDFLATEX);
fix_path_assignment(catfile('lib','LaTeX','Driver','Paths.pm'), 'dvips',     $DVIPS);
fix_path_assignment(catfile('lib','LaTeX','Driver','Paths.pm'), 'ps2pdf',    $PS2PDF);
fix_path_assignment(catfile('lib','LaTeX','Driver','Paths.pm'), 'bibtex',    $BIBTEX);
fix_path_assignment(catfile('lib','LaTeX','Driver','Paths.pm'), 'makeindex', $MAKEINDEX);

#------------------------------------------------------------------------

my %opts = (
    'NAME'	       => 'LaTeX-Driver',
    'VERSION_FROM' => 'lib/LaTeX/Driver.pm',
    'PMLIBDIRS'    => [ 'lib' ], 
    'PREREQ_PM'    => { 
    },
    'dist'         => {
        'COMPRESS' => 'gzip',
        'SUFFIX'   => 'gz',
    },
    'clean'        => {
        'FILES'    => join(' ', qw( t/output/test1.pdf 
                                    t/output/test1.ps 
                                    t/output/test1.dvi
                                    t/output/test2 
                                    t/output/test2.pdf 
                                    t/output/test2.ps 
                                    t/output/test2.dvi )),
    },
);

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{ AUTHOR   } = 'Andrew Ford <a.ford@ford-mason.co.uk>';
    $opts{ ABSTRACT } = 'LaTeX Driver',
}

WriteMakefile(%opts);


#------------------------------------------------------------------------
# fix_assignment($file, $find, $fix)
#
# Fixes a variable definition in a file.  e.g. 
# fix_path_assignment('lib/LaTeX/Driver/Paths.pm', '$LATEX', '/path/to/latex')
#------------------------------------------------------------------------

sub fix_path_assignment {
    my ($file, $find, $fix) = @_;
    local *FP;
    local $/ = undef;

    $find = quotemeta($find);

    open(FP, "< $file") || die "$file: $!\n";
    my $text = <FP>;
    close(FP);

    ($text =~ s/^(\s*\$program_path\{\s*${find}\s*\}\s*=\s*)'.*?'/$1'$fix'/m)
    	|| die "$find not found in $file\n";

    open(FP, "> $file") || die "$file: $!\n";
    print FP $text;
    close(FP);
}


#------------------------------------------------------------------------
# find_program($path, $prog)
#
# Find a program, $prog, by traversing the given directory path, $path.
# Returns full path if the program is found.
#
# Written by Craig Barratt, Richard Tietjen add fixes for Win32.
#
# abw changed name from studly caps findProgram() to find_program() :-)
#------------------------------------------------------------------------

sub find_program {
    my($path, $prog) = @_;

    foreach my $dir ( split($Config{path_sep}, $path) ) {
        my $file = File::Spec->catfile($dir, $prog);
        if ( !$WIN32 ) {
            return $file if ( -x $file );
        } else {
            # Windows executables end in .xxx, exe precedes .bat and .cmd
            foreach my $dx ( qw/exe bat cmd/ ) {
                return "$file.$dx" if ( -x "$file.$dx" );
            }
        }
    }
}


#------------------------------------------------------------------------
# message($text)
#
# Print message unless quiet mode.
#------------------------------------------------------------------------

sub message {
    return if $QUIET;
    print @_;
}


#------------------------------------------------------------------------
# ttprompt($message, $default)
#------------------------------------------------------------------------

sub ttprompt {
    my ($msg, $def)=@_;
    my $ISA_TTY = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT)) ; # Pipe?
    my $dispdef = defined $def ? "[$def] " : " ";
    $def = defined $def ? $def : "";
    my $ans = '';
    local $|=1;
    print "$msg $dispdef" unless $QUIET;
    if ($ACCEPT || ! $ISA_TTY) {
        print "$def\n" unless $QUIET;
    }
    else {
        chomp($ans = <STDIN>);
    }
    return ($ans ne '') ? $ans : $def;
}



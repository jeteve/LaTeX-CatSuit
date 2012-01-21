#!/usr/bin/perl -w                                         # -*- perl -*-

use strict;

use Config;
use File::Spec::Functions qw( catfile );
use ExtUtils::MakeMaker;
use Cwd;

select STDERR;
$| = 1;
select STDOUT;

our $QUIET  = 0;
our $ACCEPT = 0;
our $WIN32  = ($^O eq 'MSWin32');
our $MODVERSION = '1.00_01';

#------------------------------------------------------------------------

message(<<EOF);

LaTeX::CatSuit v$MODVERSION
-------------------

LaTeX::CatSuit runs either the 'latex' or 'pdflatex' command on a LaTeX
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
our $BIBTEX    = ttprompt('bibtex path',    find_program($ENV{PATH}, "bibtex"));
our $MAKEINDEX = ttprompt('makeindex path', find_program($ENV{PATH}, "makeindex"));
our $DVIPS     = ttprompt('dvips path',     find_program($ENV{PATH}, "dvips"));
our $DVIPDFM   = ttprompt('dvipdfm path',   find_program($ENV{PATH}, "dvipdfm"));
our $PS2PDF    = ttprompt('ps2pdf path',    find_program($ENV{PATH}, "ps2pdf"));
our $PDF2PS    = ttprompt('pdf2ps path',    find_program($ENV{PATH}, "pdf2ps"));

if (!$LATEX and !$PDFLATEX) {
    my $continue = ttprompt('You don\'t seem to have LaTeX installed.  Continue anyway?', 'N');
    die("Aborting as LaTeX is not installed\n") unless uc($continue) =~ /^Y/;
}

fix_path_assignment(catfile('lib','LaTeX','CatSuit','Paths.pm'), 'latex',     $LATEX);
fix_path_assignment(catfile('lib','LaTeX','CatSuit','Paths.pm'), 'pdflatex',  $PDFLATEX);
fix_path_assignment(catfile('lib','LaTeX','CatSuit','Paths.pm'), 'bibtex',    $BIBTEX);
fix_path_assignment(catfile('lib','LaTeX','CatSuit','Paths.pm'), 'makeindex', $MAKEINDEX);
fix_path_assignment(catfile('lib','LaTeX','CatSuit','Paths.pm'), 'dvips',     $DVIPS);
fix_path_assignment(catfile('lib','LaTeX','CatSuit','Paths.pm'), 'dvipdfm',   $DVIPDFM);
fix_path_assignment(catfile('lib','LaTeX','CatSuit','Paths.pm'), 'ps2pdf',    $PS2PDF);
fix_path_assignment(catfile('lib','LaTeX','CatSuit','Paths.pm'), 'ps2pdf',    $PDF2PS);

#------------------------------------------------------------------------

my %opts = (
    'NAME'	       => 'LaTeX-CatSuit',
    'VERSION_FROM' => 'lib/LaTeX/CatSuit.pm',
    'PMLIBDIRS'    => [ 'lib' ], 
    'PREREQ_PM'    => { 
	'BSD::Resource'    => 0,
	'Class::Accessor'  => 0,
	'Cwd'              => 0,
	'Exception::Class' => 0,
	'File::Slurp'      => 0,
	'File::Spec'       => 0,
	'IO::File'         => 0,
	'Test::More'       => 0,
	'Test::Exception'  => 0,
    },
    'dist'         => {
        'COMPRESS' => 'gzip',
        'SUFFIX'   => 'gz',
    },
);

## Protect against developer version if ExtUtils::MakeMaker
my $EM_VERSION = $ExtUtils::MakeMaker::VERSION;
$EM_VERSION =~ s/_.+//;
if ($EM_VERSION >= '5.43') {
    $opts{ AUTHOR   } = 'Jerome Eteve <jeteve@cpan.org>';
    $opts{ ABSTRACT } = 'LaTeX CatSuit';
    $opts{ LICENCE } = 'perl';
}

WriteMakefile(%opts);


#------------------------------------------------------------------------
# fix_assignment($file, $find, $fix)
#
# Fixes a variable definition in a file.  e.g. 
# fix_path_assignment('lib/LaTeX/CatSuit/Paths.pm', '$LATEX', '/path/to/latex')
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


# sub get_module_version {
#     open(MODULE, catfile('lib','LaTeX','CatSuit.pm'))
# 	or die "cannot find LaTeX::CatSuit module\n";
#     while (<MODULE>) {
# 	return $1 if /VERSION = (\d+\.\d+)/;
#     }
#     return "<unkown version>";
# }

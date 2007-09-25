#========================================================================
#
# LaTeX::Driver
#
# DESCRIPTION
#   Driver module that encapsulates the details of formatting a LaTeX document
#
# AUTHOR
#   Andrew Ford <a.ford@ford-mason.co.uk>  (current maintainer)
#
# COPYRIGHT
#   Copyright (C) 2006-2007 Andrew Ford.   All Rights Reserved.
#   Portions Copyright (C) 1996-2006 Andy Wardley.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
# HISTORY
#   * Extracted from the Template::Latex module (AF, 2007-09-10)
#
#   $Id: Driver.pm 39 2007-09-25 20:08:17Z andrew $
#========================================================================

package LaTeX::Driver;

use strict;
use warnings;

use base 'Class::Accessor';
use Cwd;
use English;
use Exception::Class ( 'LaTeX::Driver::Exception' );
use File::Copy;
use File::Compare;
use File::Path;
use File::Spec;

our $VERSION = 0.05;

__PACKAGE__->mk_accessors( qw( basename basedir basepath options
                               formatter preprocessors postprocessors _program_path
                               maxruns extraruns stats texinputs_path
                               undefined_citations undefined_references
                               labels_changed rerun_required ) );

our $DEBUG; $DEBUG = 0 unless defined $DEBUG;
our $DEBUGPREFIX;


# LaTeX executable paths set at installation time by the Makefile.PL

eval { require LaTeX::Driver::Paths };

our @PROGRAM_NAMES = qw(latex pdflatex bibtex makeindex dvips dvipdfm ps2pdf);
our %program_path;

map { $program_path{$_} = $LaTeX::Driver::Paths::program_path{$_} || "/usr/bin/$_" } @PROGRAM_NAMES;



# valid output formats and program alias

our $DEFAULT_OUTPUTTYPE = 'pdf';

our %OUTPUTTYPE_FORMATTERS  = (
    dvi        => [ 'latex' ],
    ps         => [ 'latex', 'dvips' ],
    pdf        => [ 'pdflatex' ],
    'pdf(dvi)' => [ 'latex', 'dvipdfm' ],
    'pdf(ps)'  => [ 'latex', 'dvips', 'ps2pdf' ],
);

our %FORMATTER_OUTPUTTYPES = (
    latex    => { default => 'dvi',
                  dvi => [],
                  ps  => [ 'dvips' ],
                  pdf => [ 'dvips', 'ps2pdf' ]
    },
    pdflatex => { default => 'pdf',
                  pdf     => [],
    },
);



#------------------------------------------------------------------------
# new(%options)
#
# Constructor for the Latex driver
#------------------------------------------------------------------------

sub new {
    my $class = shift;
    my $options = ref $_[0] ? shift : { @_ };
    my (@postprocessors, %path);

    $DEBUG       = $options->{DEBUG} || 0;
    $DEBUGPREFIX = $options->{DEBUGPREFIX} if exists $options->{DEBUGPREFIX};

    # Sanity check first - check we're running on a supported OS

    $class->throw("not available on $OSNAME")
        if $OSNAME =~ /^(MacOS|os2|VMS)$/i;


    # Examine the options - we need at least a basename to work with

    $class->throw("no basename specified")
        unless $options->{basename};


    # The base directory is either taken from the directory part of
    # the basename or from

    my ($volume, $basedir, $basename) = File::Spec->splitpath($options->{basename});
    $basename =~ s/\.tex$//;
    if ($basedir and $volume) {
        $basedir = File::Spec->catfile($volume, $basedir);
    }
    $basedir ||= $options->{basedir} || getcwd;
    my $basepath = File::Spec->catfile($basedir, $basename);


    # Determine how the document is to be processed

    my $formatter  = $options->{ formatter };
    my $outputtype = $options->{ outputtype } || $options->{ format };

    # outputtype takes precedence - there is a formatter and zero or
    # more postprocessors for each output type; there are also special
    # output types 'pdf(dvi)', 'pdf(ps)' and 'ps(pdf)' that specify
    # alternate routes to generate the output type.  If a formtter is
    # specified with an output type then they must be compatible.

    if ($outputtype) {
        $class->throw("invalid output type: '$outputtype'")
            unless exists $OUTPUTTYPE_FORMATTERS{$outputtype};
        if ($formatter) {
            $class->throw("invalid formatter: '$formatter'")
                unless exists $FORMATTER_OUTPUTTYPES{$formatter};
            my $formatter_attrs = $FORMATTER_OUTPUTTYPES{$formatter};
            $outputtype = $formatter_attrs->{default} if $outputtype eq 'default';
            $class->throw(sprintf("cannot produce output type '%s' with formatter '%s'",
                                  $outputtype, $formatter))
                unless exists $formatter_attrs->{$outputtype};
            @postprocessors = @{$formatter_attrs->{$outputtype}};
        }
        else {
            $outputtype = $DEFAULT_OUTPUTTYPE if $outputtype eq 'default';
            ($formatter, @postprocessors) = @{$OUTPUTTYPE_FORMATTERS{$outputtype}};
        }
    }

    # If a formatter is specified but no outputtype then the output
    # type and postprocessors are taken from the attributes of the
    # formatter.

    elsif ($formatter) {
        $class->throw("invalid formatter: '$formatter'")
            unless exists $FORMATTER_OUTPUTTYPES{$formatter};
        my $formatter_attrs = $FORMATTER_OUTPUTTYPES{$formatter};
        $outputtype         = $formatter_attrs->{default};
        @postprocessors     = @{$formatter_attrs->{$outputtype}};
    }

    # If neither formatter or outputtype is specified then the default
    # output type is selected and the formatter and postprocessors
    # selected from that output type.

    else {
        $outputtype = $DEFAULT_OUTPUTTYPE;
        ($formatter, @postprocessors) = @{$OUTPUTTYPE_FORMATTERS{$outputtype}};
    }


    # Set up a mapping of program name to full pathname.
    # This is initialized from the paths detemined at installation
    # time, but any specified in the paths option override these
    # values.

    $options->{paths} ||= {};

    my $path = {};

    map { $path->{$_} = $program_path{$_}; } @PROGRAM_NAMES;
    map { $path->{$_} = $options->{paths}->{$_}; } keys %{ $options->{paths} };


    # Set up the texinputs path

    my $texinputs_path = $options->{TEXINPUTS} || $options->{texinputs} || [];
    $texinputs_path = [ split(/:/, $texinputs_path) ] unless ref $texinputs_path;

    # construct and return the object

    return $class->SUPER::new({ basename       => $basename,
                                basedir        => $basedir,
                                basepath       => $basepath,
                                options        => $options,
                                maxruns        => $options->{maxruns}   || 10,
                                extraruns      => $options->{extraruns} ||  0,
                                formatter      => $formatter,
                                _program_path  => $path,
                                texinputs_path => join(':', ('.', @$texinputs_path, '')),
                                preprocessors  => [],
                                postprocessors => \@postprocessors,
                                stats          => { formatter_runs => 0,
                                                    bibtex_runs    => 0,
                                                    makeindex_runs => 0 } });
    
}


#------------------------------------------------------------------------
# run()
#
# Constructor for the Latex driver
#------------------------------------------------------------------------

sub run {
    my $self = shift;

    $DEBUG = $self->options->{DEBUG} || 0;

    # Check that the file exists

    $self->throw(sprintf("file %s.tex does not exist", $self->basepath))
        unless -f $self->basepath . '.tex';


    # Run any preprocessors (none specified yet).

    map { $self->$_ } @{$self->preprocessors};


    # Run LaTeX and friends until an error occurs, the document
    # stabilizes, or the maximum number of runs is reached.

    my $maxruns   = $self->maxruns;
    my $extraruns = $self->extraruns;
  RUN:
    foreach my $run (1 .. $maxruns) {

        if ($self->latex_required) {
            $self->run_latex;
        }
        else {
            if ($self->bibtex_required) {
                $self->run_bibtex;
            }
            elsif ($self->makeindex_required) {
                $self->run_makeindex;
            }
            else {
                last RUN unless $extraruns-- > 0;
            }
            $run--;
        }
    }


    # Run any postprocessors (e.g.: dvips, ps2pdf, etc).

    foreach my $postproc (@{$self->postprocessors}) {
        my $method = $postproc;
        if ($self->can($method)) {
            $self->$method();
        }
        else {
            $method = 'run_' . $postproc;
            if ($self->can($method)) {
                $self->$method();
            }
            else {
                $self->throw("cannot find postprocessor $postproc");
            }
        }
    }


    # Return any output

    return 1;
}


#------------------------------------------------------------------------
# run_latex()
#
# Run the latex processor (latex or pdflatex depending on what is configured).
#------------------------------------------------------------------------

sub run_latex {
    my $self = shift;

    my $basename = $self->basename;
    my $exitcode = $self->run_command($self->formatter =>
                                      "\\nonstopmode\\def\\TTLATEX{1}\\input{$basename}");

    $self->stats->{formatter_runs}++;

    # If an error occurred attempt to extract the interesting lines
    # from the log file.  Even without errors the log file may contain
    # interesting warnings indicating that LaTeX or one of its friends
    # must be rerun.

    my $errors = "";
    my $logfile = $self->basepath . ".log";

    if (open(FH, "<", $logfile) ) {
        $self->reset_latex_required;
        my $matched = 0;
        while ( <FH> ) {
            debug($_) if $DEBUG >= 9;
            # TeX errors start with a "!" at the start of the
            # line, and followed several lines later by a line
            # designator of the form "l.nnn" where nnn is the line
            # number.  We make sure we pick up every /^!/ line,
            # and the first /^l.\d/ line after each /^!/ line.
            if ( /^(!.*)/ ) {
                $errors .= $1 . "\n";
                $matched = 1;
            }
            elsif ( $matched && /^(l\.\d.*)/ ) {
                $errors .= $1 . "\n";
                $matched = 0;
            }
            elsif ( /^LaTeX Warning: Reference .*? on page \d+ undefined/ ) {
                $self->undefined_references(1);
            }
            elsif ( /^LaTeX Warning: Citation .* on page \d+ undefined/ ) {
                debug('undefined citations detected') if $DEBUG;
                $self->undefined_citations(1);
            }
            elsif ( /LaTeX Warning: There were undefined references./i ) {
                debug('undefined reference detected') if $DEBUG;
                $self->undefined_references(1)
                    unless $self->undefined_citations;
            }
            elsif ( /No file $basename\.(toc|lof|lot)/i ) {
                debug("missing $1 file") if $DEBUG;
                $self->undefined_references(1);
            }
            elsif ( /^LaTeX Warning: Label\(s\) may have changed./i ) {
                debug('labels have changed') if $DEBUG;
                $self->labels_changed(1);
            }
        }
        close(FH);
    }
    else {
        $errors = "failed to open $logfile for input";
    }

    if ($exitcode or $errors) {
        $self->throw($self->formatter . " exited with errors:\n$errors");
    }
    return;
}

sub reset_latex_required {
    my $self = shift;
    $self->rerun_required(0);
    $self->undefined_references(0);
    $self->labels_changed(0);
    return;
}

sub latex_required {
    my $self = shift;

    my $auxfile = $self->basepath . '.aux';
    return 1
        if $self->undefined_references
        || $self->labels_changed
        || $self->rerun_required
        || ! -f $auxfile;
    return;
}


#------------------------------------------------------------------------
# run_bibtex()
#
# Run bibtex to generate the bibliography
# bibtex reads references from the .aux file and writes a .bbl file
# It looks for .bib file in BIBINPUTS and TEXBIB
# It looks for .bst file in BSTINPUTS
#------------------------------------------------------------------------

sub run_bibtex {
    my $self = shift;

    my $basename = $self->basename;
    my $exitcode = $self->run_command(bibtex => $basename, 'BIBINPUTS');

    $self->stats->{bibtex_runs}++;

    # TODO: extract meaningful error message from .blg file

    $self->throw("bibtex $basename failed ($exitcode)")
        if $exitcode;

    # Make a backup of the citations file for future comparison, reset
    # the undefined citations flag and mark the driver as needing to
    # re-run the formatter.

    my $basepath = $self->basepath;
    copy("$basepath.cit", "$basepath.cbk");

    $self->undefined_citations(0);
    $self->rerun_required(1);
    return;
}


#------------------------------------------------------------------------
# $self->bibtex_required
#
# LaTeX reports 'Citation ... undefined' if it sees a citation
# (\cite{xxx}, etc) and hasn't read a \bibcite{xxx}{yyy} from the aux
# file.  Those commands are written by parsing the bbl file, but will
# not be seen on the run after bibtex is run as the citations tend to
# come before the \bibliography.
#
# The latex driver sets undefined_citations if it sees the message,
# but we need to look at the .aux file and check whether the \citation
# lines match those seen before the last time bibtex was run.  We
# store the citation commands in a .cit file, this is copied to a cbk
# file by the bibtex method once bibtex has been run.  Doing this
# check saves an extra run of bibtex and latex.
#------------------------------------------------------------------------

sub bibtex_required {
    my $self = shift;

    if ($self->undefined_citations) {
        my $auxfile = $self->basepath . ".aux";
        my $citfile = $self->basepath . ".cit";
        my $cbkfile = $self->basepath . ".cbk";
        local(*AUXFH);
        local(*CITFH);

        open(AUXFH, '<', $auxfile) || return;
        open(CITFH, '>', $citfile)
            or $self->throw("failed to open $citfile for output: $!");

        while ( <AUXFH> ) {
            print(CITFH $_) if /^\\citation/;
        }
        close(AUXFH);
        close(CITFH);

        return if -e $cbkfile and (compare($citfile, $cbkfile) == 0);
        return 1;
    }
    return;
}


#------------------------------------------------------------------------
# $self->run_makeindex()
#
# Run makeindex to generate the index
#
# makeindex has a '-s style' option which specifies the style file.
# The environment variable INDEXSTYLE defines the path where the style
# file should be found.
# TODO: sanity check the indexoptions? don't want the caller
# specifying the output index file name as that might screw things up.
#------------------------------------------------------------------------

sub run_makeindex {
    my $self = shift;

    my $basename = $self->basename;
    my @args;
    if (my $stylename = $self->options->{indexstyle}) {
        push @args, "-s", $stylename;
    }
    if (my $index_options = $self->options->{indexoptions}) {
        push @args, $index_options;
    }
    my $exitcode = $self->run_command(makeindex => join(" ", (@args, $basename)));

    $self->stats->{makeindex_runs}++;

    # TODO: extract meaningful error message from .ilg file

    $self->throw("makeindex $basename failed ($exitcode)")
        if $exitcode;


    # Make a backup of the raw index file that was just processed, so
    # that we can determine whether makeindex needs to be rerun later.

    my $basepath = $self->basepath;
    copy("$basepath.idx", "$basepath.ibk");

    $self->rerun_required(1);
    return;
}


#------------------------------------------------------------------------
# $self->makeindex_required()
#
# Determine whether makeindex needs to be run.  Checks that there is a
# raw index file and that it differs from the backup file (if that exists).
#------------------------------------------------------------------------

sub makeindex_required {
    my $self = shift;

    my $basepath = $self->basepath;
    my $raw_index_file = "$basepath.idx";
    my $backup_file    = "$basepath.ibk";

    return unless -e $raw_index_file;
    return if -e $backup_file and (compare($raw_index_file, $backup_file) == 0);
    return 1;
}


#------------------------------------------------------------------------
# $self->run_dvips()
#
# Run dvips to generate PostScript output
#------------------------------------------------------------------------

sub run_dvips {
    my $self = shift;

    my $basename = $self->basename;

    my $exitstatus = $self->run_command(dvips => "$basename -o");

    $self->throw("dvips $basename failed ($exitstatus)")
        if $exitstatus;
    return;
}


#------------------------------------------------------------------------
# $self->run_ps2pdf()
#
# Run ps2pdf to generate PDF from PostScript output
#------------------------------------------------------------------------

sub run_ps2pdf {
    my $self = shift;

    my $basename = $self->basename;

    my $exitstatus = $self->run_command(ps2pdf => sprintf("%s.ps %s.pdf", $basename, $basename));

    $self->throw("ps2pdf $basename failed ($exitstatus)")
        if $exitstatus;
    return;
}


#------------------------------------------------------------------------
# $self->run_command($progname, $config, $dir, $args, $env)
#
# Run a command in the specified directory, setting up the environment
# and allowing for the differences between operating systems.
#------------------------------------------------------------------------

sub run_command {
    my ($self, $progname, $args, $envvars) = @_;

    # get the full path to the executable for this output format
    my $program = $self->program_path($progname)
        || $self->throw("$progname cannot be found, please specify its location");

    my $dir  = $self->basedir;
    my $null = File::Spec->devnull();
    my $cmd;

    $args ||= '';

    # Set up environment variables
    $envvars ||= "TEXINPUTS";
    $envvars = [ $envvars ] unless ref $envvars;
    $envvars = join(" ", ( map { sprintf('%s=%s', $_, $self->texinputs_path) } @{$envvars} ) );


    # Format the command appropriately for our O/S
    if ($OSNAME eq 'MSWin32') {
        # This doesn't set the environment variables yet - what's the syntax?
        $cmd = "cmd /c \"cd $dir && $program $args\"";
    }
    else {
        $args = "'$args'" if $args =~ / \\ /mx;
        $cmd  = "cd $dir; $envvars $program $args 1>$null 2>$null 0<$null";
    }

    debug("running '$program $args'") if $DEBUG;

    my $exitstatus = system($cmd);
    return $exitstatus;
}



#------------------------------------------------------------------------
# $self->cleanup
#
# cleans up the temporary files
#------------------------------------------------------------------------

sub cleanup {
    my $self = shift;
    return;
}


#------------------------------------------------------------------------
# $self->program_path($progname, $optional_value)
#
# 
#------------------------------------------------------------------------

sub program_path {
    my $class_or_self = shift;
    my $href     = ref $class_or_self ? $class_or_self->{_program_path} : \%program_path;
    my $progname = shift;

    return @_ ? ($href->{$progname} = shift) : $href->{$progname};
}


sub latex_path     { my $self = shift; $self->program_path('latex',     @_); }
sub pdflatex_path  { my $self = shift; $self->program_path('pdflatex',  @_); }
sub bibtex_path    { my $self = shift; $self->program_path('bibtex',    @_); }
sub makeindex_path { my $self = shift; $self->program_path('makeindex', @_); }
sub dvips_path     { my $self = shift; $self->program_path('dvips',     @_); }
sub dvipdfm_path   { my $self = shift; $self->program_path('dvipdfm',   @_); }
sub ps2pdf_path    { my $self = shift; $self->program_path('ps2pdf',    @_); }



#------------------------------------------------------------------------
# throw($error)
#
# Throw an error message
#------------------------------------------------------------------------

sub throw {
    my $self = shift;
    $self->cleanup;
    LaTeX::Driver::Exception->throw( error => join('', @_) );
}

sub debug {
    print STDERR $DEBUGPREFIX || "[latex] ", @_;
    print STDERR "\n" unless $_[-1] =~ / \n $ /mx;
    return;
}


1;

__END__

=head1 NAME

LaTeX::Driver - Latex driver

=head1 VERSION

This document describes version 0.04 of C<LaTeX::Driver>.

=head1 SYNOPSIS

    use LaTeX::Driver;

    $drv = LaTeX::Driver->new( basename  => $basename,
                               formatter => 'pdflatex',
                               %other_options );
    $ok    = $drv->run;
    $stats = $drv->stats;
    $drv->cleanup($what);

=head1 DESCRIPTION

The LaTeX::Driver module encapsulates the details of invoking the
Latex programs to format a LaTeX document.  Formatting with LaTeX is
complicated; there are potentially many programs to run and the output
of those programs must be monitored to determine whether further
processing is required.

This module runs the required commands in the directory specified,
either explicitly with the C<dirname> option or implicitly by the
directory part of C<basename>, or in the current directory.  As a
result of the processing up to a dozen or more intermediate files are
created.  These can be removed with the C<cleanup> method.


=head1 SUBROUTINES/METHODS

=over 4

=item C<new(%options)>

This is the constructor method.  It takes the following options:

=over 4

=item C<basename>

The base name of the document to be formatted.  This is mandatory.
The name may include the directory, in which case that is taken as the
base directory (overriding any value of C<basedir>).  If the basename
includes a C<.tex> suffix that is stripped off.

=item C<basedir>

The base directory of the document to be formatted.  If C<basename>
contains a directory part then that is used, if not and C<basedir> is
not specified then the current directory is used.

=item C<formatter>

The name of the formatter to be used (either C<latex> or C<pdflatex>).

=item C<paths>

Specifies a mapping of program names to full pathname as a hash
reference.  These paths override the paths determined at installation
time.

=item C<outputtype>

The type of output required (C<dvi>, C<pdf> or C<ps>)

=item C<maxruns>

The maximum number of runs of the formatter program (defaults to 10).

=item C<extraruns>

The number of additional runs of the formatter program after the document has stabilized.

=item C<indexstyle>

The name of a C<makeindex> index style file that should be passed to
C<makeindex>.

=item C<indexoptions>

Specifies additional options that should be passed to C<makeindex>.
Useful options are: C<-c> to compress intermediate blanks in index
keys, C<-l> to specify letter ordering rather than word ordering,
C<-r> to disable implicit range formation.  Refer to L<makeindex(1)>
for full details.

=back

The constructor performs sanity checking on the options and will die
if the following conditions are detected:

=over 4

=item *

no base name is specified

=item *

an invalid outputtype is specified

=item *

an invalid formatter is specified

=item *

a formatter and an outputtype are specified but the formatter is not
able to generate the specified output type (even with known
postprocessors).

=back

The constructor method returns a driver object.


=item C<run()>

Format the document.


=item C<stats()>

Returns a reference to a hash containing stats about the processing
tht was performed, containing the following items:

=over 4

=item C<formatter_runs>

number of times C<latex> or C<pdflatex> was run

=item C<bibtex_runs>

number of times C<bibtex> was run

=item C<makeindex_runs>

number of times C<makeindex> was run

=back


=item C<cleanup($what)>

Removes temporary intermediate files from the document directory and
resets the stats.

Not yet implemented


=item C<latex_path($opt_value)>

Get or set the path to the C<latex> program.  Can be used as a class
method to set the default path or as an object method to set the path
for that instance of the driver object.

=item C<pdflatex_path($opt_value)>

Get or set the path to the C<pdflatex> program.  

=item C<bibtex_path($opt_value)>

Get or set the path to the C<bibtex> program.  

=item C<dvipdfm_path($opt_value)>

=item C<dvips_path($opt_value)>

=item C<makeindex_path($opt_value)>

=item C<ps2pdf_path($opt_value)>

=item C<program_path($program_name, $opt_value)>


=back


There are a number of other methods that are used internally by the
driver.  Calling these methods directly may lead to unpredictable results.

=over 4

=item C<run_latex>

Runs the formatter (C<latex> or C<pdflatex>.

=item C<latex_required>

=item C<reset_latex_required>

=item C<run_bibtex>

=item C<bibtex_required>

=item C<run_makeindex>

=item C<makeindex_required>

=item C<run_dvips>

=item C<run_ps2pdf>

=item C<run_command>

=item C<throw>

=item C<debug>


=back


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT


=head1 DEPENDENCIES

C<LaTeX::Driver> depends on latex and friends being installed.


=head1 BUGS AND LIMITATIONS

This is beta software - there are bound to be bugs and misfeatures.
If you have any comments about this software I would be very grateful
to hear them; email me at E<lt>a.ford@ford-mason.co.ukE<gt>.

Among the things I am aware of are:

=over 4

=item *

I haven't worked out how I am going to deal with tex-related environment variables.

=back


=head1 FUTURE DIRECTIONS

=over 4

=item *

Look at how path variables could be specified to the filter
(C<TEXINPUTS>, C<TEXINPUTS_latex>, C<TEXINPUTS_pdflatex>,
C<BIBINPUTS>, etc), and how these should interact with the system
paths.

=item *

Investigate pre- and post-processors and other auxilliary programs.

=back


=head1 BACKGROUND

This module has its origins in the original C<latex> filter that was
part of Template Toolkit prior to version 2.16.  That code was fairly
simplistic; it created a temporary directory, copied the source text
to a file in that directory, and ran either C<latex> or C<pdflatex> on
the file once; if postscript output was requested then it would run
C<dvips> after running C<latex>.  This did not cope with documents
that contained forward references, a table of contents, lists of
figures or tables, bibliographies, or indexes.

The current module does not create a temporary directory for
formatting the document; it is given the name and location of an
existing LaTeX document and runs the latex programs in the directory
specified (the Template Toolkit plugin will be modified to set up a
temporary directory, copy the source text in, then run this module,
extract the output and remove the temporary directory).


=head1 INTERNALS

This section is aimed at a technical audience.  It documents the
internal methods and subroutines as a reference for the module's
developers, maintainers and anyone interesting in understanding how it
works.  You don't need to know anything about them to use the module
and can safely skip this section.




=head2 Formatting with LaTeX or PDFLaTeX

LaTeX documents can be formatted with C<latex> or C<pdflatex>; the
former generates a C<.dvi> file (device independent - TeX's native
output format), which can be converted to PostScript or PDF; the
latter program generates PDF directly.

finds inputs in C<TEXINPUTS>, C<TEXINPUTS_latex>, C<TEXINPUTS_pdflatex>, etc


=head2 Generating indexes

The standard program for generating indexes is C<makeindex>, is a
general purpose hierarchical index generator.  C<makeindex> accepts
one or more input files (C<.idx>), sorts the entries, and produces an
output (C<.ind>) file which can be formatted.

The style of the generated index is specified by a style file
(C<.ist>), which is found in the path specified by the C<INDEXSTYLE>
environment variable.

An alternative to C<makeindex> is C<xindy>, but that program is not
widespread yet.


=head2 Generating bibliographies with BiBTeX

BiBTeX generates a bibliography for a LaTeX document.  It reads the
top-level auxiliary file (C<.aux>) output during the running of latex and
creates a bibliograpy file (C<.bbl>) that will be incorporated into the
document on subsequent runs of latex.  It looks up the entries
specified by \cite and \nocite commands in the bibliographic database
files (.bib) specified by the \bibliography commands.  The entries are
formatted according to instructions in a bibliography style file
(C<.bst>), specified by the \bibliographystyle command.

Bibliography style files are searched for in the path specified by the
C<BSTINPUTS> environment variable; for bibliography files it uses the
C<BIBINPUTS> environment variable.  System defaults are used if these
environment variables are not set.


=head2 Running Dvips

The C<dvips> program takes a DVI file produced by TeX and converts it
to PostScript.


=head2 Running ps2pdf

The C<ps2pdf> program invokes Ghostscript to converts a PostScript file to PDF.


=head2 Running on Windows

Commands are executed with C<cmd.exe>.  The syntax is:

   cmd /c "cd $dir && $program $args"

This changes to the specified directory and executes the program
there, without affecting the working directory of the the Perl process.

Need more information on how to set environment variables for the invoked programs.


=head2 Miscellaneous Information

This is a placeholder for information not yet incorporated into the rest of the document.

May want to mention the kpathsea library, the C<kpsewhich> program,
the web2c TeX distribution, TeX live, tetex, TeX on Windows, etc.


=head1 AUTHOR

Andrew Ford E<lt>a.ford@ford-mason.co.ukE<gt>


=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 Andrew Ford.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::Plugin::Latex>, L<latex(1)>, L<makeindex(1)>,
L<bibtex(1)>, L<dvips(1)>, The dvips manual

There are a number of books and other documents that cover LaTeX:

=over 4

=item *

The LaTeX Companion

=item *

Web2c manual

=back

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

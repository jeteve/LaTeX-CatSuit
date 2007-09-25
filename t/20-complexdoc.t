#!/usr/bin/perl
# $Id: 20-complexdoc.t 36 2007-09-25 20:02:12Z andrew $

use strict;
use blib;
use FindBin qw($Bin);
use File::Spec;
use lib ("$Bin/../lib", "$Bin/lib");
use Data::Dumper;

use Test::More tests => 11;

use Test::LaTeX::Driver;
use LaTeX::Driver;

# Debug configuration

my $dont_tidy_up = 1;

# Get the test configuration
my ($testno, $basedir, $docname) = get_test_params();


tidy_directory($basedir, $docname, $debug);

my $drv = LaTeX::Driver->new( basedir     => $basedir,
			      basename    => $docname,
			      outputtype  => 'dvi',
			      TEXINPUTS   => [ "$Bin/testdata/00-common"],
			      DEBUG       => $debug,
			      DEBUGPREFIX => '# [latex]: ' );

diag("Checking the formatting of a complex LaTeX document with references, a bibliography, an index, etc");
isa_ok($drv, 'LaTeX::Driver');
is($drv->basedir, $basedir, "checking basedir");
is($drv->basename, $docname, "checking basename");
is($drv->basepath, File::Spec->catpath('', $basedir, $docname), "checking basepath");
is($drv->formatter, 'latex', "formatter");

ok($drv->run, "formatting $docname");

cmp_ok($drv->stats->{formatter_runs}, '>=',  5, "should have run latex at least five times");
cmp_ok($drv->stats->{formatter_runs}, '<=',  8, "should have run latex not more than eight times");
is($drv->stats->{bibtex_runs},    1, "should have run bibtex once");
is($drv->stats->{makeindex_runs}, 2, "should have run makeindex twice");


test_dvifile($drv, [ "Complex Test Document $testno",	# title
		     'A.N. Other',			# author
		     '20 September 2007',		# date
		     '^Contents$',			# table of contents header
		     'This is a test document with all features.',
		     'The document has 12 pages.',
		     'Forward Reference',		# section title
		     'Here is a reference to page 9.',
		     'File Inclusion',
		     'Here we include another file.',
		     'Included File',			# section title
		     'This is text from an included file.',
		     'Bibliographic Citations',
		     'We reference the Badger book\\[',
		     '^WCC03$',
		     '\\] and the Camel book\\[',
		     '^Wal03$',
		     'Index Term',
		     'Here is the definition of the index term .xyzzy.',
	             '^References$',			# bibliography section heading
		     '^\\s*\\[WCC03\\]$',		# the bibiographic key
		     'Andy Wardley, Darren Chamberlain, and Dave Cross.',
	             '^Index$',				# Index section heading
		     '\\bxyzzy, 8$',			# the index term
		     '\\bxyzzy2, 12$',			# index term from the colophon
		     '11$',			        # page number 11
		     'Colophon$' ] );

tidy_directory($basedir, $docname, $debug)
    unless $dont_tidy_up;

exit(0);

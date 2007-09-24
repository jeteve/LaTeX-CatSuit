#!/usr/bin/perl
# $Id: 14-makeindex.t 22 2007-09-23 20:35:35Z andrew $
#
# Test out invocation of makeindex:
# * Tests the default invocation of makeindex
# * Tests alternate style (replaces comma after index term with colon)
# * Tests index options (uses -l for letter ordering of index entries
 

use strict;
use warnings;

use vars qw($debug $dont_tidy_up $drv);
use blib;
use FindBin qw($Bin);
use File::Spec;
use lib ("$Bin/../lib", "$Bin/lib");
use Data::Dumper;

use Test::More tests => 16;

use Test::LaTeX::Driver;
use LaTeX::Driver;

# Debug configuration
$debug        = 0;
$dont_tidy_up = 0;

# Get the test configuration
my ($testno, $basedir, $docname) = get_test_params();

tidy_directory($basedir, $docname, $debug);

$drv = LaTeX::Driver->new( basedir     => $basedir,
			   basename    => $docname,
			   DEBUG       => $debug,
			   DEBUGPREFIX => '# [latex]: ' );

diag("Checking the formatting of a LaTeX document with an index");
isa_ok($drv, 'LaTeX::Driver');
is($drv->basedir, $basedir, "checking basedir");
is($drv->basename, $docname, "checking basename");
is($drv->basepath, File::Spec->catpath('', $basedir, $docname), "checking basepath");
is($drv->formatter, 'latex', "formatter");

ok($drv->run, "formatting $docname");

is($drv->stats->{formatter_runs}, 2, "should have run latex twice");
is($drv->stats->{bibtex_runs},    0, "should not have run bibtex");
is($drv->stats->{makeindex_runs}, 1, "should have run makeindex once");

test_dvifile($drv, [ "Simple Test Document $testno",	# title
		     'A.N. Other',			# author
		     '20 September 2007',		# date
		     "This is a test document that defines the index terms `seal' and `sea lion'.",
		     "These are the example terms used in the makeindex man page.",
		     '^ 1$',				# page number 1
	             '^Index$',				# Index section heading
		     # word ordering of index entries
		     'sea lion, 1$',			# two-word index term
		     'seal, 1$',			# one-word index term
		     '^ 2$' ] );			# page number 2

tidy_directory($basedir, $docname, $debug);

diag("run again with an explicit index style option");
$drv = LaTeX::Driver->new( basedir      => $basedir,
			   basename     => $docname,
			   indexstyle   => 'testind',
			   DEBUG        => $debug,
			   DEBUGPREFIX  => '# [latex]: ' );

isa_ok($drv, 'LaTeX::Driver');

ok($drv->run, "formatting $docname");

test_dvifile($drv, [ '^Index$',				# Index section heading
		     # word ordering of index entries
		     'sea lion: 1$',			# two-word index term
		     'seal: 1$',			# one-word index term
		     '^ 2$' ] );			# page number 2

tidy_directory($basedir, $docname, $debug);

diag("run again with -l (letter ordering) option");
$drv = LaTeX::Driver->new( basedir      => $basedir,
			   basename     => $docname,
			   indexoptions => '-l',
			   DEBUG        => $debug,
			   DEBUGPREFIX  => '# [latex]: ' );

isa_ok($drv, 'LaTeX::Driver');

ok($drv->run, "formatting $docname");

test_dvifile($drv, [ '^Index$',				# Index section heading
		     # letter ordering of index entries
		     'seal, 1$',			# one-word index term
		     'sea lion, 1$',			# two-word index term
		     '^ 2$' ] );			# page number 2

tidy_directory($basedir, $docname, $debug)
    unless $dont_tidy_up;

exit(0);

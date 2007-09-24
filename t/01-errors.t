#!/usr/bin/perl
# Script to test LaTeX::Driver's error handling
# $Id: 01-errors.t 12 2007-09-21 22:55:28Z andrew $

use strict;
use blib;
use vars qw($testno $basedir $docname $drv $debug $debugprefix $dont_tidy_up);

use FindBin qw($Bin);
use File::Spec;
use lib ("$Bin/../lib", "$Bin/lib");
use Data::Dumper;

use Test::More tests => 11;
use Test::Exception;
use Test::LaTeX::Driver;

use LaTeX::Driver;

# Debug configuration
$debug        = 0;
$dont_tidy_up = 0;
$debugprefix  = '# [latex]: ';


# Get the test configuration
($testno, $basedir, $docname) = get_test_params();


# For some of our tests we need a directory that does not exist, we
# had better make sure that someone hasn't created it.

my $nonexistent_dir = "$basedir/this-directory-should-not-exist";
die "hey, someone created our non-existent directory" if -d $nonexistent_dir;


diag("testing constructor error handling");

dies_ok { LaTeX::Driver->new( DEBUG       => $debug,
			      DEBUGPREFIX => $debugprefix ) } 'no basename specified';
like($@, qr{no basename specified}, 'constructor fails without a basename');

dies_ok { LaTeX::Driver->new( basedir     => $basedir,
			      basename    => $docname,
			      outputtype  => 'tiff',
			      DEBUG       => $debug,
			      DEBUGPREFIX => $debugprefix ) } 'unsupported output type';
like($@, qr{invalid output type}, "'tiff' is not a supported output type");

dies_ok { LaTeX::Driver->new( basedir     => $basedir,
			      basename    => $docname,
			      formatter   => 'pdflatex',
			      outputtype  => 'dvi',
			      DEBUG       => $debug,
			      DEBUGPREFIX => $debugprefix ) } 'incompatible outputtype and formatter';
like($@, qr{cannot produce output type}, "pdflatex cannot generate dvi output");

dies_ok { LaTeX::Driver->new( basedir     => $basedir,
			      basename    => $docname,
			      formatter   => 'troff',
			      DEBUG       => $debug,
			      DEBUGPREFIX => $debugprefix ) } 'invalid formatter';
like($@, qr{invalid formatter}, "'troff' is not (yet?) a valid formatter");

lives_ok { $drv = LaTeX::Driver->new( basedir     => $nonexistent_dir,
				      basename    => $docname,
				      DEBUG       => $debug,
				      DEBUGPREFIX => $debugprefix ) } 'constructor call on non-existent file succeeds';
dies_ok { $drv->run } 'trying to run formatter in non-existent directory';

like($@, qr{file .* does not exist}, "running driver on a non-existent file fails correctly");

exit(0);


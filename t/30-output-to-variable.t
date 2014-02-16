#!/usr/bin/perl
# $Id: 30-output-to-variable.t 62 2007-10-03 14:20:44Z andrew $

use strict;
use blib;
use FindBin qw($Bin);
use File::Spec;
use lib ("$Bin/../lib", "$Bin/lib");
use Data::Dumper;

use Test::More tests => 11;

use Log::Log4perl qw/:easy/;
Log::Log4perl->easy_init($INFO);

use Test::LaTeX::CatSuit;
use LaTeX::CatSuit;

tidy_directory($basedir, $docname, $debug);

my $output;
my $drv = LaTeX::CatSuit->new( source      => $docpath,
			      format      => 'ps',
			      output      => \$output,
			      @DEBUGOPTS );

diag("Checking the formatting of a simple LaTeX document into a variable");
isa_ok($drv, 'LaTeX::CatSuit');
is($drv->basedir, $basedir, "checking basedir");
is($drv->basename, $docname, "checking basename");
is($drv->basepath, File::Spec->catpath('', $basedir, $docname), "checking basepath");
is($drv->formatter, 'latex', "formatter");

ok($drv->run, "formatting $docname");

is($drv->stats->{runs}{latex},         1, "should have run latex once");
is($drv->stats->{runs}{bibtex},    undef, "should not have run bibtex");
is($drv->stats->{runs}{makeindex}, undef, "should not have run makeindex");
is($drv->stats->{runs}{dvips},         1, "should have run dvips once");

like($output, qr/^%!PS/, "got postscript in output string");


tidy_directory($basedir, $docname, $debug)
 unless $no_cleanup;


exit(0);

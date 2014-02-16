#!/usr/bin/perl
# $Id: 31-input-from-variable.t 63 2007-10-03 14:58:55Z andrew $

use strict;
use blib;
use FindBin qw($Bin);
use File::Spec;
use lib ("$Bin/../lib", "$Bin/lib");
use Data::Dumper;

use Test::More tests => 13;

use Log::Log4perl qw/:easy/;
Log::Log4perl->easy_init($FATAL);

use Test::LaTeX::CatSuit;
use LaTeX::CatSuit;
use File::Slurp;

tidy_directory($basedir, $docname, $debug);

my $source = read_file($docpath) or die "cannot read the source data";
my $output;
my $drv = LaTeX::CatSuit->new( source      => \$source,
			      format      => 'ps',
			      output      => \$output,
			      @DEBUGOPTS );

## diag("Checking the formatting of a simple LaTeX document read from a variable");
isa_ok($drv, 'LaTeX::CatSuit');
like($drv->basedir, qr{^/tmp/$LaTeX::CatSuit::DEFAULT_TMPDIR\w+$}, "checking basedir");
is($drv->basename, $LaTeX::CatSuit::DEFAULT_DOCNAME, "checking basename");
is($drv->basepath, File::Spec->catpath('', $drv->basedir, $LaTeX::CatSuit::DEFAULT_DOCNAME), "checking basepath");
is($drv->formatter, 'latex', "formatter");

ok($drv->run, "formatting $docname");

is($drv->stats->{runs}{latex},         1, "should have run latex once");
is($drv->stats->{runs}{bibtex},    undef, "should not have run bibtex");
is($drv->stats->{runs}{makeindex}, undef, "should not have run makeindex");
is($drv->stats->{runs}{dvips},         1, "should have run dvips once");

like($output, qr/^%!PS/, "got postscript in output string");

my $tmpdir = $drv->basedir;
ok(-d $tmpdir, "temporary directory exists before undeffing driver");
undef $drv;
ok(!-d $tmpdir, "temporary directory deleted after undeffing driver");


tidy_directory($basedir, $docname, $debug)
  unless $no_cleanup;


exit(0);

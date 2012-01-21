#!/usr/bin/perl
# $Id: 10-simpledoc.t 62 2007-10-03 14:20:44Z andrew $

use strict;
use blib;
use FindBin qw($Bin);
use File::Spec;
use lib ("$Bin/../lib", "$Bin/lib");
use Data::Dumper;

use Test::More;
use Test::Exception;
use Test::LaTeX::CatSuit;
use LaTeX::CatSuit;

tidy_directory($basedir, $docname, $debug);

my $drv = LaTeX::CatSuit->new( source => $docpath,
                              format => 'dvi',
                              timeout => 1,
                              @DEBUGOPTS );

diag("Checking the timeout feature");
isa_ok($drv, 'LaTeX::CatSuit');
is($drv->basedir, $basedir, "checking basedir");
is($drv->basename, $docname, "checking basename");
is($drv->basepath, File::Spec->catpath('', $basedir, $docname), "checking basepath");
is($drv->formatter, 'latex', "formatter");
diag("Running with a timeout");
dies_ok( sub{ $drv->run; } ,"Running this job dies because of a timeout");
diag("Died after one second");
tidy_directory($basedir, $docname, $debug);


## Now do a test without timeout.
## Note that because we are still in the same process, this also tests that
## the timeout implementation doesnt break the current process.
{
    my $drv = LaTeX::CatSuit->new( source => $docpath,
                                  format => 'dvi',
                                  #timeout => 1,
                                  @DEBUGOPTS );
    diag("Runing without timeout. Should take a while");
    lives_ok( sub{ $drv->run() ; } , "Now runs until the end without crashing with no timeout");
    diag("Took a while");
    test_dvifile($drv, [ "Simple Test Document $testno",	# title
                         'Jerome Eteve',			# author
                         '04 August 2011',		# date
                         'allow a timeout of 1 second' ] );
    tidy_directory($basedir, $docname, $debug);
}


tidy_directory($basedir, $docname, $debug)
    unless $no_cleanup;
done_testing();
exit(0);

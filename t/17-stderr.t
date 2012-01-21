#!/usr/bin/perl
use strict;
use blib;
use FindBin qw($Bin);
use File::Spec;
use File::Slurp;
use File::Which;
use lib ("$Bin/../lib", "$Bin/lib");
use Data::Dumper;

use Test::More;
use Test::Exception;
use Test::LaTeX::CatSuit;
use LaTeX::CatSuit;

tidy_directory($basedir, $docname, $debug);

my $xelatex = 'xelatex';
my $which_xelatex = File::Which::which($xelatex);


SKIP: {
  skip "No ".$xelatex." binary found on system. Skipping tests" , 1  unless $which_xelatex;
  my $drv = LaTeX::CatSuit->new( source => $docpath,
                                format => 'pdf',
                                timeout => 1,
                                paths => { 'pdflatex' => $which_xelatex },
                                capture_stderr => 1,
                                @DEBUGOPTS );
  lives_ok( sub{ $drv->run() ; } , "Runs correctly using xelatex as a pdf producer.");
  ok( -e $drv->std_error_file() , "Ok got a stderror file");
  ok( my $stderr = File::Slurp::read_file( $drv->std_error_file() ) , "There is something in stderror");
  ok( $stderr =~ /\*\* WARNING \*\*/ , "Ok stderr contains warnings");
  tidy_directory($basedir, $docname, $debug);

  ## Now test that running without the option behaves as usual.
  $drv = LaTeX::CatSuit->new( source => $docpath,
                                format => 'pdf',
                                timeout => 1,
                                paths => { 'pdflatex' => $which_xelatex },
                                @DEBUGOPTS );
  lives_ok( sub{ $drv->run() ; } , "Runs correctly using xelatex as a pdf producer.");
  ok( ! -e $drv->std_error_file() , "No std error file!");
  tidy_directory($basedir, $docname, $debug);

};

done_testing();
exit(0);

#!/usr/bin/perl
# $Id: 10-simpledoc.t 62 2007-10-03 14:20:44Z andrew $

use strict;
use blib;
use FindBin qw($Bin);
use File::Spec;
use lib ("$Bin/../lib", "$Bin/lib");
use Data::Dumper;

use Test::More tests => 10;
use Test::LaTeX::CatSuit;
use LaTeX::CatSuit;

use Log::Log4perl qw/:easy/;
Log::Log4perl->easy_init($FATAL);

## Be liberal about Test::Exception
BEGIN {
    eval "use Test::Exception";
    plan skip_all => "Test::Exception needed" if $@;
}

tidy_directory($basedir, $docname, $debug);

## diag("Checking formatting a document with an incorrect latex path");
my $drv = LaTeX::CatSuit->new( source => $docpath,
			      format => 'dvi',
            paths => { 'latex' => '/a/non/existing/command' },
			      @DEBUGOPTS );

isa_ok($drv, 'LaTeX::CatSuit');
is($drv->basedir, $basedir, "checking basedir");
is($drv->basename, $docname, "checking basename");
is($drv->basepath, File::Spec->catpath('', $basedir, $docname), "checking basepath");
is($drv->formatter, 'latex', "formatter");

my $e;
throws_ok( sub { 
             eval{ $drv->run ;};
             if( $e = $@ ){
               die $e;
             }
           }, 'LaTeX::CatSuit::Exception' , "Broken command doesnt run");
like( $e , qr/General command failure executing/ , "The right exception is thrown");

is($drv->stats->{runs}{latex},        1, "should have run latex once");
is($drv->stats->{runs}{bibtex},    undef, "should not have run bibtex");
is($drv->stats->{runs}{makeindex}, undef, "should not have run makeindex");


tidy_directory($basedir, $docname, $debug);

exit(0);

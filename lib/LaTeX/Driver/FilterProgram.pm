#============================================================= -*-perl-*-
#
# LaTeX::Driver::FilterProgram
#
# DESCRIPTION
#   Implements the guts of the latex2xxx filter programs
#
# AUTHOR
#   Andrew Ford    <a.ford@ford-mason.co.uk>
#
# COPYRIGHT
#   Copyright (C) 2007 Andrew Ford.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
# HISTORY
#
#   $Id: Paths.pm 45 2007-09-28 10:33:19Z andrew $
#========================================================================
 
package LaTeX::Driver::FilterProgram;

use strict;
use warnings;
use Carp;

use LaTeX::Driver;
use Getopt::Long;
use File::Slurp;

sub execute {
    my ($class, %options) = @_;
    my ($source, $output, $tt2mode, $debug, @vars, %var);

    GetOptions( "output:s" => \$output,
		"tt2mode"  => \$tt2mode,
		"define:s" => \@vars,
		"debug"    => \$debug );

    if ( @ARGV ) {
	$source = shift @ARGV;
    }
    else {
	my $input = join('', <STDIN>);
	$source = \$input;
    }

    if ($tt2mode) {
	eval {
	    use Template;
	};
	if ($@) {
	    die "Cannot load the Template Toolkit - tt2 mode is unavailable\n";
	}
	if (!ref $source) {
	    $$source = read_file($source);
	}

	foreach (@vars) {
	    my($name, $value) = split(/\s*=\s*/);
	    printf(STDERR "defining %s as '%s'\n", $name, $value) if $debug;
	    $var{$name} = $value;
	} 

	my $input;
	my $tt2  = Template->new({});
	$tt2->process($source, \%var, \$input)
	    or die $tt2->error(), "\n";

	$source = \$input;
    }

    if (!$output) {
	my $tmp;
	$output = \$tmp;
    }
    eval {
	my $drv = LaTeX::Driver->new( source => $source,
				      output => $output,
				      format => $options{format} );
        $drv->run;
    };
    if (my $e = LaTeX::Driver::Exception->caught()) {
        $e->show_trace(1);
#        my $extra = sprintf("\nat %s line %d (%s)\n%s", $e->file, $e->line, $e->package, $e->trace);
        die $e; #sprintf("%s\n%s", "$e", $e->trace);
    }

    print $$output if ref $output;

    return;
}




1;

__END__

=head1 NAME

LaTeX::Driver::FilterProgram

=head1 SYNOPSIS

  use LaTeX::Driver::FilterProgram;
  LaTeX::Driver::FilterProgram->execute(format => $format);

=head1 DESCRIPTION

This module is not intended to be used except by the programs
C<latex2pdf>, C<latex2ps> and C<latex2dvi> that are included in the
LaTeX::Driver distribution.  It implements the guts of those filter
programs.


=head1 AUTHOR

Andrew Ford E<lt>a.ford@ford-mason.co.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 Andrew Ford.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

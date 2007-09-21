#============================================================= -*-perl-*-
#
# LaTeX::Driver::Paths
#
# DESCRIPTION
#   Provides an interface to Latex from the Template Toolkit.
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
#   * Module extracted from Template::Latex module originally by Andy Wardley,
#     September 2007
#
#   $Id: Paths.pm 16 2007-09-21 23:03:09Z andrew $
#========================================================================
 
package LaTeX::Driver::Paths;

use strict;
use warnings;

# LaTeX executable paths set at installation time by the Makefile.PL

our %program_path;

$program_path{latex}     = '/usr/bin/latex';
$program_path{pdflatex}  = '/usr/bin/pdflatex';
$program_path{dvips}     = '/usr/bin/dvips';
$program_path{ps2pdf}    = '/usr/bin/ps2pdf';
$program_path{bibtex}    = '/usr/bin/bibtex';
$program_path{makeindex} = '/usr/bin/makeindex';

1;

__END__

=head1 NAME

LaTeX::Driver::Paths

=head1 DESCRIPTION

This module defines the default paths for the LaTeX executables.  It
is updated by Makefile.PL.

=head1 AUTHOR

Andrew Ford E<lt>a.ford@ford-mason.co.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 Andrew Ford.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

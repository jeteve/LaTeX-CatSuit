#============================================================= -*-perl-*-
#
# LaTeX::CatSuit::Paths
#
# DESCRIPTION
#   Provides an interface to Latex from the Template Toolkit.
#
# ORIGINAL AUTHOR
#   Andrew Ford    <a.ford@ford-mason.co.uk>
#
# COPYRIGHT
#   Copyright (C) 2012 Jerome Eteve. All rights Reserved.
#   Copyright (C) 2007 Andrew Ford.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
# HISTORY
#
#   * Forked by Jerome Eteve from Adrew Ford's LaTeX::Driver, January 2012
#   * Module extracted from Template::Latex module originally by Andy Wardley,
#     September 2007
#
#========================================================================

package LaTeX::CatSuit::Paths;

use strict;
use warnings;

# LaTeX executable paths set at installation time by the Makefile.PL

our %program_path;

$program_path{latex}     = '/usr/bin/latex';
$program_path{pdflatex}  = '/usr/bin/pdflatex';
$program_path{bibtex}    = '/usr/bin/bibtex';
$program_path{makeindex} = '/usr/bin/makeindex';
$program_path{dvips}     = '/usr/bin/dvips';
$program_path{dvipdfm}   = '/usr/bin/dvipdfm';
$program_path{pdf2ps}    = '/usr/bin/pdf2ps';
$program_path{ps2pdf}    = '/usr/bin/pdf2ps';

1;

__END__

=head1 NAME

LaTeX::CatSuit::Paths

=head1 SYNOPSIS

N/A - this file is only intended to be used from C<LaTeX::CatSuit>

=head1 DESCRIPTION

This module defines the default paths for the LaTeX executables.  It
is updated by Makefile.PL.

=head1 AUTHOR

Jerome Eteve E<lt>jeteve@cpan.orgE<gt>
Andrew Ford E<lt>a.ford@ford-mason.co.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 Jerome Eteve. All rights Reserved.
Copyright (C) 2007 Andrew Ford.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

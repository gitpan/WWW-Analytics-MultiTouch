package WWW::Analytics::MultiTouch::Tabular;

use warnings;
use strict;

use IO::File;
use strict;
use warnings;
use Text::Table;
use Text::CSV_XS;
use Spreadsheet::WriteExcel;

use base qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw/format outfile filehandle/);

=head1 NAME

WWW::Analytics::MultiTouch::Tabular - Provides various output formats for writing tabular reports

=head1 SYNOPSIS

   use WWW::Analytics::MultiTouch::Tabular;

   my @reports = (
       { 
       title => "My Title",
       sheetname => "My Sheet Name",
       headers => [ "Column1", "Column2", "Column3" ],
       data => \@data,
       },
       ...
       );
   my $output = WWW::Analytics::MultiTouch::Tabular->new({'format' => 'txt', outfile => $file});
   $output->print(\@reports);
   $output->close();

=head1 DESCRIPTION

Takes a list of reports and outputs them in the specified format (text, csv, or Excel).

=head1 METHODS

=head2 new

    $output = WWW::Analytics::MultiTouch::Tabular->new({format => 'txt', outfile => $file});

OPTIONS

=over 4

=item format

txt, csv or xls.

=item outfile

Name of output file

=back

=cut

sub new
{
    my ($class, $opts) = @_;

    my $self = $class->SUPER::new($opts);
    $self->open;

    return $self;
}

=head2 print

  $output->print(\@reports);

Prints given data in txt, csv, or xls format.

Each item in @reports is a hash containing the following elements:

=over 4

=item title

Report title

=item sheetname

Sheet name, where applicable (as in spreadsheet output).

=item headers

Column headers

=item data

Array of data; each row is a row in the output, with columns corresponding to
the column headers given.

=back

=cut

sub print 
{
    my ($self, $data) = @_;

    local $_ = $self->format;
  SWITCH: {
      m/csv/ && do { $self->csv($data), last SWITCH };
      m/xls/ && do { $self->xls($data), last SWITCH };
      $self->txt($data);
  };
}

=head2 txt

    $output->txt(\@reports);

Generate output in plain text format.

=cut

sub txt
{
    my ($self, $datasets) = @_;
    my $handle = $self->filehandle;
    binmode $handle, ':utf8';
    foreach my $data (@$datasets) {
	my $tab = Text::Table->new(@{$data->{'headers'}});

	$tab->load(@{$data->{'data'}});
	$handle->print($data->{'sheetname'} . "\n") if $data->{'sheetname'};
	$handle->print($data->{'title'} . "\n" . $tab->table);
	$handle->print("\n\n");
	if ($data->{'notes'} && @{$data->{'notes'}}) {
	    $handle->print("$_\n") for @{$data->{'notes'}};
	    $handle->print("\n\n");
	}
    }
}

=head2 csv

    $output->csv(\@reports);

Generate output in CSV format.

=cut


sub csv
{
    my ($self, $datasets) = @_;

    my $handle = $self->filehandle;
#   binmode $handle, ':utf8';

    my $csv = Text::CSV_XS->new( { 'binary'=>1 } );
    foreach my $data (@$datasets) {
	if ($data->{'sheetname'}) {
	    $csv->print($handle, [ $data->{'sheetname'} ]);
	    $handle->print("\n");
	}
	$csv->print($handle, [ $data->{'title'} ]);
	$handle->print("\n");
	$csv->print($handle, $data->{'headers'});
	$handle->print("\n");
	map { $csv->print($handle, $_); $handle->print("\n"); } @{$data->{'data'}};
	$handle->print("\n\n\n");
	if ($data->{'notes'} && @{$data->{'notes'}}) {
	    $handle->print("$_\n") for @{$data->{'notes'}};
	    $handle->print("\n\n\n");
	}
    }
}

=head2 xls

    $output->xls(\@reports);

Generate output in Excel spreadsheet format.

=cut
  
sub xls
{
    my ($self, $worksheets) = @_;

    my $handle = $self->filehandle;
    binmode $handle, ':bytes';
    my $xls = Spreadsheet::WriteExcel->new($handle);

    my $bold = $xls->add_format();

    $bold->set_bold();
    my $tabcount = 0;
    foreach my $tab (@$worksheets) {
	$tabcount++;
	my $name = $tab->{'sheetname'} || "Sheet $tabcount";
	$name = substr($name, 0, 31) if length($name) > 31;
	my $worksheet = $xls->add_worksheet($name);

	# Bug in Spreadsheet::WriteExcel that causes corruption if URL has UTF-8 chars
	$worksheet->add_write_handler(qr{^https?://}, sub {
	    my $worksheet = shift;
	    return $worksheet->write_string(@_);
	});

	my $row = 0;
	my $col = 0;
	my @cols;
	
	$worksheet->write($row++, 0, $tab->{'title'}, $bold);

	$worksheet->write($row++, 0, $tab->{'headers'}, $bold);
	@cols = map { length($_); } @{$tab->{'headers'}};

	if ($tab->{colwise}) {
	    my $max_row = 0;
	    foreach my $column (@{$tab->{'data'}}) {
		$worksheet->write_col($row, $col, $column);
		$max_row = @$column if $max_row < @$column;
		for my $i (0..@$column) {
		    $cols[$col] = length($column->[$i]) if ($column->[$i] && length($column->[$i]) > ($cols[$col] || 0));
		}
		$col++;
	    }
	    $row = $max_row + 1;
	}
	else {
	    foreach my $line (@{$tab->{'data'}}) {
		$worksheet->write($row++, 0, $line);
		for my $i (0..@$line) {
		    $cols[$i] = length($line->[$i]) if ($line->[$i] && length($line->[$i]) > ($cols[$i] || 0));
		}
	    }
	}
	if ($tab->{'notes'} && @{$tab->{'notes'}}) {
	    $row++;
	    $worksheet->write($row++, 0, $_) for @{$tab->{'notes'}};
	}

	for my $i (0..@cols) {
	    $cols[$i] += 2;
	    $cols[$i] = 6 if ($cols[$i] < 6);
	    $cols[$i] = 60 if ($cols[$i] > 60);
	    $worksheet->set_column($i, $i, $cols[$i]);
	}
    }

    $xls->close();
}


=head2 open

=head2 format

=head2 outfile

=head2 filehandle

    $tab->format('csv');
    $tab->outfile("$dir/csv-test.csv");
    $tab->open;

    $tab->open("xls", "$dir/xls-test.xls");

    $tab->filehandle(\*STDOUT);

'open' opens a file for writing.  It is usually not necessary to call 'open' as it 
is implicit in 'new'.  However, if you wish to re-use the object created with
'new' to output a different format or to a different file, then you need to call
open with the new format/file arguments, or after setting the new format and
output file with the format and outfile methods.

If no outfile is provided as an argument or previously set, STDOUT will be used.

As an alternative to 'open', you can set the file handle explicitly using $tab->filehandle().

=cut

sub open
{
    my ($self, $format, $outfile) = @_;
    my $filehandle;

    $self->format($format) if $format;
    $self->outfile($outfile) if $outfile;

    if ($self->outfile) {
	$filehandle = IO::File->new(">" . $self->outfile) or die "Failed to open " . $self->outfile . ": $!";
    }
    else {
	$filehandle = \*STDOUT;
    }

    $self->filehandle($filehandle);
}

=head2 close

Close file

=cut

sub close
{
    my $self = shift;

    if ($self->filehandle) {
	$self->filehandle->close();
	$self->filehandle(undef);
	$self->outfile(undef);
    }
}

=head1 SEE ALSO

Data::Tabular and Data::Tabular::Dumper do a similar thing, but gave me various
issues around encoding and correctly producing output.


=head1 AUTHOR

Jon Schutz, C<< <jon at jschutz.net> >>


=head1 BUGS

Please report any bugs or feature requests to C<bug-www-analytics-multitouch at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Analytics-MultiTouch>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Analytics::MultiTouch


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Analytics-MultiTouch>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Analytics-MultiTouch>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Analytics-MultiTouch>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Analytics-MultiTouch/>

=back


=head1 COPYRIGHT & LICENSE

 Copyright 2010 YourAmigo Ltd.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.

=cut

1;

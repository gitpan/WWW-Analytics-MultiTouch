#! /usr/bin/perl

use strict;
use warnings;

use WWW::Analytics::MultiTouch;
use Getopt::Long;
use Pod::Usage;

my %opts;

GetOptions(\%opts,
	   'user=s',
	   'pass=s',
	   'id=s',
	   'event_category=s',
	   'fieldsep=s',
	   'recsep=s',
	   'patsep=s',
	   'debug',
	   'start_date=s',
	   'end_date=s',
	   'window_length=i',
	   'single_order_model',
	   'channel_pattern=s',
	   'filename=s',
	   'all_touches!',
	   'distributed_touches!',
	   'transactions!',
	   'format=s',
	   'title=s',
	   'help|?',
    ) or pod2usage(2);
pod2usage(1) if $opts{help};

WWW::Analytics::MultiTouch->process(\%opts);

__END__

=head1 NAME

multitouch_report.pl - MultiTouch Analytics Reporting

=head1 SYNOPSIS

multitouch_report --user=USERNAME --pass=PASSWORD --ID=ANALYTICSID --start_date=YYYYMMDD --end_date=YYYYMMDD --filename=FILENAME

=head1 DESCRIPTION

Runs MultiTouch Analytics reports; see L<http://www.multitouchanalytics.com/> for details.

=head2 BASIC OPTIONS

=over 4

=item * --user=USERNAME, --pass=PASSWORD, --id=ANALYTICSID

These are the Google Analytics username, password and reporting ID respectively.
These parameters are mandatory.

=item * --start_date=YYYYMMDD, --end_date=YYYYMMDD

Start and end dates respectively.  The total interval includes both start and
end dates.  Date format is YYYY-MM-DD or YYYYMMDD.

=item * --filename=FILENAME

Name of file in which to save reports.  If not specified, output is sent to the
screen.  The filename extension, if given, is used to determine the file format,
which can be xls, csv or txt.

=back

=head2 REPORT OPTIONS

=over 4

=item * title

Title to insert into reports.

=item * all_touches

If set, the generated report includes the all-touches report; enabled by
default.  The all-touches report shows, for each channel, the total number of
transactions and the total revenue amount in which that channel played a role.
Since multiple channels may have contributed to each transaction, the total of
all transactions across all channels will exceed the actual number of
transactions.

=item * distributed_touches

If set, the generated report includes the distributed-touches report; enabled by
default.  The distributed-touches report shows, for each channel, a number of
transactions and revenue amount in proportion to the number of touches for that
channel.  Since each individual transaction is distributed across the
contributing channels, the total of all transactions (revenue) across all
channels will equal the actual number of transactions (revenue).

=item * transactions

If set, the generated report includes transactions report; enabled by default.
The transactions report lists each transaction and the channels that contributed
to it. 

=item * --window_length=DAYS

The analysis window length, in days.  Only touches this many days prior to any
given order will be included in the analysis.

=item * --single_order_model

If set, any touch is counted only once, toward the next order only; subsequent
repeat orders do not include touches prior to the initial order.

=item * --channel_pattern=PATTERN

Each "channel" is derived from the Google source (source), Google medium (med)
and a subcategory (subcat) field that can be set in the javascript calls, joined
using the pattern separator patsep (defined in L<new>, default '-').  

For example, the source might be 'yahoo' or 'google' and the medium 'organic' or
'cpc'.  To see a report on channels yahoo-organic, google-organic, google-cpc
etc, the channel pattern would be 'source-med'.  To see the report just at the
search engine level, channel pattern would be 'source', and to see the report
just at the medium level, the channel pattern would be 'med'.

Arbitrary ordering is permissible, e.g. med-subcat-source.

The default channel pattern is 'source-med-subcat'.

=back

=head2 ADVANCED OPTIONS

=over 4

=item * --patsep=C

The pattern separator for turning source, medium and subcategory information
into a "channel" identifier.  See the C<channel_pattern> option for more
information.  Defaults to '-'.

=item * --format=FORMAT

May be set to xls, csv or txt to specify Excel, CSV and Text format output
respectively.  The filename extension takes precedence over this parameter.

=item * --event_category=CATEGORY

The name of the event category used in Google Analytics to store multi-touch
data.  Defaults to 'multitouch' and only needs to be changed if the equivalent
variable in the associated javascript library has been customised.

=item * --fieldsep=C, --recsep=C

Field and record separators for stored multi-touch data.  These default to '!'
and '*' respectively and only need to be changed if the equivalent variables in
the associated javascript library has been customised.

=item * --debug

Enable debug output.

=back

=head1 RELATED INFORMATION

See L<http://www.multitouchanalytics.com> for further details.

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

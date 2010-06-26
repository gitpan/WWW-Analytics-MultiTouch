package WWW::Analytics::MultiTouch;

use warnings;
use strict;
use Net::Google::Analytics;
use Net::Google::AuthSub;
use DateTime;
use Data::Dumper;
use Params::Validate;
use List::Util qw/sum/;

use WWW::Analytics::MultiTouch::Tabular;

our $VERSION = '0.03';


sub new {
    my $class = shift;

    my %params = validate(@_, { user => 1,
				pass => 1,
				id => 1,
				event_category => { default => 'multitouch' },
				fieldsep => { default => '!' },
				recsep => { default => '*' },
				patsep => { default => '-' },
				debug => { default => 0 },
			  });
    my $self = bless \%params, ref $class || $class;

    return $self;
}

sub get_data {
    my $self = shift;
    my %params = validate(@_, { start_date => 0,
				end_date => 0,
			  });

    unless (exists $self->{analytics}) {
	my $auth = Net::Google::AuthSub->new(service => 'analytics');
	my $response = $auth->login($self->{user}, $self->{pass});

	die "Login failed: " . $response->error . "\n" unless $response->is_success;

	$self->{analytics} = Net::Google::Analytics->new();
	$self->{analytics}->auth_params($auth->auth_params);
    }
    my $data_feed = $self->{analytics}->data_feed;
    my $req = $data_feed->new_request();
    $req->ids("ga:" . $self->{id});
    $req->dimensions('ga:eventCategory,ga:eventAction,ga:eventLabel');
    $req->metrics('ga:totalEvents');
    $req->sort('ga:eventAction');
    $req->filters('ga:eventCategory==' . $self->{event_category});

    my $start_date = _to_date_time($params{start_date});
    my $end_date = _to_date_time($params{end_date});

    my %data;
    while (DateTime->compare($start_date, $end_date) <= 0) {
	my $ymd = $start_date->ymd('-');
	$self->_debug("Processing $ymd\n");
	$req->start_date($ymd);
	$req->end_date($ymd);
	my $res = $data_feed->retrieve($req);
	die $res->message unless $res->is_success;
	for my $entry (@{$res->entries}) {
	    my $metrics = $entry->metrics;
	    my $dims = $entry->dimensions;
	    my %names = map { $dims->[$_]->name => $_ } (0 .. @$dims - 1);
	    $data{$dims->[$names{'ga:eventAction'}]->value} = [ $ymd, $self->_split_events($dims->[$names{'ga:eventLabel'}]->value) ];
	}
	$start_date->add(days => 1);
    }

    $self->{current_data} = { start_date => $start_date,
			      end_date => $end_date,
			      transactions => \%data,
    };
}

sub _to_date_time {
    my $date = shift;
    
    if ($date) {
	my ($y, $m, $d) = ( $date =~ m/^(\d{4})-?(\d{2})-?(\d{2})/ );
	die "Invalid date format: $date\n" if ! defined $d;
	return DateTime->new(year => $y, month => $m, day => $d);
    }
    return DateTime->today;
}

sub _split_events {
    my ($self, $events) = @_;

    return unless $events;
    my $rs = $self->{recsep};
    my $fs = $self->{fieldsep};
    my @events = split(/\Q$rs\E/, $events);
    my @rec = map { [ split(/\Q$fs\E/, $_) ] } @events;

    return @rec;
}

sub summarise {
    my $self = shift;

    my %params = validate(@_, { window_length =>  { default => 45 },
				single_order_model => 0,
				channel_pattern => { default => join($self->{patsep}, qw/source med subcat/) },
			  });
    my $patsubst = $self->_compile_channel_pattern($params{channel_pattern});
    my $dt = $params{window_length} * 24 * 3600;

    my %distr_touches;
    my %all_touches;
    my @trans;
    # Each event has category 'multitouch', action TIDtid, label ORDER*TOUCH*TOUCH...
    # Each order is of format __ORD!tid!rev!time
    # Each touch is of format source!medium!subcat!time
    for my $tid (keys %{$self->{current_data}->{transactions}}) {
	my $rec = $self->{current_data}->{transactions}->{$tid};
	my $order = $rec->[1];
	if (! ($order->[0] eq '__ORD' 
	       && 'TID' . $order->[1] eq $tid 
	       && $order->[3] =~ m/^\d+$/)) {
	    $self->_debug("Bad record for TID $tid: no __ORD. " . Dumper($rec));
	    next;
	}
	# Set window start based on browser timestamps
	my $window_start = $order->[3] - $dt;
	my %touches;
	for my $entry (@$rec[2 .. @$rec - 1]) {
	    if (@$entry != 4) {
		$self->_debug("Bad record for TID $tid: invalid entry. " . Dumper($entry));
		next;
	    }
	    last if $entry->[3] < $window_start;
	    if ($entry->[0] =~ m/__ORD/) {
		last if $params{single_order_model};
		next;
	    }
	    my $channel = join($self->{patsep}, map { $entry->[$_] || '(none)' } @$patsubst );

	    $touches{$channel}{count}++;
	    $touches{$channel}{transactions} = 1;
	    $touches{$channel}{revenue} = $self->_currency_conversion($order->[2]);

	}
	if (scalar keys %touches > 0) {
	    for my $sum (qw/count transactions revenue/) {
		$all_touches{$_}{$sum} += $touches{$_}{$sum} for keys %touches;
	    }
	    # normalise
	    my $touches_total = sum(map { $touches{$_}{count} } keys %touches);
	    for my $sum (qw/transactions revenue/) {
		$touches{$_}{$sum} = $touches{$_}{$sum} * $touches{$_}{count} / $touches_total for keys %touches;
	    }
	    for my $sum (qw/count transactions revenue/) {
		$distr_touches{$_}{$sum} += $touches{$_}{$sum} for keys %touches;
	    }
	    push(@trans, { tid => $order->[1], 
			   timestamp => $order->[3], 
			   date => $rec->[0],
			   rev => $order->[2], 
			   touches => \%touches }); 
	}

    }
    $self->{summary} = {
	all_touches => \%all_touches,
	distr_touches => \%distr_touches,
	trans => \@trans };

}

sub report {
    my $self = shift;
    my %params = validate(@_, { all_touches =>  { default => 1 },
				distributed_touches =>  { default => 1 },
				transactions => { default => 1 },
				filename => 1,
				'format' => 0,
				title => 0,
			  });

    if ($params{filename} =~ m/\.(xls|txt|csv)$/i) {
	$params{'format'} = lc($1);
    }
    elsif (! defined $params{format}) {
	$params{'format'} = 'csv';
    }

    my @reports;
    push(@reports, $self->all_touches_report( title => $params{title} )) if $params{all_touches};
    push(@reports, $self->distributed_touches_report( title => $params{title} )) if $params{distributed_touches};
    push(@reports, $self->transactions_report( title => $params{title} )) if $params{transactions};
    my $output = WWW::Analytics::MultiTouch::Tabular->new({ 'format' => $params{'format'},
							    outfile => $params{filename},
							  });
    $output->print(\@reports);
    $output->close();
}

sub all_touches_report {
    my $self = shift;
    my %params = validate(@_, { title => { default => 'All Touches' } });

    my @data;
    my $summary = $self->{summary}{all_touches};
    for my $channel (sort keys %{$summary}) {
	push(@data, [ $channel, map { $summary->{$channel}{$_} } qw/count transactions revenue/ ]);
    }
    my %report = ( title => $params{title},
		   sheetname => 'All Touches',
		   headers => [ 'Channel', 'Touches', 'Transactions', 'Revenue' ],
		   data => \@data,
	);
    return \%report;
}

sub distributed_touches_report {
    my $self = shift;
    my %params = validate(@_, { title => { default => 'Distributed Touches' } });

    my @data;
    my $summary = $self->{summary}{distr_touches};
    for my $channel (sort keys %{$summary}) {
	push(@data, [ $channel, map { $summary->{$channel}{$_} } qw/count transactions revenue/ ]);
    }
    my %report = ( title => $params{title},
		   sheetname => 'Distributed Touches',
		   headers => [ 'Channel', 'Touches', 'Transactions', 'Revenue' ],
		   data => \@data,
	);
    return \%report;
}

sub transactions_report {
    my $self = shift;
    my %params = validate(@_, { title => { default => 'Transactions' } });

    my @summary = sort { $a->{tid} cmp $b->{tid} } @{$self->{summary}{trans}};
    my %channels;
    for my $rec (@summary) {
	$channels{$_}++ for keys %{$rec->{touches}};
    }

    my @channels = sort keys %channels;
    my @data = ( [ '', '', map { qw/Touches Transactions Revenue/ } @channels ] );
    for my $rec (@summary) {
	push(@data, [ $rec->{tid}, $rec->{'date'}, map { ($rec->{touches}{$_}{count} || '', $rec->{touches}{$_}{transactions} || '', $rec->{touches}{$_}{revenue} || '') } @channels ]);
    }
    my %report = ( title => $params{title},
		   sheetname => 'Transactions',
		   headers => [ 'Transaction ID', 'Date', map { (' ', $_, ' ') } @channels ],
		   data => \@data,
	);
    return \%report;
}


sub _compile_channel_pattern {
    my ($self, $pat) = @_;

    my @parts = split($self->{patsep}, $pat);
    my @idx;
    for (@parts) {
	m/source/ && do { push(@idx, 0); next };
	m/med/ && do { push(@idx, 1); next };
	m/sub|cat/ && do { push(@idx, 2); next };
	warn "Invalid channel pattern component: $_\n";
    }
    if (! @idx) {
	@idx = (0, 1, 2);
    }
    return \@idx;
}

sub _currency_conversion {
    my ($self, $dv) = @_;
    return $dv if $dv =~ m/^[0-9.]+$/;

    die "Currency conversion not implemented: rev = $dv\n";
}

sub _debug {
    my $self = shift;
    print @_ if $self->{debug};
}

sub process {
    my $class = shift;
    my $opts = shift;

    my $mt = $class->new(_opts_subset($opts, qw/user pass id event_category fieldsep recsep patsep debug/));

    $mt->get_data(_opts_subset($opts, qw/start_date end_date/));
    $mt->summarise(_opts_subset($opts, qw/window_length single_order_model channel_pattern/));
    $mt->report(_opts_subset($opts, qw/all_touches distributed_touches transactions filename format title/));
}

sub _opts_subset {
    my ($opts, @fields) = @_;

    my %result;
    for (@fields) {
	$result{$_} = $opts->{$_} if exists $opts->{$_};
    }

    return %result;
}

=head1 NAME

WWW::Analytics::MultiTouch - Multi-touch web analytics, using Google Analytics

=head1 SYNOPSIS

    use WWW::Analytics::MultiTouch;

    # Simple, all-in-one approach
    WWW::Analytics::MultiTouch->process(user => $username, 
                                        pass => $password, 
                                        id => $analytics_id,
                                        start_date => '2010-01-01',
                                        end_date => '2010-02-01',
                                        filename => 'report.xls');

    # Or step by step
    my $mt = WWW::Analytics::MultiTouch->new(user => $username, 
                                              pass => $password, 
                                              id => $analytics_id);
    $mt->get_data(start_date => '2010-01-01',
                  end_date => '2010-02-01');

    $mt->summarise(window_length => 45);
    $mt->report(filename => 'report-45day.xls');
    
    $mt->summarise(window_length => 30);
    $mt->report(filename => 'report-30day.xls');

=head1 DESCRIPTION

This module provides reporting for multi-touch web analytics, as described at
L<http://www.multitouchanalytics.com>.  

Unlike typical last-session attribution web analytics, multi-touch gives insight
into all of the various marketing channels to which a visitor is exposed before
finally making the decision to buy.

Multi-touch analytics uses a javascript library to send information from a
web user's browser to Google Analytics for raw data collection; this module uses
the Google Analytics API to collate the data and then summarises it in a
spreadsheet, showing (for example):

=over 4

=item * Summary of marketing channels and number of transactions to which each channel
had some contribution (sum of transactions > total transactions)

=item * Summary of channels and fair attribution of transactions (sum of
transactions = total transactions)

-item * List of each transaction and the contributing channels

=back

=head1 BASIC USAGE

=head2 process

    WWW::Analytics::MultiTouch->process(%options)

The process() function integrates all of the steps required to generate a report
into one, i.e. it creates a WWW::Analytics::MultiTouch object, fetches data from
the Google Analytics API, summarises the data and generates a report.

Options available are all of the options for L<new>, L<get_data>, L<summarise>
and L<report>.  Minimum options are user, pass, id, and typically start_date,
end_date and filename.

Typically the most time consuming part of the process is fetching the data from
Google.  The process() function is suitable if only one set of parameters is to
be used for the reports; to generate multiple reports using, for example,
different attribution windows, it is more efficient to use the full API to fetch
the data once and then run all the needed reports.

=head1 METHODS

=head2 new

  my $mt = WWW::Analytics::MultiTouch->new(%options)

Creates a new WWW::Analytics::MultiTouch object.

Options are:

=over 4

=item * user, pass, id

These are the Google Analytics username, password and reporting ID respectively.
These parameters are mandatory.

=item * event_category

The name of the event category used in Google Analytics to store multi-touch
data.  Defaults to 'multitouch' and only needs to be changed if the equivalent
variable in the associated javascript library has been customised.

=item * fieldsep, recsep

Field and record separators for stored multi-touch data.  These default to '!'
and '*' respectively and only need to be changed if the equivalent variables in
the associated javascript library has been customised.

=item * patsep

The pattern separator for turning source, medium and subcategory information
into a "channel" identifier.  See the C<channel_pattern> option under
L<summarise> for more information.  Defaults to '-'.

=item * debug

Enable debug output.

=back

=head2 get_data

  $mt->get_data(%options)

Get data via the Google Analytics API.

Options are:

=over 4

=item * start_date, end_date

Start and end dates respectively.  The total interval includes both start and
end dates.  Date format is YYYY-MM-DD or YYYYMMDD.

=back

=head2 summarise

  $mt->summarise(%options)

Summarise data.

Options are:

=over 4

=item * window_length

The analysis window length, in days.  Only touches this many days prior to any
given order will be included in the analysis.

=item * single_order_model

If set, any touch is counted only once, toward the next order only; subsequent
repeat orders do not include touches prior to the initial order.

=item * channel_pattern

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


=head2 report

  $mt->report(%options)

Generate reports.

Options are:

=over 4

=item * filename

Name of file in which to save reports.  If not specified, output is sent to STDOUT.  The filename extension, if given, is used to determine the file format, which can be xls, csv or txt.

=item * format

May be set to xls, csv or txt to specify Excel, CSV and Text format output
respectively.  The filename extension takes precedence over this parameter.

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

=back 

=cut

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

1; # End of WWW::Analytics::MultiTouch

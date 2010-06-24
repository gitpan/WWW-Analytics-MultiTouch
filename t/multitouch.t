#! /usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;
use WWW::Analytics::MultiTouch;
use DateTime;
use DateTime::Duration;

my $channel1 = 'src1!med1!';
my $channel2 = 'src2!med2!';
my $channel3 = 'src1!med1!sub3';

my $now = DateTime->now;
my $hour = DateTime::Duration->new(hours => 1);
my $day = DateTime::Duration->new(days => 1);
my $week = DateTime::Duration->new(days => 7);

my $t3 = _epoch_of($now);
my $t2 = _epoch_of($now - $hour);
my $t1 = _epoch_of($now - $day);
my $t0 = _epoch_of($now - $week);

my @events = (
    "__ORD!5!10.0!$t3*$channel1!$t2*$channel2!$t1",    
    "__ORD!4!8.0!$t3*$channel1!$t2*$channel3!$t0",
    "__ORD!3!6.0!$t3*$channel1!$t2*$channel1!$t0",
    "__ORD!2!4.0!$t3*$channel1!$t2*__ORD!1!2.0!$t1*$channel3!$t0",
    "__ORD!1!2.0!$t1*$channel3!$t0",
    );

test1();
test2();
test3();

sub _epoch_of {
    return shift->epoch;
}

sub test1 {
    my $mt =  WWW::Analytics::MultiTouch->new(user => 1, pass => 2, id => 3);
    my @event_data = map { [ $mt->_split_events($_) ] } @events;
    my %data = map { 'TID' . $_->[0][1] => [ DateTime->from_epoch(epoch => $_->[0][3])->ymd('-'),
					     @$_ ] } @event_data;

    $mt->{current_data} = { start_date => DateTime->from_epoch(epoch => $t0),
			    end_date => DateTime->from_epoch(epoch => $t3),
			    transactions => \%data,
    };

    $mt->summarise();
    my $all_touches_report = $mt->all_touches_report();
    is_deeply($all_touches_report->{data}, [
		  [ 'src1-med1-(none)', 5, 4, 28 ],
		  [ 'src1-med1-sub3', 3, 3, 14 ],
		  [ 'src2-med2-(none)', 1, 1, 10 ],
	      ], "All touches");
    my $distr_touches_report =  $mt->distributed_touches_report();
    is_deeply($distr_touches_report->{data}, [
		  [ 'src1-med1-(none)', 5, 2.5, 17 ],
		  [ 'src1-med1-sub3', 3, 2, 8 ],
		  [ 'src2-med2-(none)', 1, 0.5, 5 ],
	      ], "Distributed touches");
    my $trans_report = $mt->transactions_report();
    #splice off date field
    splice(@$_, 1, 1) for @{$trans_report->{data}};
    is_deeply($trans_report->{data}, 
	      [['','Touches','Transactions','Revenue','Touches','Transactions','Revenue','Touches','Transactions','Revenue'],
	       ['1','','','',1,1,2,'','',''],
	       ['2',1,'0.5',2,1,'0.5',2,'','',''],
	       ['3',2,1,6,'','','','','',''],
	       ['4',1,'0.5',4,1,'0.5',4,'','',''],
	       ['5',1,'0.5',5,'','','',1,'0.5',5]], "Transactions");

}

sub test2 {
    my $mt =  WWW::Analytics::MultiTouch->new(user => 1, pass => 2, id => 3);
    my @event_data = map { [ $mt->_split_events($_) ] } @events;
    my %data = map { 'TID' . $_->[0][1] => [ DateTime->from_epoch(epoch => $_->[0][3])->ymd('-'),
					     @$_ ] } @event_data;

    $mt->{current_data} = { start_date => DateTime->from_epoch(epoch => $t0),
			    end_date => DateTime->from_epoch(epoch => $t3),
			    transactions => \%data,
    };

    $mt->summarise(single_order_model => 1);
    my $all_touches_report = $mt->all_touches_report();
    is_deeply($all_touches_report->{data}, [
		  [ 'src1-med1-(none)', 5, 4, 28 ],
		  [ 'src1-med1-sub3', 2, 2, 10 ],
		  [ 'src2-med2-(none)', 1, 1, 10 ],
	      ], "All touches single order");
    my $distr_touches_report =  $mt->distributed_touches_report();
    is_deeply($distr_touches_report->{data}, [
		  [ 'src1-med1-(none)', 5, 3, 19 ],
		  [ 'src1-med1-sub3', 2, 1.5, 6 ],
		  [ 'src2-med2-(none)', 1, 0.5, 5 ],
	      ], "Distributed touches single order");
    my $trans_report = $mt->transactions_report();
    #splice off date field
    splice(@$_, 1, 1) for @{$trans_report->{data}};
    is_deeply($trans_report->{data}, 
	      [['','Touches','Transactions','Revenue','Touches','Transactions','Revenue','Touches','Transactions','Revenue'],
	       ['1','','','',1,1,2,'','',''],
	       ['2',1,1,4,'','','','','',''],
	       ['3',2,1,6,'','','','','',''],
	       ['4',1,'0.5',4,1,'0.5',4,'','',''],
	       ['5',1,'0.5',5,'','','',1,'0.5',5]], "Transactions single order");

}

			    
sub test3 {
    my $mt =  WWW::Analytics::MultiTouch->new(user => 1, pass => 2, id => 3);
    my @event_data = map { [ $mt->_split_events($_) ] } @events;
    my %data = map { 'TID' . $_->[0][1] => [ DateTime->from_epoch(epoch => $_->[0][3])->ymd('-'),
					     @$_ ] } @event_data;

    $mt->{current_data} = { start_date => DateTime->from_epoch(epoch => $t0),
			    end_date => DateTime->from_epoch(epoch => $t3),
			    transactions => \%data,
    };

    $mt->summarise(window_length => 6);
    my $all_touches_report = $mt->all_touches_report();
    is_deeply($all_touches_report->{data}, [
		  [ 'src1-med1-(none)', 4, 4, 28 ],
		  [ 'src1-med1-sub3', 1, 1, 2 ],
		  [ 'src2-med2-(none)', 1, 1, 10 ],
	      ], "All touches short window");

    my $distr_touches_report =  $mt->distributed_touches_report();
    is_deeply($distr_touches_report->{data}, [
		  [ 'src1-med1-(none)', 4, 3.5, 23 ],
		  [ 'src1-med1-sub3', 1, 1, 2 ],
		  [ 'src2-med2-(none)', 1, 0.5, 5 ],
	      ], "Distributed touches short window");

    my $trans_report = $mt->transactions_report();
    #splice off date field
    splice(@$_, 1, 1) for @{$trans_report->{data}};
    is_deeply($trans_report->{data}, 
	      [['','Touches','Transactions','Revenue','Touches','Transactions','Revenue','Touches','Transactions','Revenue'],
	       ['1','','','',1,1,2,'','',''],
	       ['2',1,1,4,'','','','','',''],
	       ['3',1,1,6,'','','','','',''],
	       ['4',1,1,8,'','','','','',''],
	       ['5',1,'0.5',5,'','','',1,'0.5',5]], "Transactions short window");

}

			    
    
    

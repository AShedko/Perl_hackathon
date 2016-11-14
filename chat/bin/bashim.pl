#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Term::ReadLine;
use IO::Select;
use Local::Chat::ServerConnection;
use Data::Dumper;
use LWP::UserAgent;
use Encode;

$|=1;


my $time = time;

my $term = Term::ReadLine->new('Simple perl chat');

my $server = Local::Chat::ServerConnection->new(
	nick => 'bashim',#'T'.int(rand(10000)),
	host => $ARGV[0] || 'localhost',
	netlog => 1,
	on_fd => sub {
		my ($srv, $fd) = @_;
		if ($fd == $term->IN) {
			my $msg = $term->readline();
                        exit unless defined $msg;
			chomp($msg);
			return unless length $msg;

			if ($msg =~ m{^/(\w+)(?:\s+(\S+))*$}) {
				if ($1 eq 'nick') {
					$srv->nick($2);
					return;
				}
				elsif ($1 eq 'names') {
					$srv->names();
				}
				elsif ($1 eq 'kill') {
					$srv->kill($2);
				}
				else {
					warn "Unknown command '$1'\n";
				}
				return;
			}
			$srv->message( $msg );
			# $srv->message( $msg.2 );
			# $srv->message( $msg.3 );
		}
	},
	on_idle => sub {
		my ($srv, $data) = @_;
		if ($time <= time) {
			$time += 30;
			my $browser = LWP::UserAgent->new;
			my $url = 'http://bash.im/random';
			my $response = $browser->get( $url );
			die "Can't get $url — ", $response->status_line unless $response->is_success;

			my $str= $response->content;
			my @a=split (/<div class="text">/, $str);
			my $s=$a[49];
			my @b=split (/<\/div>/, $s);
			my $n=$b[0];
			Encode::from_to($n, 'cp1251', 'utf8');
			$n =~ s/<br>/\n/g;
			$n =~ s/<br \/>/\n/g;
			$n =~ s/&quot;/'/g;
			$n =~ s/&gt;/>/g;
			$n =~ s/&lt;/</g;
			$n = $n."\n";
			$srv->message( $n );
		}
	},
	on_msg => sub {
		my ($srv, $data) = @_;
		if ($data->{text} eq '!who') {
			$srv->message( 'I am bashim' );
		}
		if ($data->{to}) {
			printf "[%s] %s: %s\n", $data->{to}, $data->{from}, $data->{text};
		} else {
			printf "[-] %s: %s\n", $data->{from}, $data->{text};
		}
	}
);

$server->sel->add($term->IN);
$server->poll;

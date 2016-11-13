#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Term::ReadLine;
use IO::Select;
use Local::Chat::ServerConnection;
use LWP::UserAgent;
use XML::Simple;

$|=1;

my $term = Term::ReadLine->new('Simple perl chat');

my $server = Local::Chat::ServerConnection->new(
	nick => 'cbr',#'T'.int(rand(10000)),
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
	on_idle => sub {},
	on_msg => sub {
		my ($srv, $data) = @_;
		my @chunks = split /\s+/, $data->{text};
		if ($chunks[0] eq 'cbr') {
			my $amount = $chunks[1];
			my $currency = $chunks[2];
			my $browser = LWP::UserAgent->new;
			my $url = 'http://www.cbr.ru/scripts/XML_daily.asp?';
			my $response = $browser->get( $url );
			die "Can't get $url — ", $response->status_line unless $response->is_success;
			my $str = %{$response}{_content};
			my $result = XML::Simple->new()->XMLin($str);
			my $money = -1;
			for (my $i = 0; $i < scalar @{%{$result}{Valute}}; $i++) {
			  if (${@{%{$result}{Valute}}[$i]}{CharCode} eq $currency) {
			    my $nom = ${@{%{$result}{Valute}}[$i]}{Nominal};
			    my $val = ${@{%{$result}{Valute}}[$i]}{Value};
			    $val =~ s/,/\./;
			    $val = 0 + $val;
			    $money = $val*$amount/$nom;
			  };
			}
			my $msg;
			if ($money == -1) {
				$msg = "Bad currency";
			} else {
				my $date = ${$result}{Date};
				$date =~ s/\./\//g;
				$msg = $data->{from}.' '.$amount.' '.$currency.' '.$date.' = '.$money." RUB\n";
			}
			$srv->message( $msg );
		}
		if ($data->{text} eq '!who') {
			$srv->message( 'I am cbr' );
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

#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Term::ReadLine;
use IO::Select;
use Local::Chat::ServerConnection;
use DDP;
use Term::ReadKey;

$|=1;

my $time = time;

my @strings_to_show = ();

local $SIG{TERM} = $SIG{INT} = \&stop;

my ( $term_width, $term_height ) = GetTerminalSize();

my $term = Term::ReadLine->new('Simple perl chat');
$term->MinLine();

local $SIG{WINCH} = sub {
	( $term_width, $term_height ) = GetTerminalSize();
};

sub stop {
    print "\e[".(2 + @strings_to_show).";1H\e[J\n";
    exit;
}

sub init {
    print "\e[1;1H\e[J";
}

sub redraw {
	print "\e7";
    print "\e[2;1H\e[J";
	print join "\n", @strings_to_show;
    print "\e8";
}

sub add_message {
	my $string = shift;
	unshift @strings_to_show, split /\n/, $string;
	splice @strings_to_show, ( $term_height - 1 ) if @strings_to_show > $term_height - 1;
	redraw;
}

my $nick = 'fortune';
my $pass = 'fortunepass';

chomp($nick);
chomp($pass);
$term->MinLine(2);

init();
my $room = "#all";
my $server = Local::Chat::ServerConnection->new(nick => $nick,pass=> $pass, host => $ARGV[0] || 'localhost',
	on_fd => sub {
		my ($srv, $fd) = @_;
		if ($fd == $term->IN) {
			my $msg = $term->readline('');
			print "\e[1;1H\e[2K";
                        stop() unless defined $msg;
			chomp($msg);
                        return unless length $msg;
			if ($msg =~ m{^/(\w+)(?:\s+(\S+))*$}) {
				if ($1 eq 'nick') {
					$srv->nick($2);
					return;
				}
				elsif($1 eq 'join') {
					$srv->join($2);
					$room = $2;
				}
				elsif($1 eq 'create') {
					$srv->create($2);
				}
				elsif ($1 eq 'names') {
					$srv->names($2);
				}
				elsif ($1 eq 'kill') {
					$srv->kill($2);
				}
				else {
					add_message( "\e[31mUnknown command '$1'\e[0m\n" );
				}
				return;
			}
			$srv->message({ text => $msg, to => $room });
		}
	},
	on_message => sub {
		my ($srv, $message) = @_;
		#add_message( $message->{from} . ": ". $message->{text} );
        if ($message->{text} eq '!who') {
            $srv->message({ text => 'fortune', to => $room });
        }
	},
	on_idle => sub {
        my ($srv) = @_;
		if ($time < time){
			$time += 60;
            my $message = `fortune`;
            $srv->message({ text => $message, to => $room });
		}
	},
	on_names => sub {
		my ($srv, $message) = @_;
		add_message( $message->{room} . ": " . join ', ', @{$message->{names}} );
	},
	on_disconect => sub {
		my ($srv) = @_;
		add_message("Сервер оборвал соединение");
	},
	on_error => sub {
		my ($srv, $message) = @_;
		add_message( "\e[31;1m"."Error"."\e[0m".": $message->{text}\n" );
		if ($message->{code}==666){exit "Wrong pass!";}

	}
);

$server->sel->add($term->IN);
my $last_error = time();
while () {
	eval {
		$server->connect;
	};
	if ($@) {
		if (time() - $last_error > 60) {
			add_message("Ожидание сервера");
			$last_error = time();
		}
		sleep(1);
	}
	else {
		$server->poll();
	}

}

stop();

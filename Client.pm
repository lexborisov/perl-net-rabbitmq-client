package Net::RabbitMQ::Client;

use utf8;
use strict;
use vars qw($AUTOLOAD $VERSION $ABSTRACT @ISA @EXPORT);

BEGIN {
	$VERSION = 0.4;
	$ABSTRACT = "RabbitMQ client (XS for librabbitmq)";
	
	@ISA = qw(Exporter DynaLoader);
	@EXPORT = qw(
		AMQP_STATUS_OK AMQP_STATUS_NO_MEMORY AMQP_STATUS_BAD_AMQP_DATA AMQP_STATUS_UNKNOWN_CLASS
		AMQP_STATUS_UNKNOWN_METHOD AMQP_STATUS_HOSTNAME_RESOLUTION_FAILED AMQP_STATUS_INCOMPATIBLE_AMQP_VERSION
		AMQP_STATUS_CONNECTION_CLOSED AMQP_STATUS_BAD_URL AMQP_STATUS_SOCKET_ERROR AMQP_STATUS_INVALID_PARAMETER
		AMQP_STATUS_TABLE_TOO_BIG AMQP_STATUS_WRONG_METHOD AMQP_STATUS_TIMEOUT AMQP_STATUS_TIMER_FAILURE
		AMQP_STATUS_HEARTBEAT_TIMEOUT AMQP_STATUS_UNEXPECTED_STATE AMQP_STATUS_SOCKET_CLOSED AMQP_STATUS_SOCKET_INUSE
		AMQP_STATUS_BROKER_UNSUPPORTED_SASL_METHOD _AMQP_STATUS_NEXT_VALUE AMQP_STATUS_TCP_ERROR
		AMQP_STATUS_TCP_SOCKETLIB_INIT_ERROR _AMQP_STATUS_TCP_NEXT_VALUE AMQP_STATUS_SSL_ERROR
		AMQP_STATUS_SSL_HOSTNAME_VERIFY_FAILED AMQP_STATUS_SSL_PEER_VERIFY_FAILED
		
		AMQP_DELIVERY_NONPERSISTENT AMQP_DELIVERY_PERSISTENT
		
		AMQP_SASL_METHOD_UNDEFINED AMQP_SASL_METHOD_PLAIN AMQP_SASL_METHOD_EXTERNAL
		
		AMQP_RESPONSE_NONE AMQP_RESPONSE_NORMAL AMQP_RESPONSE_LIBRARY_EXCEPTION AMQP_RESPONSE_SERVER_EXCEPTION
		
		AMQP_FIELD_KIND_BOOLEAN AMQP_FIELD_KIND_I8 AMQP_FIELD_KIND_U8 AMQP_FIELD_KIND_I16 AMQP_FIELD_KIND_U16
		AMQP_FIELD_KIND_I32 AMQP_FIELD_KIND_U32 AMQP_FIELD_KIND_I64 AMQP_FIELD_KIND_U64 AMQP_FIELD_KIND_F32
		AMQP_FIELD_KIND_F64 AMQP_FIELD_KIND_DECIMAL AMQP_FIELD_KIND_UTF8 AMQP_FIELD_KIND_ARRAY AMQP_FIELD_KIND_TIMESTAMP
		AMQP_FIELD_KIND_TABLE AMQP_FIELD_KIND_VOID AMQP_FIELD_KIND_BYTES
		
		AMQP_PROTOCOL_VERSION_MAJOR AMQP_PROTOCOL_VERSION_MINOR AMQP_PROTOCOL_VERSION_REVISION AMQP_PROTOCOL_PORT
		AMQP_FRAME_METHOD AMQP_FRAME_HEADER AMQP_FRAME_BODY AMQP_FRAME_HEARTBEAT AMQP_FRAME_MIN_SIZE AMQP_FRAME_END
		AMQP_REPLY_SUCCESS AMQP_CONTENT_TOO_LARGE AMQP_NO_ROUTE AMQP_NO_CONSUMERS AMQP_ACCESS_REFUSED AMQP_NOT_FOUND
		AMQP_RESOURCE_LOCKED AMQP_PRECONDITION_FAILED AMQP_CONNECTION_FORCED AMQP_INVALID_PATH AMQP_FRAME_ERROR
		AMQP_SYNTAX_ERROR AMQP_COMMAND_INVALID AMQP_CHANNEL_ERROR AMQP_UNEXPECTED_FRAME AMQP_RESOURCE_ERROR AMQP_NOT_ALLOWED
		AMQP_NOT_IMPLEMENTED AMQP_INTERNAL_ERROR
		
		AMQP_BASIC_CLASS AMQP_BASIC_CONTENT_TYPE_FLAG AMQP_BASIC_CONTENT_ENCODING_FLAG AMQP_BASIC_HEADERS_FLAG
		AMQP_BASIC_DELIVERY_MODE_FLAG AMQP_BASIC_PRIORITY_FLAG AMQP_BASIC_CORRELATION_ID_FLAG AMQP_BASIC_REPLY_TO_FLAG
		AMQP_BASIC_EXPIRATION_FLAG AMQP_BASIC_MESSAGE_ID_FLAG AMQP_BASIC_TIMESTAMP_FLAG AMQP_BASIC_TYPE_FLAG AMQP_BASIC_USER_ID_FLAG
		AMQP_BASIC_APP_ID_FLAG AMQP_BASIC_CLUSTER_ID_FLAG
	);
};

bootstrap Net::RabbitMQ::Client $VERSION;

use DynaLoader ();
use Exporter ();

my $STATUSES = {
	0  => undef,
	10 => "Can't open socket",
	20 => "Can't login on server",
	30 => "Can't open chanel",
	40 => "Can't declare exchange",
	50 => "Cant' declare queue",
	51 => "Can't bind queue",
	60 => "Can't basic consume",
	70 => "Can't publish data"
};

sub _destroy_and_status {
	my ($self, $status) = @_;
	
	$self->sm_destroy();
	
	$status;
}

sub sm_new {
	my ($class) = shift;
	my $config = {
		host => '', port => 5672, channel => 1,
		login => '', password => '',
		exchange => undef, exchange_type => undef, exchange_declare => 0,
		queue => undef, routingkey => '', queue_declare => 0,
		@_
	};
	
	my $rmq    = $class->create();
	my $conn   = $rmq->new_connection();
	my $socket = $rmq->tcp_socket_new($conn);
	
	my $self = bless {rmq => $rmq, conn => $conn, socket => $socket, config => $config}, $class;
	
	my $status = $rmq->socket_open($socket, $config->{host}, $config->{port});
	return $self->_destroy_and_status(10) if $status;
	
	$status = $rmq->login($conn, "/", 0, 131072, 0, AMQP_SASL_METHOD_PLAIN(), $config->{login}, $config->{password});
	return $self->_destroy_and_status(20) if $status != AMQP_RESPONSE_NORMAL();
	
	$status = $rmq->channel_open($conn, $config->{channel});
	return $self->_destroy_and_status(30) if $status != AMQP_RESPONSE_NORMAL();
	
	if (defined $config->{exchange} && $config->{exchange_declare} &&
	    $config->{exchange} ne '' && defined $config->{exchange_type})
	{
		$status = $rmq->exchange_declare($conn, $config->{channel}, $config->{exchange}, $config->{exchange_type}, 0, 1, 0, 0);
		return $self->_destroy_and_status(40) if $status != AMQP_RESPONSE_NORMAL();
	}
	
	if (defined $config->{queue} && $config->{queue} ne '')
	{
		if ($config->{queue_declare}) {
			$rmq->queue_declare($conn, $config->{channel}, $config->{queue}, 0, 1, 0, 0);
			return $self->_destroy_and_status(50) if $status != AMQP_RESPONSE_NORMAL();
		}
		
		if (exists $config->{exchange} && $config->{exchange} ne '') {
			$rmq->queue_bind($conn, $config->{channel}, $config->{queue}, $config->{exchange}, $config->{routingkey}, 0);
			return $self->_destroy_and_status(51) if $status != AMQP_RESPONSE_NORMAL();
		}
	}
	
	$self;
}

sub sm_destroy {
	my ($self) = @_;
	
	my $rmq = $self->{rmq};
	my $config = $self->{config};
	
	if (ref $rmq && ref $self->{conn} && ref $config eq "HASH") {
		$rmq->channel_close($self->{conn}, $config->{channel}, AMQP_REPLY_SUCCESS());
		$rmq->connection_close($self->{conn}, AMQP_REPLY_SUCCESS());
		$rmq->destroy_connection($self->{conn});
	}
}

sub sm_publish {
	my ($self, $data) = (shift, shift);
	my $args = {
		content_type  => "text/plain",
		delivery_mode => AMQP_DELIVERY_PERSISTENT(),
		_flags        => AMQP_BASIC_CONTENT_TYPE_FLAG()|AMQP_BASIC_DELIVERY_MODE_FLAG(),
		@_
	};
	
	my $rmq     = $self->{rmq};
	my $conn    = $self->{conn};
	my $config  = $self->{config};
	my $channel = $config->{channel};
	
	my $props = $rmq->type_create_basic_properties();
        $rmq->set_prop__flags($props, $args->{"_flags"});
        $rmq->set_prop_content_type($props, $args->{content_type});
        $rmq->set_prop_delivery_mode($props, $args->{delivery_mode});
	
        my $status = $rmq->basic_publish($conn, $channel, $config->{exchange}, $config->{routingkey}, 0, 0, $props, $data);
	
        if($status != AMQP_STATUS_OK()) {
		$status = 70;
        }
	
        $rmq->type_destroy_basic_properties($props);
	
	$status;
}

sub sm_get_messages {
	my ($self, $callback) = @_;
	
	my $rmq     = $self->{rmq};
	my $conn    = $self->{conn};
	my $config  = $self->{config};
	my $channel = $config->{channel};
	
	my $status = $rmq->basic_consume($conn, $channel, $config->{queue}, undef, 0, 0, 0);
	return 60 if $status != AMQP_RESPONSE_NORMAL();
	
	my $envelope = $rmq->type_create_envelope();
	
	while (1) {
		$rmq->maybe_release_buffers($conn);
		
		my $status = $rmq->consume_message($conn, $envelope, 0, 0);
		next if $status != AMQP_RESPONSE_NORMAL();
		
		if($callback->($self, $rmq->envelope_get_message_body($envelope))) {
			$rmq->basic_ack($conn, $channel, $rmq->envelope_get_delivery_tag($envelope), 0);
		}
		
		$rmq->destroy_envelope($envelope);
	}
	
	$rmq->type_destroy_envelope($envelope);
	
	0;
}

sub sm_get_message {
	my ($self) = shift;
	
	my $rmq     = $self->{rmq};
	my $conn    = $self->{conn};
	my $config  = $self->{config};
	my $channel = $config->{channel};
	
	my $status = $rmq->basic_consume($conn, $channel, $config->{queue}, undef, 0, 0, 0);
	return $_[0] = 60 if $status != AMQP_RESPONSE_NORMAL() && exists $_[0];
	
	my $envelope = $rmq->type_create_envelope();
	my $message;
	
	$rmq->maybe_release_buffers($conn);
	
	$status = $rmq->consume_message($conn, $envelope, 0, 0);
	
	if($status == AMQP_RESPONSE_NORMAL()) {
		$message = $self, $rmq->envelope_get_message_body($envelope);
	}
	
	$rmq->basic_ack($conn, $channel, $rmq->envelope_get_delivery_tag($envelope), 0);
	$rmq->destroy_envelope($envelope);
	
	$rmq->type_destroy_envelope($envelope);
	
	$message;
}

sub sm_get_rabbitmq   {$_[0]->{rmq}}
sub sm_get_connection {$_[0]->{conn}}
sub sm_get_socket     {$_[0]->{socket}}
sub sm_get_config     {$_[0]->{config}}

sub sm_get_error_desc {$STATUSES->{$_[0]}}

1;


__END__

=head1 NAME

Net::RabbitMQ::Client - RabbitMQ client (XS for librabbitmq)

=head1 SYNOPSIS


Simple API:

	use utf8;
	use strict;
	
	use Net::RabbitMQ::Client;
	
	produce();
	consume();
	
	sub produce {
		my $simple = Net::RabbitMQ::Client->sm_new(
			host => "best.host.for.rabbitmq.net",
			login => "login", password => "password",
			queue => "test_queue", queue_declare => 1
		);
		die sm_get_error_desc($simple) unless ref $simple;
		
		my $sm_status = $simple->sm_publish('{"say": "hello"}', content_type => "application/json");
		die sm_get_error_desc($sm_status) if $sm_status;
		
		$simple->sm_destroy();
	}
	
	sub consume {
		my $simple = Net::RabbitMQ::Client->sm_new(
			host => "best.host.for.rabbitmq.net",
			login => "login", password => "password",
			queue => "test_queue"
		);
		die sm_get_error_desc($simple) unless ref $simple;
		
		my $sm_status = $simple->sm_get_messages(sub {
			my ($self, $message) = @_;
			
			print $message, "\n";
			
			1; # it is important to return 1 (send ask) or 0
		});
		die sm_get_error_desc($sm_status) if $sm_status;
		
		$simple->sm_destroy();
	}


Base API:

	use utf8;
	use strict;
	
	use Net::RabbitMQ::Client;
	
	produce();
	consume();
	
	sub produce {
		my $rmq = Net::RabbitMQ::Client->create();
		
		my $exchange = "test";
		my $routingkey = "";
		my $messagebody = "lalala";
		
		my $channel = 1;
		
		my $conn = $rmq->new_connection();
		my $socket = $rmq->tcp_socket_new($conn);
		
		my $status = $rmq->socket_open($socket, "best.host.for.rabbitmq.net", 5672);
		die "Can't create socket" if $status;
		
		$status = $rmq->login($conn, "/", 0, 131072, 0, AMQP_SASL_METHOD_PLAIN, "login", "password");
		die "Can't login on server" if $status != AMQP_RESPONSE_NORMAL;
		
		$status = $rmq->channel_open($conn, $channel);
		die "Can't open chanel" if $status != AMQP_RESPONSE_NORMAL;
	    
		$rmq->queue_bind($conn, 1, "test_q", $exchange, $routingkey, 0);
		die "Can't bind queue" if $status != AMQP_RESPONSE_NORMAL;
		
		my $props = $rmq->type_create_basic_properties();
		$rmq->set_prop__flags($props, AMQP_BASIC_CONTENT_TYPE_FLAG|AMQP_BASIC_DELIVERY_MODE_FLAG);
		$rmq->set_prop_content_type($props, "text/plain");
		$rmq->set_prop_delivery_mode($props, AMQP_DELIVERY_PERSISTENT);
		
		$status = $rmq->basic_publish($conn, $channel, $exchange, $routingkey, 0, 0, $props, $messagebody);
		
		if($status != AMQP_STATUS_OK) {
		    print "Can't send message\n";
		}
		
		$rmq->type_destroy_basic_properties($props);
		
		$rmq->channel_close($conn, 1, AMQP_REPLY_SUCCESS);
		$rmq->connection_close($conn, AMQP_REPLY_SUCCESS);
		$rmq->destroy_connection($conn);
	}
	
	sub consume {
		my $rmq = Net::RabbitMQ::Client->create();
		
		my $exchange = "test";
		my $routingkey = "";
		my $messagebody = "lalala";
		
		my $channel = 1;
		
		my $conn = $rmq->new_connection();
		my $socket = $rmq->tcp_socket_new($conn);
		
		my $status = $rmq->socket_open($socket, "best.host.for.rabbitmq.net", 5672);
		die "Can't create socket" if $status;
		
		$status = $rmq->login($conn, "/", 0, 131072, 0, AMQP_SASL_METHOD_PLAIN, "login", "password");
		die "Can't login on server" if $status != AMQP_RESPONSE_NORMAL;
		
		$status = $rmq->channel_open($conn, $channel);
		die "Can't open chanel" if $status != AMQP_RESPONSE_NORMAL;
		
		$status = $rmq->basic_consume($conn, 1, "test_q", undef, 0, 1, 0);
		die "Consuming" if $status != AMQP_RESPONSE_NORMAL;
		
		my $envelope = $rmq->type_create_envelope();
		
		while (1)
		{
			$rmq->maybe_release_buffers($conn);
			
			$status = $rmq->consume_message($conn, $envelope, 0, 0);
			last if $status != AMQP_RESPONSE_NORMAL;
			
			print "New message: \n", $rmq->envelope_get_message_body($envelope), "\n";
			
			$rmq->destroy_envelope($envelope);
		}
		
		$rmq->type_destroy_envelope($envelope);
		
		$rmq->channel_close($conn, 1, AMQP_REPLY_SUCCESS);
		$rmq->connection_close($conn, AMQP_REPLY_SUCCESS);
		$rmq->destroy_connection($conn);
	}


=head1 DESCRIPTION

This is binding for RabbitMQ-C library.

Please, before install this module make RabbitMQ-C library.

See https://github.com/alanxz/rabbitmq-c

https://github.com/lexborisov/perl-net-rabbitmq-client


=head1 METHODS

=head2 Simple API

=head3 sm_new

	my $simple = Net::RabbitMQ::Client->sm_new(
		host => '',              # default: 
		port => 5672,            # default: 5672
		channel => 1,            # default: 1
		login => '',             # default: 
		password => '',          # default: 
		exchange => undef,       # default: undef
		exchange_type => undef,  # optional, if exchange_declare == 1; types: topic, fanout, direct, headers; default: undef
		exchange_declare => 0,   # declare exchange or not; 1 or 0; default: 0
		queue => undef,          # default: undef
		routingkey => '',        # default: 
		queue_declare => 0,      # declare queue or not; 1 or 0; default: 0
	);

Return: a Simple object if successful, otherwise an error occurred


=head3 sm_publish

	my $sm_status = $simple->sm_publish($text,
		# default args
		content_type  => "text/plain",
		delivery_mode => AMQP_DELIVERY_PERSISTENT,
		_flags        => AMQP_BASIC_CONTENT_TYPE_FLAG|AMQP_BASIC_DELIVERY_MODE_FLAG
	);

Return: 0 if successful, otherwise an error occurred


=head3 sm_get_messages

Loop to get messages

	my $callback = {
		my ($simple, $message) = @_;
		
		1; # it is important to return 1 (send ask) or 0
	}
	
	my $sm_status = $simple->sm_get_messages($callback);

Return: 0 if successful, otherwise an error occurred


=head3 sm_get_message

Get one message
	
	my $sm_status = 0;
	my $message = $simple->sm_get_message($sm_status);

Return: message if successful


=head3 sm_get_rabbitmq

	my $rmq = $simple->sm_get_rabbitmq();
	
Return: RabbitMQ Base object


=head3 sm_get_connection

	my $conn = $simple->sm_get_connection();
	
Return: Connection object (from Base API new_connection)


=head3 sm_get_socket

	my $socket = $simple->sm_get_socket();
	
Return: Socket object (from Base API tcp_socket_new)


=head3 sm_get_config

	my $config = $simple->sm_get_config();
	
Return: Config when creating a Simple object


=head3 sm_get_config

	my $description = $simple->sm_get_error_desc($sm_error_code);
	
Return: Error description by Simple error code


=head3 sm_destroy

Destroy a Simple object
	
	$simple->sm_destroy();
	

=head2 Base API

=head3 create

 my $rmq = Net::RabbitMQ::Client->create();

Create XS_RabbitMQ object

=head3 new_connection

 my $conn = $rmq->new_connection();

Allocate and initialize a new amqp_connection_state_t object


=head3 tcp_socket_new

 my $socket = $rmq->tcp_socket_new();

Create a new TCP socket.


=head3 socket_open

 my $status = $rmq->socket_open($socket, $host, $port);

Open a socket connection.


=head3 socket_open_noblock

 my $status = $rmq->socket_open_noblock($socket, $host, $port, $timeout_in_sec);

Open a non-blocking socket connection.


=head3 socket_get_sockfd

 my $int = $rmq->socket_get_sockfd($socket);

Get the socket descriptor in use by a socket object.


=head3 get_socket

 my $socket = $rmq->get_socket($conn);

Get the socket object associated with a amqp_connection_state_t



=head1 DESTROY

 undef $rmq;

Free mem and destroy object.

=head1 AUTHOR

Alexander Borisov <lex.borisov@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexander Borisov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

See librabbitmq license and COPYRIGHT https://github.com/alanxz/rabbitmq-c


=cut

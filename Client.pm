package Net::RabbitMQ::Client;

use utf8;
use strict;
use vars qw($AUTOLOAD $VERSION $ABSTRACT @ISA @EXPORT);

BEGIN {
	$VERSION = 0.3;
	$ABSTRACT = "RabbitMQ client (XS for librabbitmq v0.7.0)";
	
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

1;


__END__

=head1 NAME

Net::RabbitMQ::Client - RabbitMQ client (XS for librabbitmq v0.7.0)

=head1 SYNOPSIS


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

This is glue for RabbitMQ-C library.

Please, before install this module make RabbitMQ-C library.

Current v0.7.0 ( https://github.com/alanxz/rabbitmq-c/releases/tag/v0.7.0 )

See https://github.com/alanxz/rabbitmq-c

https://github.com/lexborisov/perl-net-rabbitmq-client

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

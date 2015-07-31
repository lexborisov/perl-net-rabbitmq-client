perl-net-rabbitmq-client
==============================

RabbitMQ client (XS for librabbitmq v0.7.0)

# INSTALLATION

Please, before install this module make RabbitMQ-C library.

Current v0.7.0 ( https://github.com/alanxz/rabbitmq-c/releases/tag/v0.7.0 )

See https://github.com/alanxz/rabbitmq-c

Make module:

```sh
perl Makefile.PL
make
make test
make install
```

# SYNOPSIS

```perl
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
```


# DESCRIPTION

This is glue for RabbitMQ-C library v0.7.0


# DESTROY

 undef $rmq;

Free mem and destroy object.

# AUTHOR

Alexander Borisov <lex.borisov@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexander Borisov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

See librabbitmq license and COPYRIGHT https://github.com/alanxz/rabbitmq-c

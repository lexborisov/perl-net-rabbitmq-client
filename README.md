perl-net-rabbitmq-client
==============================

RabbitMQ client (XS for librabbitmq)

# INSTALLATION

Please, before install this module make RabbitMQ-C library.

See https://github.com/alanxz/rabbitmq-c

Make module:

```sh
perl Makefile.PL
make
make test
make install
```

# SYNOPSIS

Simple API:

```perl
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
```


Base API:

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

This is glue for RabbitMQ-C library

# METHODS

## Simple API

### sm_new

```perl
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
```


Return: a Simple object if successful, otherwise an error occurred


### sm_publish

```perl
my $sm_status = $simple->sm_publish($text,
        # default args
        content_type  => "text/plain",
        delivery_mode => AMQP_DELIVERY_PERSISTENT,
        _flags        => AMQP_BASIC_CONTENT_TYPE_FLAG|AMQP_BASIC_DELIVERY_MODE_FLAG
);
```


Return: 0 if successful, otherwise an error occurred


### sm_get_messages

Loop to get messages

```perl
my $callback = {
        my ($simple, $message) = @_;
        
        1; # it is important to return 1 (send ask) or 0
}

my $sm_status = $simple->sm_get_messages($callback);
```


Return: 0 if successful, otherwise an error occurred


### sm_get_message

Get one message

```perl
my $sm_status = 0;
my $message = $simple->sm_get_message($sm_status);
```


Return: message if successful


### sm_get_rabbitmq

```perl
my $rmq = $simple->sm_get_rabbitmq();
```


Return: RabbitMQ Base object


### sm_get_connection

```perl
my $conn = $simple->sm_get_connection();
```


Return: Connection object (from Base API new_connection)


### sm_get_socket

```perl
my $socket = $simple->sm_get_socket();
```


Return: Socket object (from Base API tcp_socket_new)


### sm_get_config

```perl
my $config = $simple->sm_get_config();
```


Return: Config when creating a Simple object


### sm_get_config

```perl
my $description = $simple->sm_get_error_desc($sm_error_code);
```


Return: Error description by Simple error code


### sm_destroy

Destroy a Simple object

```perl
$simple->sm_destroy();
```


## Base API

Description will be later


# DESTROY

```perl
undef $rmq;
```


Free mem and destroy object.

# AUTHOR

Alexander Borisov <lex.borisov@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexander Borisov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

See librabbitmq license and COPYRIGHT https://github.com/alanxz/rabbitmq-c

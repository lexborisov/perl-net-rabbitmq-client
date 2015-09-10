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
                exchange => "test_ex", exchange_type => "direct", exchange_declare => 1,
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

# Simple API

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


# Base API

## Connection and Authorization

### create

```perl
 my $rmq = Net::RabbitMQ::Client->create();
```

Return: rmq


### new_connection

```perl
 my $amqp_connection_state_t = $rmq->new_connection();
```

Return: amqp_connection_state_t


### tcp_socket_new

```perl
 my $amqp_socket_t = $rmq->tcp_socket_new($conn);
```

Return: amqp_socket_t


### socket_open

```perl
 my $status = $rmq->socket_open($socket, $host, $port);
```

Return: status


### socket_open_noblock

```perl
 my $status = $rmq->socket_open_noblock($socket, $host, $port, $struct_timeout);
```

Return: status


### login

```perl
 my $status = $rmq->login($conn, $vhost, $channel_max, $frame_max, $heartbeat, $sasl_method);
```

Return: status


### channel_open

```perl
 my $status = $rmq->channel_open($conn, $channel);
```

Return: status


### socket_get_sockfd

```perl
 my $res = $rmq->socket_get_sockfd($socket);
```

Return: variable


### get_socket

```perl
 my $amqp_socket_t  = $rmq->get_socket($conn);
```

Return: amqp_socket_t 


### channel_close

```perl
 my $status = $rmq->channel_close($conn, $channel, $code);
```

Return: status


### connection_close

```perl
 my $status = $rmq->connection_close($conn, $code);
```

Return: status


### destroy_connection

```perl
 my $status = $rmq->destroy_connection($conn);
```

Return: status


## SSL

### ssl_socket_new

```perl
 my $amqp_socket_t = $rmq->ssl_socket_new($conn);
```

Return: amqp_socket_t


### ssl_socket_set_key

```perl
 my $status = $rmq->ssl_socket_set_key($socket, $cert, $key);
```

Return: status


### set_initialize_ssl_library

```perl
 $rmq->set_initialize_ssl_library($do_initialize);
```

### ssl_socket_set_cacert

```perl
 my $status = $rmq->ssl_socket_set_cacert($socket, $cacert);
```

Return: status


### ssl_socket_set_key_buffer

```perl
 my $status = $rmq->ssl_socket_set_key_buffer($socket, $cert, $key, $n);
```

Return: status


### ssl_socket_set_verify

```perl
 $rmq->ssl_socket_set_verify($socket, $verify);
```

## Basic Publish/Consume

### basic_publish

```perl
 my $status = $rmq->basic_publish($conn, $channel, $exchange, $routing_key, $mandatory, $immediate, $properties, $body);
```

Return: status


### basic_consume

```perl
 my $status = $rmq->basic_consume($conn, $channel, $queue, $consumer_tag, $no_local, $no_ack, $exclusive);
```

Return: status


### basic_get

```perl
 my $status = $rmq->basic_get($conn, $channel, $queue, $no_ack);
```

Return: status


### basic_ack

```perl
 my $status = $rmq->basic_ack($conn, $channel, $delivery_tag, $multiple);
```

Return: status


### basic_nack

```perl
 my $status = $rmq->basic_nack($conn, $channel, $delivery_tag, $multiple, $requeue);
```

Return: status


### basic_reject

```perl
 my $status = $rmq->basic_reject($conn, $channel, $delivery_tag, $requeue);
```

Return: status


## Consume

### consume_message

```perl
 my $status = $rmq->consume_message($conn, $envelope, $struct_timeout, $flags);
```

Return: status


## Queue

### queue_declare

```perl
 my $status = $rmq->queue_declare($conn, $channel, $queue, $passive, $durable, $exclusive, $auto_delete);
```

Return: status


### queue_bind

```perl
 my $status = $rmq->queue_bind($conn, $channel, $queue, $exchange, $routing_key);
```

Return: status


### queue_unbind

```perl
 my $status = $rmq->queue_unbind($conn, $channel, $queue, $exchange, $routing_key);
```

Return: status


## Exchange

### exchange_declare

```perl
 my $status = $rmq->exchange_declare($conn, $channel, $exchange, $type, $passive, $durable, $auto_delete, $internal);
```

Return: status


## Envelope

### envelope_get_redelivered

```perl
 my $res = $rmq->envelope_get_redelivered($envelope);
```

Return: variable


### envelope_get_channel

```perl
 my $res = $rmq->envelope_get_channel($envelope);
```

Return: variable


### envelope_get_exchange

```perl
 my $res = $rmq->envelope_get_exchange($envelope);
```

Return: variable


### envelope_get_routing_key

```perl
 my $res = $rmq->envelope_get_routing_key($envelope);
```

Return: variable


### destroy_envelope

```perl
 $rmq->destroy_envelope($envelope);
```

### envelope_get_consumer_tag

```perl
 my $res = $rmq->envelope_get_consumer_tag($envelope);
```

Return: variable


### envelope_get_delivery_tag

```perl
 my $res = $rmq->envelope_get_delivery_tag($envelope);
```

Return: variable


### envelope_get_message_body

```perl
 my $res = $rmq->envelope_get_message_body($envelope);
```

Return: variable


## Types

### type_create_envelope

```perl
 my $amqp_envelope_t = $rmq->type_create_envelope();
```

Return: amqp_envelope_t


### type_destroy_envelope

```perl
 $rmq->type_destroy_envelope($envelope);
```

### type_create_timeout

```perl
 my $struct_timeval = $rmq->type_create_timeout($timeout_sec);
```

Return: struct_timeval


### type_destroy_timeout

```perl
 $rmq->type_destroy_timeout($timeout);
```

### type_create_basic_properties

```perl
 my $amqp_basic_properties_t = $rmq->type_create_basic_properties();
```

Return: amqp_basic_properties_t


### type_destroy_basic_properties

```perl
 my $status = $rmq->type_destroy_basic_properties($props);
```

Return: status


## For a Basic Properties

### set_prop_app_id

```perl
 $rmq->set_prop_app_id($props, $value);
```

### set_prop_content_type

```perl
 $rmq->set_prop_content_type($props, $value);
```

### set_prop_reply_to

```perl
 $rmq->set_prop_reply_to($props, $value);
```

### set_prop_priority

```perl
 $rmq->set_prop_priority($props, $priority);
```

### set_prop__flags

```perl
 $rmq->set_prop__flags($props, $flags);
```

### set_prop_user_id

```perl
 $rmq->set_prop_user_id($props, $value);
```

### set_prop_delivery_mode

```perl
 $rmq->set_prop_delivery_mode($props, $delivery_mode);
```

### set_prop_message_id

```perl
 $rmq->set_prop_message_id($props, $value);
```

### set_prop_timestamp

```perl
 $rmq->set_prop_timestamp($props, $timestamp);
```

### set_prop_cluster_id

```perl
 $rmq->set_prop_cluster_id($props, $value);
```

### set_prop_correlation_id

```perl
 $rmq->set_prop_correlation_id($props, $value);
```

### set_prop_expiration

```perl
 $rmq->set_prop_expiration($props, $value);
```

### set_prop_type

```perl
 $rmq->set_prop_type($props, $value);
```

### set_prop_content_encoding

```perl
 $rmq->set_prop_content_encoding($props, $value);
```

## Other

### data_in_buffer

```perl
 my $amqp_boolean_t = $rmq->data_in_buffer($conn);
```

Return: amqp_boolean_t


### maybe_release_buffers

```perl
 $rmq->maybe_release_buffers($conn);
```

### error_string

```perl
 my $res = $rmq->error_string($error);
```

Return: variable


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

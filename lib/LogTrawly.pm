package LogTrawly;

use Mojo::Base 'CallBackery';
use CallBackery::Model::ConfigJsonSchema;

=head1 NAME

LogTrawly - the application class

=head1 SYNOPSIS

 use Mojolicious::Commands;
 Mojolicious::Commands->start_app('LogTrawly');

=head1 DESCRIPTION

Configure the mojolicious engine to run our application logic

=cut

=head1 ATTRIBUTES

LogTrawly has all the attributes of L<CallBackery> plus:

=cut

=head2 config

use our own plugin directory and our own configuration file:

=cut

has config => sub {
    my $self = shift;
    my $config = CallBackery::Model::ConfigJsonSchema->new(
        app => $self,
        file => $ENV{LogTrawly_CONFIG} || $self->home->rel_file('etc/log-trawly.yaml')
    );
    unshift @{$config->pluginPath}, 'LogTrawly::GuiPlugin';
    my $schema = $config->schema;
    $schema->{properties}{BACKEND}{properties}{log_folder} = {type => 'string'};
    push @{$schema->{properties}{BACKEND}{required}}, 'log_folder';
    $schema->{properties}{BACKEND}{properties}{cache_folder} = {type => 'string'};
    push @{$schema->{properties}{BACKEND}{required}}, 'cache_folder';
    return $config;
};


has database => sub {
    my $self = shift;
    my $database = $self->SUPER::database(@_);
    $database->sql->migrations
        ->name('LogTrawlyBaseDB')
        ->from_data(__PACKAGE__,'appdb.sql')
        ->migrate;
    return $database;
};

1;

=head1 COPYRIGHT

Copyright (c) 2022 by Lukas Derendinger. All rights reserved.

=head1 AUTHOR

S<Lukas Derendinger E<lt>lukas@E<gt>>

=cut

__DATA__

@@ appdb.sql

-- 1 up

CREATE TABLE search (
    search_id    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    search_file TEXT NOT NULL,
    search_path TEXT,
    search_result TEXT
);

-- add an extra right for people who can edit

INSERT INTO cbright (cbright_key,cbright_label)
    VALUES ('write','Editor');

-- 1 down

DROP TABLE search;

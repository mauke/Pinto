# ABSTRACT: Interface to the Pinto database

package Pinto::Database;

use Moose;

use Pinto::Schema;

use namespace::autoclean;

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------
# Attributes

has schema => (
   is         => 'ro',
   isa        => 'Pinto::Schema',
   builder    => '_build_schema',
   init_arg   => undef,
   lazy       => 1,
);

#-------------------------------------------------------------------------------
# Roles

with qw( Pinto::Role::Configurable
         Pinto::Role::Loggable
         Pinto::Role::PathMaker );

#-------------------------------------------------------------------------------
# Builders

sub _build_schema {
    my ($self) = @_;

    my $schema = Pinto::Schema->new( config => $self->config,
                                     logger => $self->logger );

    my $db_file = $self->config->db_file;
    my $dsn     = "dbi:SQLite:$db_file";
    my $xtra    = {on_connect_call => 'use_foreign_keys'};
    my @args    = ($dsn, undef, undef, $xtra);
    
    my $schema_connected = $schema->connect(@args);

    # EXPERIMENTAL: Disabling synchronous FS writes makes things
    # much, much faster.  But this exposes us to possible data
    # loss if the OS crashes or power is lost.  We should be ok
    # if the app crashes though, which is far more likely.
    $schema_connected->storage->dbh->do('PRAGMA synchronous=OFF');

    return $schema_connected;
}

#-------------------------------------------------------------------------------

sub deploy {
    my ($self) = @_;

    $self->mkpath( $self->config->db_dir );
    $self->schema->deploy;

    return $self;
}

#-------------------------------------------------------------------------------

sub select_distributions {
    my ($self, $where, $attrs) = @_;

    $attrs ||= {};
    $attrs->{prefetch} ||= 'packages';

    return $self->schema->distribution_rs->search($where, $attrs);
}

#-------------------------------------------------------------------------------

sub select_distribution {
    my ($self, $where, $attrs) = @_;

    $attrs ||= {};
    $attrs->{prefetch} ||= 'packages';
    $attrs->{key}      ||= 'author_canonical_archive_unique';

    return $self->schema->distribution_rs->find($where, $attrs);
}

#-------------------------------------------------------------------------------

sub select_packages {
    my ($self, $where, $attrs) = @_;

    $attrs ||= {};
    $attrs->{prefetch} ||= 'distribution';

    return $self->schema->package_rs->search($where, $attrs);
}

#-------------------------------------------------------------------------------

sub select_registration {
  my ($self, $where, $attrs) = @_;

  $attrs ||= {};
  $attrs->{prefetch} ||= [ {package => 'distribution'}, 'kommit' ];

  return $self->schema->registration_rs->find($where, $attrs);
}

#-------------------------------------------------------------------------------

sub select_registrations {
    my ($self, $where, $attrs) = @_;

    $attrs ||= {};
    $attrs->{prefetch} ||= [ qw( package kommit ) ];

    return $self->schema->registration_rs->search($where, $attrs);
}

#-------------------------------------------------------------------------------

sub select_stacks {
    my ($self, $where, $attrs) = @_;

    return $self->schema->stack_rs->search( $where, $attrs );
}

#-------------------------------------------------------------------------------

sub select_stack {
    my ($self, $where, $attrs) = @_;

    $attrs ||= {};
    $attrs->{key} = 'name_canonical_unique';
    $where->{name_canonical} ||= lc delete $where->{name};

    return $self->schema->stack_rs->find( $where, $attrs );
}

#-------------------------------------------------------------------------------

sub select_kommit {
  my ($self, $where, $attrs) = @_;

    return $self->schema->kommit_rs->find( $where, $attrs );
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#-------------------------------------------------------------------------------

1;

__END__

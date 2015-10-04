package Graph::Weighted;

# ABSTRACT: A weighted graph implementation

our $VERSION = '0.5902';

use warnings;
use strict;

use parent qw(Graph);

use Carp qw( croak );
use Readonly;
Readonly my $WEIGHT => 'weight';

=head1 SYNOPSIS

 use Graph::Weighted;

 my $gw = Graph::Weighted->new();
 $gw->populate(
    [ [ 0, 1, 2, 0, 0 ], # Vertex 0 with 2 edges of weight 3
      [ 1, 0, 3, 0, 0 ], #    "   1      2 "               4
      [ 2, 3, 0, 0, 0 ], #    "   2      2 "               5
      [ 0, 0, 1, 0, 0 ], #    "   3      1 "               1
      [ 0, 0, 0, 0, 0 ], #    "   4      0 "               0
    ]
 );
 for my $vertex (sort { $a <=> $b } $gw->vertices) {
    warn sprintf "vertex: %s weight=%.2f\n",
        $vertex, $gw->get_weight($vertex);
    for my $neighbor (sort { $a <=> $b } $gw->neighbors($vertex)) {
        warn sprintf "\tedge to: %s weight=%.2f\n",
            $neighbor, $gw->get_weight([$vertex, $neighbor]);
    }
 }

 my ($lightest, $heaviest) = $gw->vertex_span();
 ($lightest, $heaviest) = $gw->edge_span();

 my $weight = $gw->path_cost(\@vertices);

 my $attr = 'probability';
 $gw = Graph::Weighted->new();
 $gw->populate(
    {
        0 => { label => 'A', 1 => 0.4, 3 => 0.6 }, # Vertex A with 2 edges, weight 1
        1 => { label => 'B', 0 => 0.3, 2 => 0.7 }, # Vertex B "    2 "
        2 => { label => 'C', 0 => 0.5, 2 => 0.5 }, # Vertex C "    2 "
        3 => { label => 'D', 0 => 0.2, 1 => 0.8 }, # Vertex D "    2 "
    },
    $attr
 );
 for my $vertex (sort { $a <=> $b } $gw->vertices) {
    warn sprintf "%s vertex: %s %s=%.2f\n",
        $gw->get_vertex_attribute($vertex, 'label'),
        $vertex, $attr, $gw->get_cost($vertex, $attr);
    for my $neighbor (sort { $a <=> $b } $gw->neighbors($vertex)) {
        warn sprintf "\tedge to: %s %s=%.2f\n",
            $neighbor, $attr, $gw->get_cost([$vertex, $neighbor], $attr);
    }
 }

=head1 DESCRIPTION

A C<Graph::Weighted> object is a subclass of the L<Graph> module with 
attribute handling.  As such, all of the L<Graph> methods may be used
as documented, but with the addition of custom weighting.

=head1 METHODS

=head2 new()

  my $gw = Graph::Weighted->new;

Return a new C<Graph::Weighted> object.

Please see L<Graph/Constructors> for the possible constructor arguments.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    bless $self, $class;
    return $self;
}

=head2 populate()

  $gw->populate($matrix);
  $gw->populate($matrix, $attribute);
  $gw->populate(\@vectors);
  $gw->populate(\@vectors, $attribute);
  $gw->populate(\%data_points);
  $gw->populate(\%data_points, $attribute);

Populate a graph with weighted nodes.

For arguments, the data can be an arrayref of numeric vectors, a
C<Math::MatrixReal> object, or a hashref of numeric edge values.  The
C<attribute> is an optional string name, with the default "weight."

Examples of vertices in array reference form:

  []      1 vertex with no edges.
  [0]     1 vertex with no edges.
  [1]     1 vertex and 1 edge to itself, weight 1.
  [0,1]   2 vertices and 1 edge, weight 1.
  [1,0,9] 3 vertices and 2 edges having, weight 10.
  [1,2,3] 3 vertices and 3 edges having, weight 6.

Multiple attributes may be applied to a graph, thereby layering and increasing
the overall dimension.

=cut

sub populate {
    my ($self, $data, $attr) = @_;

    # Set the default attribute.
    $attr ||= $WEIGHT;

    # What type of data are we given?
    my $data_ref = ref $data;

    if ($data_ref eq 'ARRAY' || $data_ref eq 'Math::Matrix') {
        my $vertex = 0; # Initial vertex id.
        for my $neighbors (@$data) {
            $self->_from_array(
                $vertex, $neighbors, $attr
            );
            $vertex++; # Move on to the next vertex...
        }
    }
    elsif ($data_ref eq 'HASH') {
        for my $vertex (keys %$data) {
            if ( $data->{$vertex}{label} ) {
                my $label = delete $data->{$vertex}{label};
                $self->set_vertex_attribute($vertex, 'label', $label);
            }
            $self->_from_hash(
                $vertex, $data->{$vertex}, $attr
            );
        }
    }
    else {
        croak "Unknown data type: $data\n";
    }
}

sub _from_array {
    my ($self, $vertex, $neighbors, $attr) = @_;

    # Initial vertex weight
    my $vertex_weight = 0;

    # Make nodes and edges.
    for my $n (0 .. @$neighbors - 1) {
        my $w = $neighbors->[$n]; # Weight of the edge to the neighbor.
        next unless $w; # TODO Skip zero weight nodes if requested?

        # Add a node-node edge to the graph.
        $self->add_edge($vertex, $n);

        $self->set_edge_attribute($vertex, $n, $attr, $w);

        # Tally the weight of the vertex.
        $vertex_weight += $w;
    }

    # Set the weight of the graph node.
    $self->set_vertex_attribute($vertex, $attr, $vertex_weight);
}

sub _from_hash {
    my ($self, $vertex, $neighbors, $attr) = @_;

    # Initial vertex weight
    my $vertex_weight = 0;

    # Handle terminal nodes.
    if (ref $neighbors) {
        # Make nodes and edges.
        for my $n (keys %$neighbors) {
            my $w = $neighbors->{$n}; # Weight of the edge to the neighbor.

            # Add a node-node edge to the graph.
            $self->add_edge($vertex, $n);

            $self->set_edge_attribute($vertex, $n, $attr, $w);

            # Tally the weight of the vertex.
            $vertex_weight += $w;
        }
    }
    else {
        $vertex_weight = $neighbors;
    }

    # Set the weight of the graph node.
    $self->set_vertex_attribute($vertex, $attr, $vertex_weight);
}

=head2 get_weight()

  $w = $gw->get_weight($vertex);
  $w = $gw->get_weight([$vertex, $neighbor]);

Return the weight for the vertex or edge.

=cut

sub get_weight {
    my $self = shift;
    return $self->get_cost(@_);
}

=head2 get_cost()

  $w = $gw->get_cost($vertex);
  $w = $gw->get_cost($vertex, $attribute);
  $w = $gw->get_cost(\@edge);
  $w = $gw->get_cost(\@edge, $attribute);

Return the named attribute value for the vertex or edge.

=cut

sub get_cost {
    my ($self, $v, $attr) = @_;
    croak 'ERROR: No vertex given to get_cost()' unless defined $v;

    # Default to weight.
    $attr ||= $WEIGHT;

    # Return the edge attribute if given a list.
    return $self->get_edge_attribute(@$v, $attr) || 0 if ref $v eq 'ARRAY';

    # Return the vertex attribute if given a scalar.
    return $self->get_vertex_attribute($v, $attr) || 0;
}

=head2 vertex_span()

 my ($lightest, $heaviest) = $gw->vertex_span();
 my ($lightest, $heaviest) = $gw->vertex_span($attr);

Return the lightest and heaviest vertices.

=cut

sub vertex_span {
    my ($self, $attr) = @_;

    my $mass = {};
    for my $vertex ( $self->vertices ) {
        $mass->{$vertex} = $self->get_cost($vertex, $attr);
    }

    my ($smallest, $biggest);
    for my $vertex ( keys %$mass ) {
        my $current = $mass->{$vertex};
        if ( !defined $smallest || $smallest > $current ) {
            $smallest = $current;
        }
        if ( !defined $biggest || $biggest < $current ) {
            $biggest = $current;
        }
    }

    my ($lightest, $heaviest) = ([], []);
    for my $vertex ( keys %$mass ) {
        push @$lightest, $vertex if $mass->{$vertex} == $smallest;
        push @$heaviest, $vertex if $mass->{$vertex} == $biggest;
    }

    return $lightest, $heaviest;
}

=head2 edge_span()

 my ($lightest, $heaviest) = $gw->edge_span();
 my ($lightest, $heaviest) = $gw->edge_span($attr);

Return the lightest to heaviest edges.

=cut

sub edge_span {
    my ($self, $attr) = @_;

    my $mass = {};
    for my $edge ( $self->edges ) {
        $mass->{ $edge->[0] . '_' . $edge->[1] } = $self->get_cost($edge, $attr);
    }

    my ($smallest, $biggest);
    for my $edge ( keys %$mass ) {
        my $current = $mass->{$edge};
        if ( !defined $smallest || $smallest > $current ) {
            $smallest = $current;
        }
        if ( !defined $biggest || $biggest < $current ) {
            $biggest = $current;
        }
    }

    my ($lightest, $heaviest) = ([], []);
    for my $edge ( sort keys %$mass ) {
        my $arrayref = [ split /_/, $edge ];
        push @$lightest, $arrayref if $mass->{$edge} == $smallest;
        push @$heaviest, $arrayref if $mass->{$edge} == $biggest;
    }

    return $lightest, $heaviest;
}


=head2 path_cost()

 my $weight = $gw->path_cost(\@vertices);
 my $weight = $gw->path_cost(\@vertices, $attr);

Return the summed weight (or given cost attribute) of the path edges.

=cut

sub path_cost {
    my ($self, $path, $attr) = @_;

    return unless $self->has_path( @$path );

    my $path_cost = 0;

    for my $i ( 0 .. @$path - 2 ) {
        $path_cost += $self->get_cost( [ $path->[$i], $path->[ $i + 1 ] ], $attr );
    }

    return $path_cost;
}

1;
__END__

=head1 TO DO

Find the total cost beneath a node.

=head1 SEE ALSO

L<Graph>

The F<eg/*> and F<t/*> file sources.

=cut

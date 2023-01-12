package LogTrawly::GuiPlugin::Info;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractHtml';
use Mojo::Asset::File;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use POSIX qw(strftime);
use autodie;
use Mojo::Util qw{dumper};

=head1 NAME

CbDemo::GuiPlugin::SongForm - Song Edit Form

=head1 SYNOPSIS

 use CbDemo::GuiPlugin::SongForm;

=head1 DESCRIPTION

The Song Edit Form

=cut

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractHtml> plus:

=cut

=head2 formCfg

Returns a Configuration Structure for the information pup-up on all text search possibilities.

=cut

has screenCfg => sub {
    my $self = shift;
    return {
        type => 'html',
        options => {},
    }
};


=head2 getData (parentFormData)

Return the data to be shown in the HTML field

=cut

sub getData {
    my $self = shift;
    my $parentFormData = shift;
    return '
<h3>Search without regular expressions:</h3>
<ul>
    <li>Multiple terms are seperated by spaces (<strong>"warning error"</strong> looks for <i>warning</i> AND <i>error</i>)</li>
    <li>You can search for special characters ($, &, ?, etc.) just like that</li>
</ul>
<br>

<h3>Using regular expressions for the search:</h3>
<ul>
    <li>Multiple terms or search patterns can be seperated by spaces (AND-logic)</li>
    <li>To look for <i>warning</i> OR <i>error</i>, use | (<strong>"warning|error"</strong>)</li>
    <li>For repeated characters, use the following search pattern: x{n}, looks for n-times the letter "x"</li>
    <li>Certain special characters have to be preceded by a backslash: \? \* \+</li>
</ul>
    ';
}

1;
__END__

=head1 AUTHOR

S<Lukas Derendinger E<lt>lukas@E<gt>>

=head1 HISTORY

 2022-06-12 lukas 0.0.1 first version

=cut

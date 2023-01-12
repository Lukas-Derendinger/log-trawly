package LogTrawly::GuiPlugin::Search;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use Mojo::Asset::File;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use POSIX qw(strftime);
use autodie;
use Mojo::Util qw{dumper};
use open qw< :encoding(UTF-8) >;

=head1 NAME

LogTrawly::GuiPlugin::Search - Simple log trawler plugin

=head1 SYNOPSIS

 use LogTrawly::GuiPlugin::Search;

=head1 DESCRIPTION

The simple Log-Trawly Search Gui.

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

=head2 formCfg

the user can specify an expression to grep for in the log file

=cut

has cfg => sub ($self) {
    $self->app->config->cfgHash->{BACKEND};
};

sub getCfg ($self) {
    state $cfg;
    return $cfg if keys %$cfg;
    $cfg = {};
    my $logfilepath = $self->cfg->{log_folder};

    opendir(my $dh, $logfilepath) || die "Can't opendir $logfilepath: $!";
    my @subdirs = grep { /^[^.]/ && -d "$logfilepath/$_" } readdir($dh);
    closedir $dh;

    for my $dir (@subdirs) {
        my $serverRx;
        if ($dir =~ /mail/) {
            $serverRx = qr{(\S+\s\S+\s\S+)\s(\S+\s\S+):\s(.+)};
        }
        else {
            $serverRx = qr{(\S+)\s(\S+\s\S+):\s(.+)};
        }
        my $subpath = $logfilepath."/".$dir;
        opendir(my $fh, $subpath) || die "Can't opendir $subpath: $!";
        my @newlogfiles = grep { /^[^.]/ && -f "$subpath/$_" } readdir($fh);
        for my $file (@newlogfiles) {
            $cfg->{$file} = {
                file => "$subpath/$file",
                rx => $serverRx,
                fields => [qw(date origin content)],
                title => trm($file),
            }
        }
        closedir $fh;
    }
    return $cfg
};

has formCfg => sub {
    my $self = shift;
    my $cfg = $self->getCfg;

    my @struct = ({ key => undef, title => trm('All files')});
    for my $key (sort keys %$cfg){
        push @struct,
            { key => $key, title => $cfg->{$key}{title} }
            if $cfg->{$key}{file} and -r $cfg->{$key}{file};
    }

    return [
        {
            key => 'file',
            widget => 'selectBox',
            cfg => {
                required => true,
                structure => \@struct,
            },
            set => {
                minWidth => 200,
                enabled => true,
                incrementalSearch => true
            },
        },
        {
            widget => 'text',
            key => 'grep',
            set => {
                placeholder => trm('Trawl your log files'),
                minWidth => 400
            }
        },
        {
            key => 'useGrep',
            label => 'Use regular expressions: ',
            widget => 'checkBox',
        },
    ];
};

has actionCfg => sub {
    my $self = shift;
    my $cfg = $self->getCfg;

    return [
        {
            label => trm('Infos on text-search'),
            key => 'info',
            action => 'popup',
            addToContextMenu => false,
            popupTitle => trm('Information on the text-search functions'),
            set => {
                minHeight => 600,
                minWidth => 500
            },
            options => {
                noReload => 1,
            },
            backend => {
                plugin => 'Info',
            }
        },
        {
            action => 'separator'
        },
        {
            label => trm('Email-follow'),
            key => 'email',
            action => 'popup',
            addToContextMenu => false,
            popupTitle => trm('All logs for this specific email'),
            set => {
                minHeight => 700,
                minWidth => 900
            },
            buttonSet => {
                enabled => false
            },
            options => {
                noReload => 1,
            },
            backend => {
                plugin => 'MailFollow',
            }
        },
    ];
};

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('Date & Time'),
            type => 'html',
            width => '2*',
            key => 'date',
        },
        {
            label => trm('Origin'),
            type => 'html',
            width => '2*',
            key => 'origin'
        },
        {
            label => trm('Content'),
            type => 'html',
            width => '10*',
            key => 'content'
        },
     ]
};

=head1 METHODS

all the methods from L<HinAgwConfig::GuiPluginTable> and these:

=head2 getTableData({formData=>{grep=>...,file=>},firstRow=>x,lastRow=>y,sortColumn=>'key',sortDesc=>true})

return the requested number of rows from the table

=cut


sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $file = $args->{formData}{file};
    my $cfg = $self->getCfg;

    my $count = 0;
    my $useGrep = $args->{formData}{useGrep} ? qr/$args->{formData}{useGrep}/ : undef;
    my $grep = $args->{formData}{grep} ? qr/$args->{formData}{grep}/ : undef;
    my @grepex;
    if ($grep) {
        $grep = substr($grep, 5, -1);
        @grepex = split(/\s+/, $grep);
    }
    my @grepexPos;
    my @grepexNeg;
    for my $grepTerm (@grepex) {
        if ($grepTerm =~ /^-/) {
            my $grepTermTrunc = substr($grepTerm, 1);
            push @grepexNeg, $grepTermTrunc;
        }
        else {
            push @grepexPos, $grepTerm;
        }
    }

    my $mode = '<';
    my @cfgKeys;
    if (defined($file)) {
        @cfgKeys = $file;
    }
    else {
        @cfgKeys = sort keys %$cfg;
    }

    for my $thisKey(@cfgKeys) {
        my @args;
        if (my $name = $cfg->{$thisKey}{file}) {
            @args = ($name);
        }

        my $fh;
        for ($cfg->{$thisKey}{file}) {
            /.log$/ && do {
                open($fh, $mode, @args);
            };
            /.gz$/ && do {
                open($fh, "gunzip -c $_ |") || die "can't open pipe to $_";
            };
        }

        if ($useGrep) {
            lineLoop1:
            while (<$fh>){
                for my $posGrepTerm (@grepexPos) {
                    next lineLoop1 if defined $grep and $_ !~ /$posGrepTerm/;
                }
                for my $negGrepTerm (@grepexNeg) {
                    next lineLoop1 if defined $grep and $_ =~ /$negGrepTerm/;
                }
                $count++;
            }
        }
        else {
            lineLoop2:
            while (<$fh>){
                for my $posGrepTerm (@grepexPos) {
                    next lineLoop2 if defined $grep and index($_, $posGrepTerm) == -1;
                }
                for my $negGrepTerm (@grepexNeg) {
                    next lineLoop2 if defined $grep and index($_, $negGrepTerm) != -1;
                }
                $count++;
            }
        }
        close $fh;
    }
    return $count;
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $file = $args->{formData}{file};
    my $cfg = $self->getCfg;
    my @return;
    my @colors = qw/red blue limegreen darkorange deeppink DarkTurquoise violet steelblue silver silver silver/;

    my $firstRow = $args->{firstRow};
    my $rowCount = $args->{lastRow} - $args->{firstRow} + 1;
    my @cfgKeys;
    if (defined($file)) {
        @cfgKeys = $file;
    }
    else {
        @cfgKeys = sort keys %$cfg;
    }
    
    fileLoop:
    for my $thisKey(@cfgKeys) {
        my $c = $cfg->{$thisKey};
        my @fields = @{$c->{fields}};
        my $rx = $c->{rx};
        my $useGrep = $args->{formData}{useGrep} ? qr/$args->{formData}{useGrep}/ : undef;
        my $grepRx = $args->{formData}{grep} ? qr/$args->{formData}{grep}/ : undef;
        my @grepex;
        if ($grepRx) {
            $grepRx = substr($grepRx, 5, -1);
            @grepex = split(/\s+/, $grepRx);
        }
        my @args;
        my $mode = '<';
        if (my $name = $cfg->{$thisKey}{file}) {
            @args = ($name);
        }

        my $fh;
        # Perl's switch case construct
        for ($cfg->{$thisKey}{file}) {
            /.log$/ && do {
                open($fh, $mode, @args);
            };
            /.gz$/ && do {
                open($fh, "gunzip -c $_ |") || die "can't open pipe to $_";
            };
        }
        lineLoop3:
        while (<$fh>){
            for my $grepTerm (@grepex) {
                if ($grepTerm =~ /^\-/) {
                    my $grepTermTrunc = substr($grepTerm, 1);
                    if ($useGrep) {
                        next lineLoop3 if defined $grepRx and $_ =~ /$grepTermTrunc/;
                    }
                    else {
                        next lineLoop3 if defined $grepRx and index($_, $grepTermTrunc) != -1;
                    }
                }
                else {
                    if ($useGrep) {
                        next lineLoop3 if defined $grepRx and $_ !~ /$grepTerm/;
                    }
                    else {
                        next lineLoop3 if defined $grepRx and index($_, $grepTerm) == -1;
                    }
                }
            }
            next if $firstRow-- > 0; # skip while we are before the first row
            last fileLoop if $rowCount-- == 0; # stop if we have enough rows
            my %row;
            $_ =~ s/</&lt;/g;
            @row{@fields} = ($_ =~ $rx);

            my $mailFollowLink = false;
            if ($row{content} =~ qr{^\w{10,11}:\s(to|from|message|client|uid|removed){1}}) {
                $mailFollowLink = true;
            }
            $row{_actionSet} = {
                email => {
                    enabled => $mailFollowLink
                },
            };

            my $grepCount = 0;
            for my $grepTerm (@grepex) {
                for my $field (@fields) {
                    if ($grepTerm !~ /^\-/) {
                        if ($useGrep) {
                            if (defined $grepRx and $row{$field} =~ /$grepTerm/) {
                                my @finding = ($row{$field} =~ qr{(.+)($grepTerm)(.+)});
                                my $replace = "<span style=\"color:$colors[$grepCount]\"><strong>$finding[1]</strong></span>";
                                $row{$field} =~ s/$grepTerm/$replace/g;
                            }
                        }
                        else {
                            if (defined $grepRx and $row{$field} =~ /\Q$grepTerm\E/) {
                                my $replace = "<span style=\"color:$colors[$grepCount]\"><strong>$grepTerm</strong></span>";
                                $row{$field} =~ s/$grepTerm/$replace/g;
                            }
                        }
                    }
                }
                $grepCount++;
            }
            push @return, \%row;
        }
        close $fh;
    }
    return \@return;
}

1;
__END__

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 COPYRIGHT

Copyright (c) 2022 by OETIKER+PARTNER AG. All rights reserved.

=head1 AUTHORS

S<Lukas DerendingerE<lt>lukas.derendinger@mac.comE<gt>>
S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2022-11-05 to 0.1.0 first version

=cut

# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et

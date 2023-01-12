package LogTrawly::GuiPlugin::MailFollow;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use Mojo::Asset::File;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use POSIX qw(strftime);
use autodie;
use Mojo::Util qw{dumper};
use open qw< :encoding(UTF-8) >;
use Data::Dumper;
use Storable;

=head1 NAME

CbDemo::GuiPlugin::SongForm - Song Edit Form

=head1 SYNOPSIS

 use CbDemo::GuiPlugin::SongForm;

=head1 DESCRIPTION

The Song Edit Form

=cut

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

=head2 formCfg

Returns a Configuration Structure for the information pup-up on all text search possibilities.

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
            };
        }
        closedir $fh;
    }
    return $cfg
};


sub uniq {
    my %seen;
    my @unique;
    for my $item (@_) {
        push(@unique, $item) unless $seen{$item}++;
    }
    return @unique;
}


has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('Date & Time'),
            type => 'str',
            width => '3*',
            key => 'date',
        },
        {
            label => trm('Origin'),
            type => 'str',
            width => '4*',
            key => 'origin'
        },
        {
            label => trm('Content'),
            type => 'str',
            width => '15*',
            key => 'content'
        },
     ]
};


sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $cfg = $self->getCfg;
    my @allRows;

    my $content = $args->{parentFormData}{selection}{content};
    my $pregrep = $content ? qr/$content/ : undef;
    my @greps;
    if ($pregrep) {
        @greps = ($pregrep =~ qr{(\w{10,11}):\s[to|from|message|client|uid|removed]});
    }
    my $baseKey = $greps[0];
    my $messageID;
    my $rowCount = 0;
    my @childKeys;
    my $count = 0;

    my $cachePath = $self->cfg->{cache_folder};
    my $saveFile = "logTrawlySaveFile-$baseKey.log";
    my $cacheFileExists = 0;
    opendir(my $cfh, $cachePath) || die "Can't opendir $cachePath: $!";
    my @cacheFiles = grep { /^[^.]/ && -f "$cachePath/$_" } readdir($cfh);
    for my $cacheFile (@cacheFiles) {
        my $filetime = -M "$cachePath/$cacheFile";
        if ($filetime > 0.007) {
            unlink($cachePath."/".$cacheFile) or warn "Unable to unlink $cacheFile: $!";;
        }
        elsif ($cacheFile eq $saveFile) {
            $cacheFileExists = 1;
        }
    }
    closedir $cfh;

    if ($cacheFileExists) {
        my $rowsRef = retrieve("$cachePath/$saveFile");
        $count = $#$rowsRef + 1;
    }
    else {
        my @cfgKeys = sort keys %$cfg;

        fileloop1:
        for my $thisKey(@cfgKeys) {
            #my $c = $cfg->{$thisKey};
            my $fileName = $cfg->{$thisKey}{file};

            my $fh;
            for ($cfg->{$thisKey}{file}) {
                /.log$/ && do {
                    open($fh, "<", $fileName);
                };
                /.gz$/ && do {
                    open($fh, "gunzip -c $_ |") || die "can't open pipe to $_";
                };
            }
            while (<$fh>){
                next if defined $baseKey and index($_, $baseKey) == -1;
                $rowCount++;
                if ($rowCount == 2) {
                    my @mesID = ($_ =~ qr{message-id=<([^>]+)>});
                    $messageID = $mesID[0];
                    last fileloop1;
                }
            }
            close $fh;
        }

        fileloop2:
        for my $thisKey(@cfgKeys) {
        # my $c = $cfg->{$thisKey};
            my $fileName = $cfg->{$thisKey}{file};

            my $fh;
            for ($cfg->{$thisKey}{file}) {
                /.log$/ && do {
                    open($fh, "<", $fileName);
                };
                /.gz$/ && do {
                    open($fh, "gunzip -c $_ |") || die "can't open pipe to $_";
                };
            }
            while (<$fh>){
                next if defined $messageID and index($_, $messageID) == -1;
                push @allRows, $_;
                my @chiKey = ($_ =~ qr{(\w{10,11}):\s(?:to|from|message|client|uid|removed)});
                my $childKey = $chiKey[0];
                if (defined($childKey)) {
                    push @childKeys, $childKey;
                }
            }
            close $fh;
        }
        @childKeys = uniq(@childKeys);

        my $rx;
        my @fields;
        fileloop3:
        for my $thisKey(@cfgKeys) {
            my $c = $cfg->{$thisKey};
            @fields = @{$c->{fields}};
            my $fileName = $cfg->{$thisKey}{file};

            my $fh;
            for ($cfg->{$thisKey}{file}) {
                /.log$/ && do {
                    open($fh, "<", $fileName);
                };
                /.gz$/ && do {
                    open($fh, "gunzip -c $_ |") || die "can't open pipe to $_";
                };
            }
            lineloop:
            while (<$fh>){
                next if $_ !~ qr{(\w{10,11}):\s(?:to|from|message|client|uid|removed)};
                for my $childKey(@childKeys) {
                    next if index($_, $childKey) == -1;
                    push @allRows, $_;
                    $rx = $c->{rx};
                    if ($_ =~ qr{removed\s\[mail\.info\]}) {
                        my ($index) = grep { $childKeys[$_] eq $childKey } 0..$#childKeys;
                        if (defined $index) {
                            splice(@childKeys, $index, 1);
                        }
                        my $size = @childKeys;
                        last fileloop3 if $size == 0;
                    }
                    next lineloop;
                }
            }
            close $fh;
        }
        @allRows = uniq(@allRows);
        @allRows = sort(@allRows);

        my @saveRows;
        for my $singleRow (@allRows) {
            my %row;
            @row{@fields} = ($singleRow =~ $rx);
            push @saveRows, \%row;
        }

        store \@saveRows, "$cachePath/$saveFile";

        $count = $#allRows + 1;
    }
    return $count;
};


sub getTableData {
    my $self = shift;
    my $args = shift;

    my $content = $args->{parentFormData}{selection}{content};
    my $pregrep = $content ? qr/$content/ : undef;
    my @greps;
    if ($pregrep) {
        @greps = ($pregrep =~ qr{(\w{10,11}):\s(?:to|from|message|client|uid|removed)});
    }
    my $baseKey = $greps[0];
    
    my $cachePath = $self->cfg->{cache_folder};
    my $loadFile = "logTrawlySaveFile-$baseKey.log";

    my $rowsRef = retrieve("$cachePath/$loadFile");

    return $rowsRef;
};

1;
__END__

=head1 AUTHOR

S<Lukas Derendinger E<lt>lukas@E<gt>>

=head1 HISTORY

 2022-11-05 lukas 0.1.0 first version

=cut

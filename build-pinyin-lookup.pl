#!/usr/bin/env perl
use v5.14;
use utf8;
use JSON;
use File::Slurp;
use Unicode::Normalize qw(NFD);

use constant PINYIN_TYPE => {
    a => {
        pinyin => "HanYu",
    },
    c => {
        pinyin => "HanYu",
    },
    t => {
        trs => "TL"
    },
    h => {
        pinyin => "HanYu",
    }
};

my $JSON = JSON->new->utf8->canonical;
my $re_all_known_pinyin;

sub analyze_pinyin_field {
    my ($val) = @_;
    my @pinyin_tokens = grep { /\A[a-z]/ } split(/([a-z]+)/i, (NFD($val) =~ s/\p{Mark}//gr =~ s/ɑ/a/gr));
    if (defined $re_all_known_pinyin) {
        @pinyin_tokens = grep {
            $_
        } map {
            split(/($re_all_known_pinyin)/)
        } @pinyin_tokens;
    }

    return \@pinyin_tokens;
}

sub insert_index {
    my ($ctx, $pinyin_type, $title, $terms) = @_;
    my $idx = $ctx->{idx}{$pinyin_type};

    my (%pos, %freq);
    for (my $i = 0; $i < @$terms; $i++) {
        my $t = $terms->[$i];
        $freq{$t}++;
        push @{$pos{$t}},$i;
    }
    for my $t (keys %freq) {
        $idx->{$t}{$title} //= [$pos{$t}[0], 0];
        $idx->{$t}{$title}[1] += $freq{$t};
    }
}

sub sort_index {
    my ($ctx) = @_;

    for my $pinyin_type (keys %{$ctx->{idx}}) {
        my $idx = $ctx->{idx}{$pinyin_type};
        reset(%$idx);
        while (my ($term, $docs) = each %$idx) {
            my @rows = map {
                [ $_, $docs->{$_}[0], $docs->{$_}[1] ]
            } sort {
                length($a) <=> length($b)
                || $docs->{$a}[0] <=> $docs->{$b}[0]
                || $docs->{$b}[1] <=> $docs->{$a}[1]
            } keys %$docs;
            $idx->{$term} = \@rows;
        }        
    }
}

sub produce_lookup {
    my ($ctx) = @_;
    for my $pinyin_type (keys %{$ctx->{idx}}) {
        my $idx = $ctx->{idx}{$pinyin_type};
        reset(%$idx);
        while (my ($term, $docs) = each %$idx) {
            my $content = $JSON->encode([ map { $_->[0] } @$docs ]);
            write_file("lookup/pinyin/$ctx->{lang}/${pinyin_type}/${term}.json", $content);
        }
    }
}

my $lang = shift;
unless ($lang =~ /^[tahc]$/) {
    die << '.';
Please invoke this as one of:
    perl build-pinyin-lookup.pl a
    perl build-pinyin-lookup.pl t
    perl build-pinyin-lookup.pl h
    perl build-pinyin-lookup.pl c
.
}

my $dict_file = {
    a => "dict-revised.unicode.json",
    t => "dict-twblg.json",
    h => "dict-hakka.json",
    c => "dict-csld.json",
}->{$lang};

    
binmode STDERR, ":utf8";
mkdir "lookup";
mkdir "lookup/pinyin";
mkdir "lookup/pinyin/$lang";

# pinyin_type list from view.ls line 85..95
for my $pinyin_type ("HanYu", "HanYu-TongYong", "TongYong", "WadeGiles", "GuoYin", "TL", "TL-DT", "DT", "POJ") {
    mkdir("lookup/pinyin/${lang}/${pinyin_type}");
}

## ls -1 lookup/pinyin/a/*.json | cut -f 4 -d '/' | cut -f1 -d '.' | perl -MRegex::PreSuf=presuf -E 'my $re = presuf(<>); say $re'
if ($lang eq "c") {
    $re_all_known_pinyin = '(?:a(?:ir|n[gr]|[inor])|b(?:a(?:ir|n(?:gr|[gr])|or|[inor])|e(?:ir|n(?:gr|[gr])|[inr])|i(?:a(?:nr|or|[nor])|er|ng|[enr])|or|ur|[aiou])|c(?:a(?:ir|n[gr]|or|[inor])|e(?:ngr?|[nr])|h(?:a(?:ngr?|or|[inor])|e(?:n(?:gr|[gr])|[nr])|ir|o(?:ngr?|u)|u(?:a(?:ir|n(?:gr|[gr])|[inr])|or|[ainor])|[aeiu])|ir|o(?:ngr?|ur|u)|u(?:a(?:nr|[nr])|er|nr|or|[ino])|[aeiu])|d(?:a(?:ir|n(?:gr|[gr])|or|[inor])|e(?:ngr?|[inr])|i(?:a(?:nr|or|[nor])|er|ngr?|ur|[eru])|o(?:ngr?|ur|u)|u(?:a(?:nr|[nr])|er|ir|nr|or|[inor])|[aeiu])|e(?:ng|[nr])|f(?:a(?:n(?:gr|[gr])|[nr])|e(?:n(?:gr|[gr])|[inr])|ou|ur|[aou])|g(?:a(?:ir|n(?:gr|[gr])|or|[inor])|e(?:n(?:gr|[gr])|[inr])|o(?:ngr?|ur|u)|u(?:a(?:ir|n(?:gr|[gr])|[inr])|er|ir|nr|or|[ainor])|[aeu])|h(?:a(?:ir|n[gr]|or|[inor])|e(?:ir|ngr?|[inr])|o(?:ng|ur|u)|u(?:a(?:ir|n(?:gr|[gr])|[inr])|er|ir|nr|or|[ainor])|[aeu])|j(?:i(?:a(?:n[gr]|or|[nor])|er|n(?:gr|[gr])|ong|ur|[aenru])|u(?:a(?:nr|[nr])|er|[enr])|[iu])|k(?:a(?:ir|n[gr]|[inor])|e(?:ngr?|[nr])|o(?:ngr?|ur|u)|u(?:a(?:ir|n[gr]|[inr])|er|nr|[ainor])|[aeu])|l(?:a(?:n(?:gr|[gr])|or|[inor])|e(?:ngr?|[ir])|i(?:a(?:n(?:gr|[gr])|or|[nor])|er|ngr?|ur|[aenru])|o(?:ngr?|ur|u)|u(?:a(?:nr|[nr])|er|nr|or|[enor])|[aeiou])|m(?:a(?:n[gr]|or|[inor])|e(?:ir|n(?:gr|[gr])|[inr])|i(?:a(?:nr|or|[nor])|er|ngr?|[enru])|o[ru]|ur|[aeiou])|n(?:a(?:ngr?|or|[inor])|e(?:ng|[in])|i(?:a(?:n(?:gr|[gr])|or|[nor])|ng|ur|[enu])|o(?:ngr?|u)|u(?:a(?:nr|[nr])|er|[enor])|[aeiu])|ou|p(?:a(?:ir|n(?:gr|[gr])|or|[inor])|e(?:ir|n(?:gr|[gr])|[inr])|i(?:a(?:nr|or|[nor])|er|ng|[aenr])|o[ru]|ur|[aiou])|q(?:i(?:a(?:n(?:gr|[gr])|or|[nor])|er|n(?:gr|[gr])|ongr?|ur|[aenru])|u(?:a(?:nr|[nr])|er|[enr])|[iu])|r(?:a(?:ngr?|[no])|e(?:n[gr]|[nr])|ir|o(?:ng|ur|u)|u(?:a(?:nr|[nr])|[ino])|[eiu])|s(?:a(?:n(?:gr|[gr])|[inor])|e(?:ngr?|[inr])|h(?:a(?:ir|n(?:gr|[gr])|or|[inor])|e(?:n(?:gr|[gr])|[inr])|ir|our?|u(?:a(?:ngr?|[in])|er|ir|nr|or|[ainor])|[aeiu])|ir|o(?:ng|u)|u(?:an|er|ir|[ino])|[aeiu])|t(?:a(?:ir|n(?:gr|[gr])|or|[inor])|e(?:ngr?|r)|i(?:a(?:nr|or|[nor])|er|ngr?|[er])|o(?:ngr?|ur|u)|u(?:a(?:nr|[nr])|er|ir|[inor])|[aeiu])|w(?:a(?:n(?:gr|[gr])|[inr])|e(?:ir|n[gr]|[inr])|or|ur|[aou])|x(?:i(?:a(?:n(?:gr|[gr])|or|[nor])|er|n(?:gr|[gr])|ong|ur|[aenru])|u(?:a(?:nr|[nr])|er|nr|[enr])|[iu])|y(?:a(?:n(?:gr|[gr])|or|[inor])|er|i(?:n(?:gr|[gr])|[nr])|o(?:ng|ur|u)|u(?:a(?:nr|[nr])|er|[enr])|[aeiou])|z(?:a(?:ng|or|[inor])|e(?:ngr?|[inr])|h(?:a(?:n(?:gr|[gr])|or|[inor])|e(?:n(?:gr|[gr])|[inr])|ir|o(?:ngr?|ur|u)|u(?:a(?:n(?:gr|[gr])|[inr])|er|ir|nr|or|[ainor])|[aeiu])|ir|o(?:ngr?|u)|u(?:a(?:nr|[nr])|er|ir|or|[inor])|[aeiu])|[aeoq])';
}

my $dict = from_json(scalar read_file $dict_file, { binmode => ":utf8" });

my %ctx = (
    lang => $lang,
    idx => {
        HanYu => {},
        TL => {}
    }
);

my $bpmf_to_pinyin = {};
for (my $i = 0; $i < @$dict; $i++) {
    my $entry = $dict->[$i];
    my $title = $entry->{title};
    for my $heteronym (@{ $entry->{heteronyms} }) {
        for my $field (qw(pinyin trs)) {
            my $pinyin = $heteronym->{$field} or next;
            my $pinyin_tokens = analyze_pinyin_field($pinyin);
            insert_index( \%ctx, PINYIN_TYPE->{$lang}{$field}, $title, $pinyin_tokens);
        }
        if ($lang eq "a" and my $bpmf = $heteronym->{bopomofo} and my $pinyin = $heteronym->{pinyin}) {
            my $pinyin_tokens = analyze_pinyin_field($pinyin);
            my $bpmf_tokens   = [split(/[ ˊˇˋ˙]/, $bpmf)];
            if ( @$bpmf_tokens == @$pinyin_tokens ) {
                for my $i ( 0 .. $#$bpmf_tokens ) {
                    $bpmf_tokens->[$i] =~ s/\P{Bopomofo}//g;
                    $bpmf_to_pinyin->{ $bpmf_tokens->[$i] } //= $pinyin_tokens->[$i];
                }
            }
        }
    }
}

sort_index( \%ctx );
produce_lookup( \%ctx );



if (%$bpmf_to_pinyin) {
    open my $fh, ">:utf8", "bopomofo-to-pinyin.tsv";
    for (sort keys %$bpmf_to_pinyin) {
        next if /[ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ]ㄦ$/;
        my $s = $_ . "\t" . $bpmf_to_pinyin->{$_};
        say $fh $s;
    }
    close $fh;
}

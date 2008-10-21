package DBD::PO::Locale::PO;

use strict;
use warnings;

our $VERSION = '0.21.01';

use Carp qw(croak);
use English qw(-no_match_vars $EVAL_ERROR $OS_ERROR);

sub new {
    my ($this, %options) = @_;

    my $class = ref($this) || $this;
    my $self = bless {}, $class;
    $self->eol( $options{eol} );
    $self->_flags({});
    for (qw(
        msgid msgid_plural msgstr msgstr_n msgctxt
        comment fuzzy automatic reference obsolete
        loaded_line_number
    )) {
        if ( defined $options{"-$_"} ) {
            $self->$_( $options{"-$_"} );
        }
    }
    if ( defined $options{'-c-format'} ) {
        $self->c_format(1);
    }
    if ( defined $options{'-no-c-format'} ) {
        $self->c_format(0);
    }
    if ( defined $options{'-php-format'} ) {
        $self->php_format(1);
    }
    if ( defined $options{'-no-php-format'} ) {
        $self->php_format(0);
    }

    return $self;
}

sub eol {
    my ($self, @params) = @_;

    if (@params) {
        my $eol = shift @params;
        $self->{eol} = $eol;
    }

    return defined $self->{eol}
           ? $self->{eol}
           : "\n";
}

sub msgctxt {
    my ($self, @params) = @_;

    return @params
           ? $self->{msgctxt} = shift @params
           : $self->{msgctxt};
}

sub msgid {
    my ($self, @params) = @_;

    return @params
           ? $self->{msgid} = shift @params
           : $self->{msgid};
}

sub msgid_plural {
    my ($self, @params) = @_;

    return @params
           ? $self->{msgid_plural} = shift @params
           : $self->{msgid_plural};
}

sub msgstr {
    my ($self, @params) = @_;

    return @params
           ? $self->{msgstr} = shift @params
           : $self->{msgstr};
}

sub msgstr_n {
    my ($self, @params) = @_;

    if (@params) {
        my $hashref = shift @params;

        # check that we have a hashref.
        ref $hashref eq 'HASH'
            or croak 'Argument to msgstr_n must be a hashref: { n => "string n", ... }.';

        # Check that the keys are all numbers.
        for ( keys %{$hashref} ) {
            croak 'Keys to msgstr_n hashref must be numbers'
                if ! defined $_ || m{\D}xms;
        }

        # Write all the values in the hashref.
        @{ $self->{msgstr_n} }{ keys %{$hashref} } = values %{$hashref};
    }

    return $self->{msgstr_n};
}

sub comment {
    my ($self, @params) = @_;

    return @params
           ? $self->{comment} = shift @params
           : $self->{comment};
}

sub automatic {
    my ($self, @params) = @_;

    return @params
           ? $self->{automatic} = shift @params
           : $self->{automatic};
}

sub reference {
    my ($self, @params) = @_;

    return @params
           ? $self->{reference} = shift @params
           : $self->{reference};
}

sub obsolete {
    my ($self, @params) = @_;

    return @params
           ? $self->{obsolete} = shift @params
           : $self->{obsolete};
}

sub fuzzy {
    my ($self, @params) = @_;

    if (@params) {
        my $value = shift @params;
        return $value
               ? $self->add_flag('fuzzy')
               : $self->remove_flag('fuzzy');
    }

    return $self->has_flag('fuzzy');
}

sub c_format {
    my ($self, @params) = @_;

    return $self->_tri_value_flag('c-format', @params);
}

sub php_format {
    my ($self, @params) = @_;

    return $self->_tri_value_flag('php-format', @params);
}

sub _flags {
    my ($self, @params) = @_;

    return @params
           ? $self->{_flags} = shift @params
           : $self->{_flags};
}

sub _tri_value_flag {
    my ($self, $flag_name, @params) = @_;

    if (@params) { # set or clear the flags
        my $value = shift @params;
        if (! defined($value) || ! length $value) {
            $self->remove_flag($flag_name);
            $self->remove_flag("no-$flag_name");
            return scalar +();
        }
        elsif ($value) {
            $self->add_flag($flag_name);
            $self->remove_flag("no-$flag_name");
            return 1;
        }
        else {
            $self->add_flag("no-$flag_name");
            $self->remove_flag($flag_name);
            return 0;
        }
    }
    else { # check the flags
        return 1 if $self->has_flag($flag_name);
        return 0 if $self->has_flag("no-$flag_name");
        return scalar +();
    }
}

sub add_flag {
    my ($self, $flag_name) = @_;

    $self->_flags()->{$flag_name} = 1;

    return;
}

sub remove_flag {
    my ($self, $flag_name) = @_;

    delete $self->_flags()->{$flag_name};

    return;
}

sub has_flag {
    my ($self, $flag_name) = @_;

    my $flags = $self->_flags();

    exists $flags->{$flag_name}
        or return;
    return $flags->{$flag_name};
}

sub loaded_line_number {
    my ($self, @params) = @_;

    return @params
           ? $self->{loaded_line_number} = shift @params
           : $self->{loaded_line_number};
}

sub dump { ## no critic (BuiltinHomonyms)
    my $self = shift;

    my $obsolete = $self->obsolete() ? '#~ ' : q{};
    my $dump = q{};
    if ( defined $self->comment() ) {
        $dump .= $self->_dump_multi_comment( $self->comment(), '# ' );
    }
    if ( defined $self->automatic() ) {
        $dump .= $self->_dump_multi_comment( $self->automatic(), '#. ' );
    }
    if ( defined $self->reference() ) {
        $dump .= $self->_dump_multi_comment( $self->reference(), '#: ' );
    }
    my $flags = join q{}, map {", $_"} sort keys %{ $self->_flags() };
    if ($flags) {
        $dump .= "#$flags"
                 . $self->eol();
    }
    if ( defined $self->msgctxt() ) {
        $dump .= "${obsolete}msgctxt "
                 . $self->quote( $self->msgctxt() );
    }
    $dump .= "${obsolete}msgid "
             . $self->quote( $self->msgid() );
    if ( defined $self->msgid_plural() ) {
        $dump .= "${obsolete}msgid_plural "
                 . $self->quote( $self->msgid_plural() );
    }
    if ( defined $self->msgstr() ) {
        $dump .= "${obsolete}msgstr "
                 . $self->quote( $self->msgstr() );

    }
    if ( my $msgstr_n = $self->msgstr_n() ) {
        $dump .= join
            q{},
            map {
                "${obsolete}msgstr[$_] "
                . $self->quote( $msgstr_n->{$_} );
            } sort {
                $a <=> $b
            } keys %{$msgstr_n};
    }

    $dump .= $self->eol();

    return $dump;
}

sub _dump_multi_comment {
    my $self    = shift;
    my $comment = shift;
    my $leader  = shift;

    my $eol = $self->eol();

    return join q{}, map {
        "$leader$_$eol";
    } split m{\Q$eol\E}xms, $comment;
}

# Quote a string properly
sub quote {
    my $self   = shift;
    my $string = shift;

    if (! defined $string) {
        return q{""};
    }
    my %named = (
        ## no critic (InterpolationOfLiterals)
        #qq{\a} => qq{\\a}, # BEL
        #qq{\b} => qq{\\b}, # BS
        #qq{\t} => qq{\\t}, # TAB
        qq{\n}  => qq{\\n}, # LF
        #qq{\f} => qq{\\f}, # FF
        #qq{\r} => qq{\\r}, # CR
        qq{"}   => qq{\\"},
        qq{\\}  => qq{\\\\},
        ## use critic (InterpolationOfLiterals)
    );
    $string =~ s{
        ( [^ !#$%&'()*+,\-.\/0-9:;<=>?@A-Z\[\]\^_`a-z{|}~] )
    }{
        ord $1 < 0x80
        ? (
            exists $named{$1}
            ? $named{$1}
            : sprintf '\x%02x', ord $1
        )
        : $1;
    }xmsge;
    $string = qq{"$string"};
    # multiline
    my $eol = $self->eol();
    if ($string =~ s{\A ( " .*? \\n )}{""$eol$1}xms) {
        $string =~ s{\\n}{\\n"$eol"}xmsg;
    }

    return "$string$eol";
}

sub dequote {
    my $self   = shift;
    my $string = shift;
    my $eol    = shift || $self->eol();

    if (! defined $string) {
        $string = q{};
    }
    # multiline
    if ($string =~ s{\A "" \Q$eol\E}{}xms) {
        $string =~ s{\\n"\Q$eol\E"}{\\n}xmsg;
    }
    $string =~ s{( [\$\@] )}{\\$1}xmsg; # make uncritical
    ($string) = $string =~ m{
        \A
        (
            "
            (?: \\\\ | \\" | [^"] )*
            "
            # eol
        )
    }xms; # check the quoted string and untaint
    return q{} if ! defined $string;
    my $dequoted = eval $string; ## no critic (StringyEval)
    croak qq{Can not eval string "$string": $EVAL_ERROR} if $EVAL_ERROR;

    return $dequoted;
}

sub save_file_fromarray {
    my ($self, @params) = @_;

    return $self->_save_file(@params, 0);
}

sub save_file_fromhash {
    my ($self, @params) = @_;

    return $self->_save_file(@params, 1);
}

sub _save_file {
    my $self     = shift;
    my $file     = shift;
    my $entries  = shift;
    my $as_hash  = shift;

    open my $out, '>', $file ## no critic (BriefOpen)
        or croak "Open $file: $OS_ERROR";
    if ($as_hash) {
        for (sort keys %{$entries}) {
            print {$out} $entries->{$_}->dump()
                or croak "Print $file: $OS_ERROR";
        }
    }
    else {
        for (@{$entries}) {
            print {$out} $_->dump()
                or croak "Print $file: $OS_ERROR";
        }
    }
    close $out
        or croak "Close $file $OS_ERROR";

    return $self;
}

sub load_file_asarray {
    my $self = shift;
    my $file = shift;
    my $eol  = shift || "\n";

    if (ref $file) {
        return $self->_load_file($file, $file, $eol, 0);
    }
    open my $in, '<', $file
        or croak "Open $file: $OS_ERROR";
    my $array_ref = $self->_load_file($file, $in, $eol, 0);
    close $in
        or croak "Close $file: $OS_ERROR";

    return $array_ref;
}

sub load_file_ashash {
    my $self = shift;
    my $file = shift;
    my $eol  = shift || "\n";

    if (ref $file) {
        return $self->_load_file($file, $file, $eol, 1);
    }
    open my $in, '<', $file
        or croak "Open $file: $OS_ERROR";
    my $hash_ref = $self->_load_file($file, $in, $eol, 1);
    close $in
        or croak "Close $file: $OS_ERROR";

    return $hash_ref;
}

sub _load_file {
    my $self        = shift;
    my $file_name   = shift;
    my $file_handle = shift;
    my $eol         = shift;
    my $ashash      = shift;

    my $line_number = 0;
    my (@entries, %entries);
    while (
        my $po = $self->load_entry(
            $file_name,
            $file_handle,
            \$line_number,
            $eol,
        )
    ) {
        # ashash
        if ($ashash) {
            if ( $po->_hash_key_ok(\%entries) ) {
                $entries{ $po->msgid() } = $po;
            }
        }
        # asarray
        else {
            push @entries, $po;
        }
    }

    return $ashash
           ? \%entries
           : \@entries;
}

sub load_entry { ## no critic (ExcessComplexity)
    my $self            = shift;
    my $file_name       = shift;
    my $file_handle     = shift;
    my $line_number_ref = shift;
    my $eol             = shift || "\n";

    my $class = ref $self || $self;
    my %last_line_of_section; # to find the end of an entry
    my $current_section_key;  # to add lines

    my ($current_line_number, $current_pos);
    my $safe_current_position = sub {
        # safe information to can roll back
        $current_line_number = ${$line_number_ref};
        $current_pos         = tell $file_handle;
        defined $current_pos
            or croak "Can not tell file pointer of file $file_name: $OS_ERROR";
    };
    $safe_current_position->();

    my $is_new_entry = sub {
        $current_section_key = shift;
        if (
            exists $last_line_of_section{ $current_section_key }
            && $last_line_of_section{ $current_section_key }
               != ${$line_number_ref} - 1
        ) {
            # roll back
            ${$line_number_ref} = $current_line_number;
            seek $file_handle, $current_pos, 0
                or croak "Can not seek file pointer of file $file_name: $OS_ERROR";
            return 1; # this is a new entry
        }
        $last_line_of_section{ $current_section_key } = ${$line_number_ref};
        return;
    };

    my $po;             # build an object during read an entry
    my %buffer;         # find the different msg...
    my $current_buffer; # to add lines
    LINE:
    while (my $line = <$file_handle>) {
        $line =~ s{\Q$eol\E \z}{}xms;
        my $line_number = ++${$line_number_ref};
        if ( $line =~ m{\A \s* \z}xms ) { ## no critic (CascadingIfElse)
            # Empty line. End of an entry.
            last LINE if $po;
        }
        elsif (
            $line =~ m{\A \# \s+ (.*)}xms
            || $line =~ m{\A \# ()\z}xms
        ) {
            # Translator comments
            last LINE if $is_new_entry->('comment');
            $po ||= $class->new(eol => $eol, -loaded_line_number => $line_number);
            $po->comment(
                defined $po->comment()
                ? $po->comment() . "$eol$1"
                : $1
            );
        }
        elsif ( $line =~ m{\A \# \. \s* (.*)}xms) {
            # Automatic comments
            last LINE if $is_new_entry->('comment');
            $po ||= $class->new(eol => $eol, -loaded_line_number => $line_number);
            $po->automatic(
                defined $po->automatic()
                ? $po->automatic() . "$eol$1"
                : $1
            );
        }
        elsif ( $line =~ m{\A \# : \s+ (.*)}xms ) {
            # reference
            last LINE if $is_new_entry->('comment');
            $po ||= $class->new(eol => $eol, -loaded_line_number => $line_number);
            $po->reference(
                defined $po->reference()
                ? $po->reference() . "$eol$1"
                : $1
            );
        }
        elsif ( $line =~ m{\A \# , \s+ (.*)}xms) {
            # flags
            last LINE if $is_new_entry->('comment');
            $po ||= $class->new(eol => $eol, -loaded_line_number => $line_number);
            my @flags = split m{\s* , \s*}xms, $1;
            for my $flag (@flags) {
                $po->add_flag($flag);
            }
        }
        elsif ( $line =~ m{\A ( \# ~ \s+ )? ( msgctxt | msgid | msgplural | msgstr ) \s+ (.*)}xms ) {
            last LINE if $is_new_entry->($2);
            $po ||= $class->new(eol => $eol, -loaded_line_number => $line_number);
            $buffer{$2} = $self->dequote($3, $eol);
            $current_buffer = \$buffer{$2};
            if ($1) {
                $po->obsolete(1);
            }
        }
        elsif ($line =~  m{\A (?: \# ~ \s+ )? msgstr \[ (\d+) \] \s+ (.*)}xms ) {
            # translated string
            last LINE if $is_new_entry->('msgstr_n');
            $buffer{msgstr_n}{$1} = $self->dequote($2, $eol);
            $current_buffer = \$buffer{msgstr_n}{$1};
        }
        elsif ( $line =~ m{\A (?: \# ~ \s+ )? "}xms ) {
            # contined string
            ${$current_buffer} .= $self->dequote($line, $eol);
            $last_line_of_section{ $current_section_key } = $line_number;
        }
        else {
            warn "Strange line at $file_name line $line_number: $line\n";
        }
        $safe_current_position->();
    }
    if ($po) {
        for my $key (qw(msgctxt msgid msgid_plural msgstr msgstr_n)) {
            if ( defined $buffer{$key} ) {
                $po->$key( $buffer{$key} );
            }
        }
        return $po;
    }

    return; # no entry found
}

sub _hash_key_ok {
    my ($self, $entries) = @_;

    my $key = $self->msgid();

    if ($entries->{$key}) {
        # don't overwrite non-obsolete entries with obsolete ones
        return if $self->obsolete() && ! $entries->{$key}->obsolete();
        # don't overwrite translated entries with untranslated ones
        return if $self->msgstr() !~ m{\w}xms
                  && $entries->{$key}->msgstr() =~ m{\w}xms;
    }

    return 1;
}

1;

__END__

=head1 NAME

DBD::PO::Locale::PO - Perl module for manipulating .po entries from GNU gettext

$Id: PO.pm 253 2008-10-21 07:24:44Z steffenw $

$HeadURL: https://dbd-po.svn.sourceforge.net/svnroot/dbd-po/trunk/DBD-PO/lib/DBD/PO/Locale/PO.pm $

=head1 VERSION

0.21.01

=head1 SYNOPSIS

    require DBD::PO::Locale::PO;

    $po = DBD::PO::Locale::PO->new([eol => $eol, [-option => value, ...]])
    [$string =] $po->msgid([new string]);
    [$string =] $po->msgstr([new string]);
    [$string =] $po->comment([new string]);
    [$string =] $po->automatic([new string]);
    [$string =] $po->reference([new string]);
    [$value =] $po->fuzzy([value]);
    [$value =] $po->add_flag('c-format');
    [$value =] $po->add_flag('php-format');
    print $po->dump();

    $quoted_string = $po->quote($string);
    $string = $po->dequote($quoted_string);
    $string = DBD::PO::Locale::PO->dequote($quoted_string, $eol);

    $aref = DBD::PO::Locale::PO->load_file_asarray(<filename>);
    $href = DBD::PO::Locale::PO->load_file_ashash(<filename>);
    DBD::PO::Locale::PO->save_file_fromarray(<filename>, $aref);
    DBD::PO::Locale::PO->save_file_fromhash(<filename>, $href);

=head1 DESCRIPTION

This module simplifies management of GNU gettext .po files and is an
alternative to using emacs po-mode. It provides an object-oriented
interface in which each entry in a .po file is a DBD::PO::Locale::PO object.

=head1 SUBROUTINES/METHODS

=over 4

=item method new

    my $po = DBD::PO::Locale::PO->new();
    my $po = DBD::PO::Locale::PO->new(%options);

Specify an eol or accept the default "\n".

    eol => "\r\n"

Create a new DBD::PO::Locale::PO object to represent a po entry.
You can optionally set the attributes of the entry by passing
a list/hash of the form:

    -option=>value, -option=>value, etc.

Where options are msgid, msgstr, msgctxt, comment, automatic, reference,
fuzzy, c-format and php-format. See accessor methods below.

To generate a po file header, add an entry with an empty
msgid, like this:

    $po = DBD::PO::Locale::PO->new(
        -msgid  => q{},
        -msgstr =>
            "Project-Id-Version: PACKAGE VERSION\n"
            . "PO-Revision-Date: YEAR-MO-DA HO:MI +ZONE\n"
            . "Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
            . "Language-Team: LANGUAGE <LL@li.org>\n"
            . "MIME-Version: 1.0\n"
            . "Content-Type: text/plain; charset=CHARSET\n"
            . "Content-Transfer-Encoding: ENCODING\n",
    );

=item method eol

Set or get the eol string from the object.

=item method msgid

Set or get the untranslated string from the object.

This method expects the new string in unquoted form but returns the current string in quoted form.

=item method msgid_plural

Set or get the untranslated plural string from the object.

This method expects the new string in unquoted form but returns the current string in quoted form.

=item method msgstr

Set or get the translated string from the object.

This method expects the new string in unquoted form but returns the current string in quoted form.

=item method msgstr_n

Get or set the translations if there are purals involved. Takes and
returns a hashref where the keys are the 'N' case and the values are
the strings. eg:

    $po->msgstr_n(
        {
            0 => 'found %d plural translations',
            1 => 'found %d singular translation',
        }
    );

This method expects the new strings in unquoted form but returns the current strings in quoted form.

=item method msgctxt

Set or get the translation context string from the object.

This method expects the new string in unquoted form but returns the current string in quoted form.

=item method obsolete

Returns 1 if the entry is obsolete.
Obsolete entries have their msgid, msgid_plural, msgstr, msgstr_n and msgctxt lines commented out with "#~"

When using load_file_ashash, non-obsolete entries will always replace obsolete entries with the same msgid.

=item method comment

Set or get translator comments from the object.

If there are no such comments, then the value is undef.  Otherwise,
the value is a string that contains the comment lines delimited with
"\n".  The string includes neither the S<"# "> at the beginning of
each comment line nor the newline at the end of the last comment line.

=item method automatic

Set or get automatic comments from the object (inserted by
emacs po-mode or xgettext).

If there are no such comments, then the value is undef.  Otherwise,
the value is a string that contains the comment lines delimited with
"\n".  The string includes neither the S<"#. "> at the beginning of
each comment line nor the newline at the end of the last comment line.

=item method reference

Set or get reference marking comments from the object (inserted
by emacs po-mode or gettext).

=item method fuzzy

Set or get the fuzzy flag on the object ("check this translation").
When setting, use 1 to turn on fuzzy, and 0 to turn it off.

=item method c_format

Set or get the c-format or no-c-format flag on the object.

This can take 3 values:
1 implies c-format, 0 implies no-c-format, and undefined implies neither.

=item method php_format

Set or get the php-format or no-php-format flag on the object.

This can take 3 values:
1 implies php-format, 0 implies no-php-format, and undefined implies neither.

=item method has_flag

    if ($po->has_flag('perl-format')) {
        ...
    }

Returns true if the flag exists in the entry's #~ comment

=item method add_flag

    $po->add_flag('perl-format');

Adds the flag to the #~ comment

=item method remove_flag

    $po->remove_flag('perl-format');

Removes the flag from the #~ comment

=item method loaded_line_number

When using one of the load_file_as* methods,
this will return the line number that the entry started at in the file.

=item method dump

Returns the entry as a string, suitable for output to a po file.

=item method quote

Applies po quotation rules to a string, and returns the quoted
string. The quoted string will have all existing double-quote
characters escaped by backslashes, and will be enclosed in double
quotes.

=item method dequote

Returns a quoted po string to its natural form.

=item method load_file_asarray

Given the filename of a po-file, reads the file and returns a
reference to a list of DBD::PO::Locale::PO objects corresponding to the contents of
the file, in the same order.

=item method load_file_ashash

Given the filename of a po-file, reads the file and returns a
reference to a hash of DBD::PO::Locale::PO objects corresponding to the contents of
the file. The hash keys are the untranslated strings, so this is a cheap
way to remove duplicates. The method will prefer to keep entries that
have been translated.

=item method save_file_fromarray

Given a filename and a reference to a list of DBD::PO::Locale::PO objects,
saves those objects to the file, creating a po-file.

=item method save_file_fromhash

Given a filename and a reference to a hash of DBD::PO::Locale::PO objects,
saves those objects to the file, creating a po-file. The entries
are sorted alphabetically by untranslated string.

=item method load_entry

Method was added to read entry by entry.

    use Carp qw(croak);
    use English qw(-no_match_vars $OS_ERROR);
    use Socket qw($CRLF);
    use DBD::PO::Locale::PO;

    open my $file_handle, '<', $file_name
        or croak $OS_ERROR;
    $eol = $CRLF;
    my $line_number = 0;
    while (
        my $po = DBD::PO::Locale::PO->load_entry(
            $file_name,
            $file_handle,
            \$line_number,
            $eol, # optional, default "\n"
        )
    ) {
        do_something_with($po);
    }

=back

=head1 DIAGNOSTICS

none

=head1 CONFIGURATION AND ENVIRONMENT

none

=head1 DEPENDENCIES

Carp

English

=head1 INCOMPATIBILITIES

not known

=head1 BUGS AND LIMITATIONS

If you load_file_as* then save_file_from*, the output file may have slight
cosmetic differences from the input file (an extra blank line here or there).
(And the quoting of binary values can be changed, but all this is not a Bug.)

msgid, msgid_plural, msgstr, msgstr_n and msgctxt
expect a non-quoted string as input, but return quoted strings.
The maintainer of Locale::PO was hesitant to change this in fear of breaking the modules/scripts
of people already using Locale::PO. (Fixed in DBD::PO::Locale::PO)

Locale::PO requires blank lines between entries, but Uniforum style PO
files don't have any. (Fixed)

=head1 SEE ALSO

L<Locale::Maketext::Lexicon> xgettext.pl

=head1 AUTHOR

Some Bugfixes in DBD::PO::Locale::PO: Steffen Winkler, steffenw at cpan.org

Maintainer of Locale::PO: Ken Prows, perl at xev.net

Original version of Locale::PO by: Alan Schwartz, alansz at pennmush.org

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008,
Steffen Winkler
C<< <steffenw at cpan.org> >>.
All rights reserved.

This module is free software;
you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

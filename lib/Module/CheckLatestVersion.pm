package Module::CheckLatestVersion;

use 5.010001;
use strict;
use warnings;
use Log::ger;
use Log::ger::Format::MultilevelLog (); # for scan prereqs
use Log::ger::Format 'MultilevelLog';

use Exporter qw(import);

# AUTHORITY
# DATE
# DIST
# VERSION

## no critic: Modules::ProhibitAutomaticExportation
our @EXPORT = qw(check_latest_version);

sub check_latest_version {
    my $opts = ref $_[0] eq 'HASH' ? {%{ shift()} } : {};
    my $mod = shift; $mod = caller() unless $mod;
    $opts->{die} //= $ENV{PERL_MODULE_CHECKLATESTVERSION_OPT_DIE};
    $opts->{log_level} //= 'debug';
    $opts->{do_check} //= 0 if
        $ENV{HARNESS_ACTIVE} ||
        $ENV{RELEASE_TESTING} ||
        $ENV{AUTOMATED_TESTING} ||
        $ENV{PERL_MODULE_CHECKLATESTVERSION_SKIP};

    no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict

    require Cache::File::Simple;
    my $cachekey = __PACKAGE__ . '|' . $mod;
    log($opts->{log_level}, "Checking version of module $mod from cache ...");
    my $res = Cache::File::Simple::cache($cachekey);
    unless ($res) {
        # cache miss
        log($opts->{log_level}, "Checking version of module $mod (cache miss) ...");
        require Module::CheckVersion;
        $res = Module::CheckVersion::check_module_version(module => $mod);
    }

    if ($res->[0] != 200) {
        warn "Cannot check latest version of module $mod: $res->[0] - $res->[1]";
        return;
    }

    if ($res->[2]{is_latest_version}) {
        log($opts->{log_level}, "Module $mod (installed version: $res->[2]{installed_version}) is latest version ($res->[2]{latest_version})");
        # cache only positive result AND when version is defined
        if (defined($res->[2]{installed_version}) && defined($res->[2]{latest_version})) {
            log($opts->{log_level}, "Caching version check result ...");
            Cache::File::Simple::cache($cachekey, $res);
        }
    } else {
        my $msg = "Module $mod (installed version: " .
            (defined($res->[2]{installed_version}) ? $res->[2]{installed_version} : "undef") .
            ") is not the latest version (" .
            (defined($res->[2]{latest_version}) ? $res->[2]{latest_version} : "undef") .
            ").";
        if ($opts->{die} && defined $res->[2]{latest_version}) {
            $msg .= " Please update to the latest version first.";
            die $msg;
        } else {
            $msg .= " Please consider updating to the latest version.";
            warn $msg;
        }
    }
}

1;
# ABSTRACT: Warn/die when a module is not the latest version

=head1 SYNOPSIS

In F<Your/Module.pm>:

 package Your::Module;

 use Module::CheckLatestVersion; # automatically exports 'check_latest_version'

 our $VERSION = 1.23;
 our $AUTHORITY = 'cpan:PERLANCAR';

 check_latest_version();
 # check_latest_version({die=>1});

If module is not the latest version (checked against authority) then a warn
message is displayed. If the C<die> option is set, program will die.

Or, alternatively, in F<your-script.pl>:

 #!perl

 use strict;
 use warnings;
 use Module::CheckLatestVersion;
 use Your::Module;

 check_latest_version("Your::Module");
 #check_latest_version({die=>1}, "Your::Module");
 ...


=head1 DESCRIPTION

This module can be used to check other module's version against latest version
in authority. Authority can be CPAN or DarkPAN or other schemes that are
supported by L<Module::CheckVersion>.

Checking against authority is cached, by default 3600 seconds (default from
L<Cache::File::Simple>).

This can be used to ensure that scripts use the latest version of a module.


=head1 FUNCTIONS

=head2 check_latest_version

Usage:

 check_latest_version([ \%opts, ] [ $mod ])

Check module C<$mod> against authority (default is CPAN), using
L<Module::CheckVersion>. C<$mod> defaults to the caller's package. If module is
not the latest version, a warning is emitted.

When one of these environment variables are set, will skip checking (no-op):
C<HARNESS_ACTIVE>, C<RELEASE_TESTING>, C<AUTOMATED_TESTING>,
C<PERL_MODULE_CHECKLATESTVERSION_SKIP>. Unless when C<do_check> is set to true.

Options:

=over

=item * die

Bool. If set to true, will die instead of warn.

=item * log_level

Str or number. Set the log level of log statements that inform about module
checking.

=item * do_check

Bool, default is undef. Can be used to force checking or disable checking
without regard to environment variables.

=back


=head1 ENVIRONMENT

=head2 PERL_MODULE_CHECKLATESTVERSION_OPT_DIE

Bool. Set default value for the C<die> option.

=head2 PERL_MODULE_CHECKLATESTVERSION_SKIP

Bool. Can be set to true to skip checking.


=head1 SEE ALSO

L<Module::CheckVersion>

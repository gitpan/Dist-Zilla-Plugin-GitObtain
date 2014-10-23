package Dist::Zilla::Plugin::GitObtain;
BEGIN {
  $Dist::Zilla::Plugin::GitObtain::VERSION = '0.04';
}

# ABSTRACT: obtain files from a git repository before building a distribution

use Git::Wrapper;
use File::Path qw/ make_path remove_tree /;
use Moose;
use namespace::autoclean;

with 'Dist::Zilla::Role::Plugin';
with 'Dist::Zilla::Role::BeforeBuild';

has 'git_dir' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    default => '.',
);

has _repos => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

sub BUILDARGS {
    my $class = shift;
    my %repos = ref($_[0]) ? %{$_[0]} : @_;

    my $zilla = delete $repos{zilla};
    my $git_dir = delete $repos{plugin_name};
    $git_dir = '.' if $git_dir eq 'GitObtain';

    my %args;
    for my $project (keys %repos) {
        if ($project =~ /^--/) {
            (my $arg = $project) =~ s/^--//;
            $args{$arg} = delete $repos{$project};
            next;
        }
        my ($url,$tag) = split ' ', $repos{$project};
        $repos{$project} = { url => $url, tag => $tag };
    }

    return {
        zilla => $zilla,
        plugin_name => 'GitObtain',
        _repos => \%repos,
        git_dir => $git_dir,
        %args,
    };
}

sub before_build {
    my $self = shift;

    if (-d $self->git_dir) {
        $self->log("using existing directory " . $self->git_dir);
    } else {
        $self->log("creating directory " . $self->git_dir);
        make_path($self->git_dir) or die "Can't create directory " . $self->git_dir . " -- $!";
    }
    for my $project (keys %{$self->_repos}) {
        my ($url,$tag) = map { $self->_repos->{$project}{$_} } qw/url tag/;
        $self->log("cloning $project");
        my $git = Git::Wrapper->new($self->git_dir);
        $git->clone($url,$project) or die "Can't clone repository $url -- $!";
        next unless $tag;
        $self->log("checkout $project revision $tag");
        my $git_tag = Git::Wrapper->new($self->git_dir . '/' . $project);
        $git_tag->checkout($tag);
    }
}


__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 NAME

Dist::Zilla::Plugin::GitObtain - obtain files from a git repository before building a distribution

=head1 VERSION

version 0.04

=head1 SYNOPSIS

In your F<dist.ini>:

  [GitObtain]
    ;project    = url                                           tag
    rakudo      = git://github.com/rakudo/rakudo.git            2010.06
    http-daemon = git://gitorious.org/http-daemon/mainline.git

=head1 DESCRIPTION

This module uses L<Git::Wrapper> to obtain files from git repositories
before building a distribution.

You may specify the directory that git repositories will be placed into
by following the plugin name (C<GitObtain>) with a forward slash
(C</>), then the path to the particular directory. For instance, if your
F<dist.ini> file contained the following section:

  [GitObtain/alpha/beta/gamma]
    ...

projects downloaded via git would be placed into the F<alpha/beta/gamma>
directory. This directory and any intermediate directories in the path
will be created if they do not already exist.  If you do not specify a
path, then the git projects will be created in the current directory.

Following the section header is the list of git repositories to download
and include in the distribution. Each repository is specified by the
name of the directory in which the repository will be checked out, an
equals sign (C<=>), the URL to the git repository, and an optional "tag"
to checkout (anything that may be passed to C<git checkout> may be used 
for the "tag"). The repository directory will be created beneath the path
specified in the section heading. So,

  [GitObtain/foo]
    my_project      = git://github.com/example/my_project.git
    another_project = git://github.com/example/another_project.git

will create a F<foo> directory beneath the current directory and
F<my_project> and F<another_project> directories inside of the F<foo>
directory. Each of the F<my_project> and F<another_project> directories
will be git repositories.

=head1 AUTHOR

Jonathan Scott Duff <duff@pobox.com>

=head1 COPYRIGHT

This software is copyright (c) 2010 by Jonathan Scott Duff

This is free sofware; you can redistribute it and/or modify it under the
same terms as the Perl 5 programming language itself.

=cut
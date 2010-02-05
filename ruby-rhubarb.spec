%{!?ruby_sitelib: %global ruby_sitelib %(ruby -rrbconfig -e 'puts Config::CONFIG["sitelibdir"] ')}
%define rel 0.3

Summary: Simple versioned object-graph persistence layer
Name: ruby-rhubarb
Version: 0.2.0
Release: %{rel}%{?dist}
Group: Applications/System
License: ASL 2.0
URL: http://git.fedorahosted.org/git/grid/rhubarb.git
Source0: %{name}-%{version}-%{rel}.tar.gz
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Requires: ruby-sqlite3
Requires: ruby
Requires: ruby(abi) = 1.8
BuildRequires: ruby
BuildArch: noarch

%description
A simple versioned object-graph persistence layer that stores
instances of specially-declared Ruby classes in a SQLite3 database

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/%{ruby_sitelib}/rhubarb
mkdir -p %{buildroot}/%{ruby_sitelib}/rhubarb/mixins
cp -f lib/rhubarb/mixins/*.rb %{buildroot}/%{ruby_sitelib}/rhubarb/mixins
cp -f lib/rhubarb/*.rb %{buildroot}/%{ruby_sitelib}/rhubarb

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, root, -)
%doc LICENSE README.rdoc CHANGES TODO VERSION
%{ruby_sitelib}/rhubarb/rhubarb.rb
%{ruby_sitelib}/rhubarb/classmixins.rb
%{ruby_sitelib}/rhubarb/mixins/freshness.rb
%{ruby_sitelib}/rhubarb/column.rb
%{ruby_sitelib}/rhubarb/reference.rb
%{ruby_sitelib}/rhubarb/util.rb
%{ruby_sitelib}/rhubarb/persisting.rb
%{ruby_sitelib}/rhubarb/persistence.rb

%changelog
* Fri Feb  5 2010  <rrat@redhat> - 0.2.0-0.3
- Explicitly list files
- Added ruby(abi) and dependency
- Added ruby build dependency

* Thu Feb  4 2010  <willb@redhat.com> - 0.2.0-0.2
- Post-0.2 cleanups

* Tue Feb  2 2010  <rrati@redhat> - 0.2.0-0.1
- Initial package

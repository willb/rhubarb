%{!?ruby_sitelib: %global ruby_sitelib %(ruby -rrbconfig -e 'puts Config::CONFIG["sitelibdir"] ')}
%define rel 0.1

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
cp -f lib/rhubarb/rhubarb.rb %{buildroot}/%{ruby_sitelib}/rhubarb

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, root, -)
%doc LICENSE README.rdoc CHANGES TODO VERSION
%{ruby_sitelib}/rhubarb

%changelog
* Tue Feb  2 2010  <rrati@fedora12-test> - 0.2.0-0.1
- Initial package

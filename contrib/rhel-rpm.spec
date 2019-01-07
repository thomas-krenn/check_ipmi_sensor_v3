Name:           check_ipmi_sensor
Version:        3.12
Release:        6%{dist}
Summary:        ipmi sensors icinga check plugin
Packager:       Thomas Loescher, <thomas.loescher@swisscom.com>
Vendor:         Thomas-Krenn.AG

Group:          Application/System
License:        GPLv3
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       perl-IPC-Run
Requires:       perl-IO-Tty
Requires:       freeipmi

%if 0%{?el6}
%filter_from_requires /perl(a[n]*)/d
%filter_setup
%endif

%description
check_plugin for hardware monitoring using the ipmi interface

%prep
%setup -q


%build


%install
%{__install} -D check_ipmi_sensor $RPM_BUILD_ROOT%{_libdir}/nagios/plugins/check_ipmi_sensor
%{__install} -D sudo_icinga_ipmi $RPM_BUILD_ROOT%{_sysconfdir}/sudoers.d/icinga_ipmi
%{__install} -D changelog.txt $RPM_BUILD_ROOT%{_defaultdocdir}/%{name}/changelog.txt
%{__install} -D COPYING $RPM_BUILD_ROOT%{_defaultdocdir}/%{name}/COPYING
%{__install} -d contrib $RPM_BUILD_ROOT%{_defaultdocdir}/%{name}/contrib
%{__install} -D contrib/default-combinedgraph.template $RPM_BUILD_ROOT%{_defaultdocdir}/%{name}/contrib/default-combinedgraph.template

%files
%defattr(0664,root,root) 
%attr(0755,root,root) %{_libdir}/nagios/plugins/check_ipmi_sensor
%attr(0660,root,root) %config(noreplace) %{_sysconfdir}/sudoers.d/icinga_ipmi
%{_defaultdocdir}/%{name}/changelog.txt
%{_defaultdocdir}/%{name}/COPYING
%{_defaultdocdir}/%{name}/contrib/default-combinedgraph.template


%changelog
* Fri Oct 12 2018 Thomas Loescher <thomas.loescher@swisscom.com> 3.12-6
- remove AutoReq, use %filter_from_requires for rhel6 perl dependencies
  (thomas.loescher@swisscom.com)

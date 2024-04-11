Summary: thrix's RPM configuration for Fedora Sericea
Name: thrix-config
Version: 1.0.6
Release: 1
License: MIT

Requires: fontawesome-fonts-all nautilus polkit-gnome

%description
Configuration rpm for Fedora Sericea

%prep

%install
mkdir -p %{buildroot}/usr/share/polkit-1/actions
cp %{_sourcedir}/thrix-config*/com.1password.1Password.policy %{buildroot}/usr/share/polkit-1/actions

%files
/usr/share/polkit-1/actions/com.1password.1Password.policy

%changelog
* Thu Apr 11 2024 Miroslav Vadkerti <mvadkert@redhat.com> 1.0.6-1
- Fix building (mvadkert@redhat.com)
* Thu Apr 11 2024 Miroslav Vadkerti <mvadkert@redhat.com> 1.0.5-1
- Create installation directory
* Thu Apr 11 2024 Miroslav Vadkerti <mvadkert@redhat.com> 1.0.4-1
- Change back :)
* Thu Apr 11 2024 Miroslav Vadkerti <mvadkert@redhat.com> 1.0.3-1
- Fix file location
* Thu Apr 11 2024 Miroslav Vadkerti <mvadkert@redhat.com> 1.0.2-1
- new package built with tito

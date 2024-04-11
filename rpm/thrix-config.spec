Summary: thrix's RPM configuration for Fedora Sericea
Name: thrix-config
Version: 1.0.2
Release: 1
License: MIT

Requires: font-awesome-config nautilus polkit-gnome

%description
Configuration rpm for Fedora Sericea

%install
cp com.1password.1Password.policy %{buildroot}/usr/share/polkit-1/actions/

%files
/usr/share/polkit-1/actions/com.1password.1Password.policy

%changelog
* Thu Apr 11 2024 Miroslav Vadkerti <mvadkert@redhat.com> 1.0.2-1
- new package built with tito

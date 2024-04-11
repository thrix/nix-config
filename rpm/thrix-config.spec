Summary: thrix's RPM configuration for Fedora Sericea
Name: thrix-config
Version: 1.0.1
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
